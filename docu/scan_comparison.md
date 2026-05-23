# Vulnerability Scan Comparison Report
## Phase 1 (No Firewall) vs. Phase 2 (Firewall Enabled)

**Scan Date:** 2026-05-03
**Phase 1 scan time:** ~19:46 – ~20:11
**Phase 2 scan time:** ~22:50 – ~23:23
**Scanner:** Kali Linux (nmap 7.99 + nuclei)
**Scope:** LAN (10.0.10.0/24) + DMZ (10.0.20.0/24)

---

## 1. Attack Surface Reduction at a Glance

| Metric | Phase 1 (No FW) | Phase 2 (FW Enabled) | Change |
|--------|-----------------|----------------------|--------|
| Reachable hosts | 3 | 1 | -2 |
| Total open ports (all hosts) | 28+ | 7 | -21+ |
| Critical findings | 3 | 1 | -2 |
| High findings | 3 | 2 | -1 |
| Medium findings | 3 | 3 | 0 |
| Low findings | 3 | 2 | -1 |
| New findings introduced | — | 1 | +1 |

---

## 2. Host Visibility Change

| Host | Zone | OS | Phase 1 | Phase 2 | Delta |
|------|------|----|---------|---------|-------|
| 10.0.10.140 | LAN | Ubuntu Linux | Reachable (7 ports) | **Blocked** | Eliminated |
| 10.0.10.150 | LAN | Windows 7 SP1 | Reachable (10 ports) | **Blocked** | Eliminated |
| 10.0.20.160 | DMZ | Windows Server 2008 R2 | Reachable (6 ports) | Reachable (7 ports) | +1 port (FTP) |

The firewall successfully hides the entire LAN zone. The two hosts with the most severe vulnerabilities are now completely unreachable from the attacker network. The Stage 4 credential audit, which found 2 hosts on the LAN in Phase 1, returned **0 hosts** in Phase 2 — confirming the LAN block is complete.

---

## 3. Finding-by-Finding Comparison

### Eliminated by the Firewall

These findings existed in Phase 1 and are gone in Phase 2 because the hosting machines are now unreachable:

| ID | Finding | Severity | Reason Gone |
|----|---------|----------|------------|
| CRIT-2 | vsftpd 2.2.2 backdoor (CVE-2011-2523, CVSS 10.0) | CRITICAL | 10.0.10.140 blocked |
| CRIT-3 | Root shell on port 6667 | CRITICAL | 10.0.10.140 blocked |
| CRIT-1 (partial) | EternalBlue on Windows 7 (CVE-2017-0143) | CRITICAL | 10.0.10.150 blocked |
| HIGH-1 | SMBv1 enabled + SMB signing disabled on Win7 | HIGH | 10.0.10.150 blocked |
| HIGH-2 | OpenSSH 4.3 (CVE-2006-5051, CVE-2024-6387) | HIGH | 10.0.10.140 blocked |
| HIGH-3 | CUPS 1.4 RCE (CVE-2012-6094, CVE-2010-2941) | HIGH | 10.0.10.140 blocked |
| INFO-1 (partial) | WinRM on Windows 7 (ports 5985/47001) | INFO | 10.0.10.150 blocked |
| INFO-2 | Anonymous IPC$ read access on Win7 | INFO | 10.0.10.150 blocked |
| LOW-2 | XAMPP default dashboard page | LOW | No longer detected |
| LOW-1 (partial) | bWAPP phpinfo.php | LOW | No longer detected |

The elimination of CRIT-2, CRIT-3, and CRIT-1 (partial) represents a substantial improvement. In Phase 1 three independent unauthenticated remote root/SYSTEM exploits were available. In Phase 2 only one remains.

---

### Unchanged — Not Fixed by the Firewall

These findings are present in both scans. The firewall provides no protection against them because the ports carrying these services on the DMZ host (10.0.20.160) remain reachable:

| ID | Finding | Severity | Notes |
|----|---------|----------|-------|
| CRIT-1 (partial) | EternalBlue on DMZ webserver (CVE-2017-0143) | CRITICAL | Port 445 still reachable on DMZ host |
| MED-1 | Broken TLS on RDP (RC4, 3DES, MD5, SHA1) | MEDIUM | Port 3389 still open, TLS config unchanged |
| MED-2 | SMB signing disabled on DMZ | MEDIUM | Port 445 reachable, signing still off |
| MED-3 | CGI printenv script exposed | MEDIUM | `http://10.0.20.160/cgi-bin/printenv.pl` still accessible |
| LOW-1 (partial) | phpinfo.php on dashboard | LOW | `http://10.0.20.160/dashboard/phpinfo.php` still accessible |
| LOW-3 | bWAPP web.config exposed | LOW | `http://10.0.20.160/bWAPP/web.config` still accessible |
| INFO-1 (partial) | WinRM on DMZ (port 5985) | INFO | Still reachable from attacker network |

The persistence of EternalBlue is the most critical gap. Port 445 should have been blocked at the firewall for the DMZ host, but it was not. This means the DMZ webserver can still be fully compromised with a single unauthenticated exploit.

---

### New Finding Introduced in Phase 2

| ID | Finding | Severity | Notes |
|----|---------|----------|-------|
| HIGH-1 (new) | FTP port 21 exposed on DMZ host | HIGH | Was filtered in Phase 1, now open — likely a firewall misconfiguration |

