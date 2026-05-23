# Vulnerability Scan Results

**Scanner:** Kali Linux 10.0.30.110, nmap 7.99 + nuclei  
**Scope:** LAN 10.0.10.0/24 + DMZ 10.0.20.0/24  
**Script:** `vulnerabilityScan.sh` — 4 stages: host discovery, NSE vuln scripts, nuclei, credential audit

Raw output files are in `scan_results_20260503/` (Phase 1) and `scan_results_with_fw/` (Phase 2).

---

## Phase 1 — No Firewall (2026-05-03 ~19:46)

### Stage 1 — Host Discovery

Ping sweep (`-sn`) across both /24 ranges found **3 live hosts**:

| IP | Latency |
|----|---------|
| 10.0.10.140 | 0.37 ms |
| 10.0.10.150 | 0.72 ms |
| 10.0.20.160 | 0.42 ms |

Full port scan (`-p- --open`) confirmed open ports per host:

| Host | Open Ports |
|------|-----------|
| 10.0.10.140 | 21, 22, 139, 445, 631, 2222, 6667 |
| 10.0.10.150 | 135, 139, 445, 5985, 47001, 49152–49157 |
| 10.0.20.160 | 80, 135, 445, 3389, 5985, 49154 |

---

### Stage 2 — Service Versions and NSE Vulnerability Scripts

#### 10.0.10.140 — Ubuntu 10.04

```
21/tcp   open  ftp         vsftpd 2.2.2
22/tcp   open  ssh         OpenSSH 5.3p1 Debian 3ubuntu7
139/tcp  open  netbios-ssn Samba smbd 3.X - 4.X
445/tcp  open  netbios-ssn Samba smbd 3.X - 4.X
631/tcp  open  ipp         CUPS 1.4
2222/tcp open  ssh         OpenSSH 4.3
6667/tcp open  irc?
| fingerprint-strings:
|   GenericLines: root@ubuntu-vintage:~#
|   NULL:         root@ubuntu-vintage:~#
```

Port 6667 is a persistent root shell (mkfifo + /bin/bash). Any connection receives an interactive root prompt with no authentication.

SMB scripts on Samba returned no Windows-specific vulnerability results (ms10-054: false; ms10-061: SMB negotiation error — expected for Linux Samba).

ftp-anon and ftp-vsftpd-backdoor scripts ran but produced no output in the report.

#### 10.0.10.150 — Windows 7 SP1

```
135/tcp   open  msrpc        Microsoft Windows RPC
139/tcp   open  netbios-ssn  Microsoft Windows netbios-ssn
445/tcp   open  microsoft-ds Microsoft Windows 7 - 10 microsoft-ds
5985/tcp  open  http         Microsoft HTTPAPI httpd 2.0 (WinRM)
49152–49157/tcp  open  msrpc
```

NSE result:
```
smb-vuln-ms17-010: VULNERABLE
  IDs: CVE:CVE-2017-0143
  State: VULNERABLE
  Risk factor: HIGH
  Disclosure date: 2017-03-14
```

#### 10.0.20.160 — Windows Server 2008 R2 (DMZ)

```
80/tcp    open  http    Apache httpd 2.4.37 ((Win32) OpenSSL/1.0.2p PHP/5.6.40)
135/tcp   open  msrpc   Microsoft Windows RPC
445/tcp   open  microsoft-ds  Microsoft Windows Server 2008 R2 - 2012
3389/tcp  open  ms-wbt-server
5985/tcp  open  http    Microsoft HTTPAPI httpd 2.0 (WinRM)
49154/tcp open  msrpc
```

NSE results:
```
smb-vuln-ms17-010: VULNERABLE
  IDs: CVE:CVE-2017-0143
  State: VULNERABLE

ssl-enum-ciphers (port 3389):
  TLSv1.0:
    TLS_RSA_WITH_AES_128_CBC_SHA        — F
    TLS_RSA_WITH_AES_256_CBC_SHA        — F
    TLS_RSA_WITH_RC4_128_SHA            — F  (RC4 deprecated RFC 7465)
    TLS_RSA_WITH_3DES_EDE_CBC_SHA       — F  (SWEET32)
    TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA  — F
    TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA  — F
    TLS_RSA_WITH_RC4_128_MD5            — F  (MD5 message integrity)
  Insecure certificate signature (SHA1), score capped at F
  least strength: F
```

rdp-ntlm-info did not produce output in Phase 1 (RDP responded but NTLM info was not extracted).

---

### Stage 3 — Nuclei

Nuclei targets from full port scan: 10.0.10.140 (7 ports), 10.0.10.150 (11 ports), 10.0.20.160 (6 ports).

All nuclei findings came from 10.0.20.160:

