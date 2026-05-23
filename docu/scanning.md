# Vulnerability Scanning

Scanning is performed from the Kali Linux VM (`10.0.30.110`) against the LAN and DMZ segments. Three tools are used: Nmap (host discovery and NSE scripts), Nuclei (template-based CVE and misconfiguration scanning), and GVM/OpenVAS (deep authenticated vulnerability assessment).

## Automated Scan Script

`/home/kali/vulnerabilityScan.sh` — deployed to the Kali VM via OpenTofu at provision time.

**Target ranges:**

| Variable | Value | Actual segment |
|----------|-------|----------------|
| `DMZ_RANGE` | 10.0.10.0/24 | LAN (Win7, Ubuntu Desktop, Wazuh) |
| `LAN_RANGE` | 10.0.20.0/24 | DMZ (Win2008) |

Note: the variable names in the script are swapped relative to the actual topology — both ranges are scanned regardless so results are unaffected, but the output filenames reference the wrong segment labels.

Output is written to `./scan_results_YYYYMMDD/` with one subdirectory per stage.

### Stage 1 — Host Discovery

```bash
nmap -sn 10.0.10.0/24 10.0.20.0/24
nmap -Pn -T4 --min-rate 1000 -F 10.0.10.0/24 10.0.20.0/24
```

ICMP + TCP ping sweep to identify live hosts, followed by a fast port scan (-F = top 100 ports) with timing T4 and a minimum packet rate of 1000/s.

Output: `stage1/nmap-initial-host-check.txt`, `stage1/quick-discovery.txt`

### Stage 2 — OS and Service Vulnerability Scan (Nmap NSE)

Three parallel Nmap scans with service version detection and targeted NSE scripts:

**General CVE lookup:**
```bash
nmap -sV --script vulners 10.0.10.0/24 10.0.20.0/24
```
Takes the detected service version strings and looks them up against a CVE database. Covers all open ports.

**Windows legacy exploit checks:**
```bash
nmap -sV --script smb-vuln-ms17-010,smb-vuln-ms08-067,rdp-vuln-ms12-020,\
smb-vuln-ms10-061,smb-vuln-ms10-054,rdp-ntlm-info 10.0.10.0/24 10.0.20.0/24
```

| Script | Checks for |
|--------|-----------|
| `smb-vuln-ms17-010` | EternalBlue (Win7, Win2008) |
| `smb-vuln-ms08-067` | NetAPI RCE (Win2008) |
| `rdp-vuln-ms12-020` | RDP DoS/RCE |
| `smb-vuln-ms10-061` | Print Spooler RCE |
| `smb-vuln-ms10-054` | SMB divide-by-zero DoS |
| `rdp-ntlm-info` | Extracts Windows build/domain info from RDP |

**Linux/service-specific checks:**
```bash
nmap -sV --script ssl-enum-ciphers,http-shellshock,ftp-anon,ftp-vsftpd-backdoor \
    10.0.10.0/24 10.0.20.0/24
```

| Script | Checks for |
|--------|-----------|
| `ssl-enum-ciphers` | Weak/deprecated TLS cipher suites |
| `http-shellshock` | CVE-2014-6271 (Bash Shellshock via HTTP) |
| `ftp-anon` | Anonymous FTP login (Ubuntu Desktop vsftpd) |
| `ftp-vsftpd-backdoor` | vsftpd 2.3.4 backdoor (CVE-2011-2523) |

Output: `stage2/nmap_vulners_report.txt`, `stage2/nmap_windows_report.txt`, `stage2/nmap_ubuntu_report.txt`

### Stage 3 — Application and CVE Scan (Nuclei)

```bash
nmap -p- --open 10.0.10.0/24 10.0.20.0/24 -oG stage3/targets.txt
nuclei -l targets.txt \
    -tags cve,exposure,misconfiguration,os,services,default-login,\
          network,windows,smb,rdp,linux,apache,ssl,ssh,dns \
    -rate-limit 10 -bulk-size 3 -concurrency 5 -timeout 5s
```

Full port scan first to build a target list of open host:port pairs, then Nuclei runs its template library against each. Tags cover:

- `cve` — known CVE templates
- `exposure` — exposed sensitive files, admin panels, config files
- `misconfiguration` — default settings, insecure configurations
- `default-login` — factory credential checks (admin/admin, root/root, etc.)
- `windows`, `smb`, `rdp`, `linux`, `apache`, `ssl`, `ssh`, `dns` — protocol/service-specific templates

Output: `stage3/nuclei_legacy_report.txt`

### Stage 4 — Credential and Authentication Audit

**Nmap NSE credential/enumeration scripts:**
```bash
nmap -p 3306,445 \
    --script mysql-empty-password,smb-enum-shares,smb-enum-users,\
             smb-protocols,smb-security-mode,smb-enum-sessions,\
             smb-os-discovery,ms-sql-info,ms-sql-empty-password,\
             pgsql-brute,http-default-accounts,snmp-brute \
    10.0.20.0/24
```

Targets DMZ only (Win2008). Checks for:
- MySQL root with no password (XAMPP default)
- SMB anonymous share enumeration and user listing
- SMB protocol version and signing status
- HTTP default credentials (bWAPP/XAMPP admin interfaces)

**Nuclei auth/brute templates:**
```bash
nuclei -l targets.txt \
    -tags default-login,brute,auth-bypass,kerberos,ldap,snmp \
    -itags windows,linux,ssh,smb,rdp,ftp \
    -rl 5 -c 2
```

Output: `stage4/nmap_auth_audit_report.txt`, `stage4/nuclei_auth_audit_report.txt`

## OpenVAS / GVM (Manual)

GVM is installed on the Kali VM (`apt install gvm`) but the first-run setup is not automated — it must be run manually before first use.

**Initial setup (one-time):**
```bash
sudo gvm-setup
# wait ~10-20 minutes for feed sync
sudo runuser -u _gvm -- gvmd --user=admin --new-password=<password>
sudo gvm-start
```

**Access:** `https://127.0.0.1:9392` (Greenbone Security Assistant web UI) from the Kali VM.

**Recommended scan config for this lab:**

| Setting | Value |
|---------|-------|
| Scan type | Full and fast |
| Targets | 10.0.10.0/24, 10.0.20.0/24 |
| Port list | All TCP and Nmap top 100 UDP |
| Credentials | Add SMB cred for Win7/Win2008 for authenticated scan |

Authenticated scanning against Win7 (`worker1`/`Password123`) and Win2008 (`Administrator`/`Packer123!`) produces significantly more findings than unauthenticated — GVM can enumerate installed software, patch levels, and registry settings directly.

## SIEM Correlation

All scan traffic from Kali is visible in Wazuh via the Sophos firewall logs (syslog forwarded to `10.0.10.170`). Firewall rule hits from `10.0.30.110` (Kali/WAN) against the DMZ and LAN targets appear as firewall events in the Wazuh dashboard.

Wazuh agents on Win7 and Win2008 will also generate Windows Security Log events during the credential audit stage (Event ID 4625 failed logon, 4624 successful logon, 4776 NTLM authentication attempts).