Port 21 (FTP) appears on 10.0.20.160 in Phase 2 but was not reachable in Phase 1. This is unexpected and suggests a firewall rule may have accidentally forwarded or permitted FTP where it should not be. FTP transmits credentials in cleartext and adds unnecessary attack surface to the DMZ server.

---

## 4. Detailed Port Comparison — 10.0.20.160 (DMZ Webserver)

| Port | Service | Phase 1 | Phase 2 | Change |
|------|---------|---------|---------|--------|
| 21/tcp | FTP | Filtered | **Open** | Newly exposed |
| 80/tcp | HTTP (Apache/PHP/XAMPP) | Open | Open | Unchanged |
| 135/tcp | MSRPC | Open | Open | Unchanged |
| 445/tcp | SMB (EternalBlue) | Open | Open | Unchanged |
| 3389/tcp | RDP (broken TLS) | Open | Open | Unchanged |
| 5985/tcp | WinRM | Open | Open | Unchanged |
| 49154/tcp | MSRPC dynamic | Open | Open | Unchanged |

---

## 5. Web Attack Surface Comparison — 10.0.20.160

| URL / Finding | Phase 1 | Phase 2 | Change |
|---------------|---------|---------|--------|
| `http://10.0.20.160/dashboard/` (XAMPP default page) | Detected | Not detected | Mitigated |
| `http://10.0.20.160/bWAPP/phpinfo.php` | Detected | Not detected | Mitigated |
| `http://10.0.20.160/dashboard/phpinfo.php` | Detected | Detected | Unchanged |
| `http://10.0.20.160/cgi-bin/printenv.pl` | Detected | Detected | Unchanged |
| `http://10.0.20.160/bWAPP/web.config` | Detected | Detected | Unchanged |

Two web findings were mitigated between scans. This may reflect additional hardening applied directly to the webserver (e.g., removing or restricting access to the bWAPP phpinfo page and XAMPP dashboard) rather than firewall action, since these are HTTP resources on port 80 which remains fully open in both phases.

---

## 6. SMB / Windows Credential Attack Surface Comparison

| Finding | Phase 1 | Phase 2 |
|---------|---------|---------|
| Hosts with EternalBlue | 2 (Win7 + Win2008) | 1 (Win2008 only) |
| Hosts with SMBv1 active | 2 | 1 |
| Hosts with SMB signing disabled | 2 | 1 |
| Anonymous IPC$ access | Yes (Win7) | No |
| Unauthenticated SMB enumeration | 2 hosts | 1 host |
| WinRM exposed hosts | 2 | 1 |

---

## 7. Summary of Firewall Effectiveness

### What the Firewall Did Well

- **Completely shielded the LAN zone.** Both LAN hosts vanished from the attacker's view. This alone removed 2 critical and 3 high severity findings.
- **Blocked the two most dangerous individual services in the lab** — the vsftpd backdoor and the open root shell on port 6667 — by making the Ubuntu host unreachable.
- **Reduced the credential audit attack surface to zero on the LAN.** Stage 4 returned 0 hosts, versus 2 in Phase 1.
- **Partial web hardening** was observed on the DMZ host (bWAPP phpinfo and XAMPP dashboard no longer detected).

### Where the Firewall Falls Short

- **EternalBlue still exploitable on the DMZ host.** Port 445 should be blocked from the external/attacker network. This is the single most important gap remaining.
- **FTP was accidentally exposed** on the DMZ host. A new attack surface was introduced, not removed — this indicates a misconfigured firewall rule.
- **RDP and WinRM remain open** on the DMZ host, providing a large credential-based attack surface that should not be reachable from the external/attacker network.
- **Application-level vulnerabilities** (CGI printenv, phpinfo, web.config) are unaffected by network-layer filtering and require separate remediation at the web server level.
- **The underlying software is still end-of-life.** The firewall reduces reachability but does not fix any CVE. If the firewall were bypassed or misconfigured, all original vulnerabilities are still fully exploitable.

---

## 8. Risk Score Comparison (Qualitative)

| Category | Phase 1 (No FW) | Phase 2 (FW Enabled) |
|----------|-----------------|----------------------|
| Network exposure | Very High | Medium |
| Critical RCE risk | Very High (3 vectors) | High (1 vector) |
| Credential theft risk | High | Medium |
| Information disclosure | Medium | Low-Medium |
| Overall risk | **Critical** | **High** |

---

## 9. Conclusion

Adding the firewall reduced the overall risk from **Critical to High**. The most important improvement is that the two LAN hosts — which together carried three independent unauthenticated root/SYSTEM exploit paths — are now completely isolated from the attacker.

However, the DMZ webserver (10.0.20.160) remains a critical risk on its own. EternalBlue is still fully exploitable because port 445 was not restricted at the firewall. A single additional firewall rule blocking inbound SMB (445/tcp) to the DMZ host from the external network would eliminate the last remaining critical vulnerability.

**Key recommendations before Phase 3 (IDS/IPS):**

1. Block port 445 inbound to the DMZ from the external network at the firewall.
2. Investigate and close the unexpected FTP (port 21) exposure on the DMZ host.
3. Restrict RDP (3389) and WinRM (5985) to management networks only — these must not be reachable from the attacker network.
4. Apply web server-level hardening to remove the remaining `phpinfo.php`, `printenv.pl`, and exposed `web.config` files.