| Severity | Template | Finding |
|----------|----------|---------|
| medium | smb-signing | 10.0.20.160:445 — SMB signing not enforced |
| medium | cgi-printenv | `http://10.0.20.160/cgi-bin/printenv.pl` — CGI dumps all env vars |
| low | phpinfo-files | `http://10.0.20.160/bWAPP/phpinfo.php` (PHP 5.6.40) |
| low | phpinfo-files | `http://10.0.20.160/dashboard/phpinfo.php` (PHP 5.6.40) |
| low | xampp-phpinfo-detect | both phpinfo paths detected |
| info | xampp-default-page | `http://10.0.20.160/dashboard/` |
| info | web-config | `http://10.0.20.160/bWAPP/web.config` |
| info | rdp-detect | 10.0.20.160:3389 |
| info | rdp-detection:win2008R2DC | 10.0.20.160:3389 |
| info | smb-version-detect | SMB 2.1 |
| info | smb-enum | OS: 6.1.7601, Computer: WIN-Q3QAH5D874F |
| info | smb-enum-domains | Domain: WIN-Q3QAH5D874F |
| info | smb2-capabilities | DFSSupport, LargeMTU, Leasing |

No nuclei findings for 10.0.10.140 or 10.0.10.150.

---

### Stage 4 — Credential and Authentication Audit

Nmap auth audit targeted **10.0.10.0/24 only**. Found **2 hosts**:

#### 10.0.10.140
- 445/tcp open
- 3306/tcp closed (MySQL not reachable)
- No SMB-specific script results returned

#### 10.0.10.150
```
smb-protocols:
  NT LM 0.12 (SMBv1) [dangerous, but default]
  2.0.2
  2.1

smb-os-discovery:
  OS: Windows 7 Home Basic 7601 Service Pack 1
  Computer name: PC
  Workgroup: WORKGROUP

smb-security-mode:
  account_used: guest
  authentication_level: user
  challenge_response: supported
  message_signing: disabled (dangerous, but default)

smb-enum-shares:
  \\10.0.10.150\IPC$  — Anonymous access: READ
  \\10.0.10.150\ADMIN$  — Anonymous access: <none>
  \\10.0.10.150\C$    — Anonymous access: <none>
```

Nuclei auth audit (targets from stage 3, full port list) found on 10.0.20.160:
- smb-signing (medium)
- smb-enum-domains, smb-enum, smb-version, smb2-capabilities, smb-os-detect, rdp-detect (info)

---

## Phase 2 — Firewall Enabled (2026-05-03 ~22:50)

### Stage 1 — Host Discovery

Ping sweep across both /24 ranges found **1 host**:

| IP | Latency |
|----|---------|
| 10.0.20.160 | 0.63 ms |

10.0.10.140 and 10.0.10.150 — no response, completely blocked.

Full port scan confirmed open ports on the only reachable host:

| Host | Open Ports |
|------|-----------|
| 10.0.20.160 | **21**, 80, 135, 445, 3389, 5985, 49154 |

Port 21 (FTP) is open in Phase 2 but was **not present** in the Phase 1 full port scan of 10.0.20.160. This is an unexpected new exposure.

---

### Stage 2 — Service Versions and NSE Vulnerability Scripts

Only 10.0.20.160 reachable:

```
21/tcp    open  ftp?           (version not identified)
80/tcp    open  http           Apache httpd 2.4.37 ((Win32) OpenSSL/1.0.2p PHP/5.6.40)
135/tcp   open  msrpc          Microsoft Windows RPC
445/tcp   open  microsoft-ds   Microsoft Windows Server 2008 R2 - 2012
3389/tcp  open  ms-wbt-server
5985/tcp  open  http           Microsoft HTTPAPI httpd 2.0 (WinRM)
49154/tcp open  msrpc
```

NSE results:
```
smb-vuln-ms17-010: VULNERABLE
  IDs: CVE:CVE-2017-0143
  State: VULNERABLE

rdp-ntlm-info:
  Target_Name: WIN-Q3QAH5D874F
  NetBIOS_Computer_Name: WIN-Q3QAH5D874F
  DNS_Computer_Name: WIN-Q3QAH5D874F
  Product_Version: 6.1.7601
  System_Time: 2026-05-04T06:07:08Z

ssl-enum-ciphers (port 3389): identical result to Phase 1
  TLSv1.0 only, all ciphers rated F
  RC4, 3DES (SWEET32), MD5, SHA1 — unchanged
```

Vulners script against Apache 2.4.37: multiple CVSS 9.8 CVEs returned (CVE-2024-38476, CVE-2023-25690, CVE-2022-31813, CVE-2021-44790 among others). Full list in `stage2/nmap_vulners_report.txt`.

---

### Stage 3 — Nuclei

Nuclei targets from full port scan: 10.0.20.160 only (7 ports).

| Severity | Template | Finding | vs Phase 1 |
|----------|----------|---------|-----------|
| medium | smb-signing | 10.0.20.160:445 | Unchanged |
| medium | cgi-printenv | `http://10.0.20.160/cgi-bin/printenv.pl` | Unchanged |
| low | phpinfo-files | `http://10.0.20.160/dashboard/phpinfo.php` | Unchanged |
| info | web-config | `http://10.0.20.160/bWAPP/web.config` | Unchanged |
| info | rdp-detect, rdp-detection:win2008R2DC | 10.0.20.160:3389 | Unchanged |
| info | smb-enum, smb-version, smb2-* | OS 6.1.7601, WIN-Q3QAH5D874F | Unchanged |
| — | phpinfo-files (bWAPP) | **Not detected** | Gone |
| — | xampp-phpinfo-detect | **Not detected** | Gone |
| — | xampp-default-page | **Not detected** | Gone |

---

### Stage 4 — Credential and Authentication Audit

Nmap auth audit targeted **10.0.10.0/24**:

```
# Nmap done — 256 IP addresses (0 hosts up) scanned in 206.39 seconds
```

0 hosts found. The entire LAN segment is unreachable from the scanner.

Nuclei auth audit on 10.0.20.160 (same targets as stage 3): smb-signing, smb-enum, smb-version, smb-os-detect, rdp-detect — no credential-related findings, identical to phase 1 for that host.

---

## Comparison — Phase 1 vs Phase 2

### Attack Surface Numbers

| Metric | Phase 1 (No FW) | Phase 2 (FW) | Delta |
|--------|----------------|-------------|-------|
| Reachable hosts | 3 | 1 | -2 |
| Total open ports (full scan) | 24 | 7 | -17 |
| Hosts with confirmed MS17-010 | 2 | 1 | -1 |
| Stage 4 LAN hosts found | 2 | 0 | -2 |
| Nuclei medium findings | 2 | 2 | 0 |
| Nuclei low findings | 4 | 1 | -3 |
| Nuclei info findings | 9 | 8 | -1 |
| New findings introduced | — | 1 (FTP/21) | +1 |

### Per-Host Visibility Change

| Host | Phase 1 | Phase 2 |
|------|---------|---------|
| 10.0.10.140 (Ubuntu, 7 ports) | Reachable | Blocked |
| 10.0.10.150 (Win7, 11 ports) | Reachable | Blocked |
| 10.0.20.160 (Win2008, 6 ports) | Reachable | Reachable (+1 port: FTP) |

### What the Firewall Removed

| Finding | Phase 1 Source |
|---------|---------------|
| Root shell on port 6667 | 10.0.10.140 — blocked |
| vsftpd 2.2.2 on port 21 | 10.0.10.140 — blocked |
| OpenSSH 4.3 on port 2222 | 10.0.10.140 — blocked |
| CUPS 1.4 on port 631 | 10.0.10.140 — blocked |
| Samba 3.X on 139/445 | 10.0.10.140 — blocked |
| MS17-010 on Win7 (port 445) | 10.0.10.150 — blocked |
| SMBv1 + signing disabled on Win7 | 10.0.10.150 — blocked |
| IPC$ anonymous read on Win7 | 10.0.10.150 — blocked |
| WinRM on Win7 (5985, 47001) | 10.0.10.150 — blocked |
| Stage 4 LAN auth audit (2 hosts) | 10.0.10.0/24 — fully blocked |
| bWAPP phpinfo.php | No longer detected (HTTP resource, not FW) |
| XAMPP default page | No longer detected (HTTP resource, not FW) |

### What the Firewall Did Not Fix

| Finding | Status in Phase 2 |
|---------|------------------|
| MS17-010 on Win2008 (port 445) | Still VULNERABLE — port 445 open to scanner |
| FTP port 21 on Win2008 | Newly exposed — not present in Phase 1 |
| WinRM (port 5985) on Win2008 | Still open |
| RDP broken TLS (F rating, RC4/3DES/MD5/SHA1) | Identical — no change |
| SMB signing disabled on Win2008 | Still detected by nuclei |
| CGI printenv (`/cgi-bin/printenv.pl`) | Still accessible |
| phpinfo at `/dashboard/phpinfo.php` | Still accessible |
| bWAPP web.config exposed | Still accessible |
| NTLM info leak via RDP | rdp-ntlm-info now extracting data (was not in Phase 1) |
| Apache 2.4.37 CVEs (vulners) | Still exposed on port 80 |

### Notable Observations

**FTP on Win2008 appeared in Phase 2 but not Phase 1.** The full port scan in Phase 1 shows no port 21 on 10.0.20.160; Phase 2 shows it open. This is unexpected — either a firewall NAT/DNAT rule accidentally forwarded FTP to the host, or a service was started on the host between the two scans. FTP transmits credentials in cleartext and was not intentionally part of the lab design for Win2008.

**rdp-ntlm-info extracted data in Phase 2 but not Phase 1.** The RDP service responded with machine identity (hostname, OS version, domain) in Phase 2. This was not returned in Phase 1 despite the same port being open. No configuration change is documented between scans — likely a timing or connection-state difference.

**bWAPP phpinfo and XAMPP default page disappeared between scans.** Port 80 remained open in both phases. These are application-level changes on the host, not a firewall effect.
