# Sophos Firewall Configuration

Sophos Firewall Home Edition 21.0.1 MR-1. Acts as the primary gateway and security enforcement point for all lab segments after the Ubuntu Router was deactivated.

All configuration below the initial bootstrap is **manual** (done via web UI) and is not reflected in the repository.

## Provisioning Split

### What Packer does (`modules/04-sophos/sophos.pkr.hcl`)

Installs Sophos from ISO with a single NIC (vmbr140). Boot commands perform the first-run wizard via the serial console and configure:
- Management IP: `10.0.40.2/24` on Port1 (vmbr140)
- XML API enabled (`AllowedIPAddress: 192.168.1.0/24`)

The result is a Proxmox template with one configured port.

### What OpenTofu does (`modules/04-sophos/sophos.tf`)

Clones the template and attaches four NICs at the Proxmox/hypervisor level in order:

| Proxmox slot | Bridge | Sophos sees |
|-------------|--------|-------------|
| NIC 1 | vmbr140 | Port A (setup/management) |
| NIC 2 | vmbr130 | Port B |
| NIC 3 | vmbr110 | Port C |
| NIC 4 | vmbr120 | Port D |

OpenTofu has no visibility into Sophos internals — it only tells Proxmox which bridges to wire up. Sophos detects the four ports on next boot but has no zone assignment yet.

### What was done manually in the web UI

After first boot of the cloned VM the four detected ports were assigned IPs and zones. The Packer bootstrap set Port1 to `10.0.40.2`; this was changed to `10.0.40.1` during manual configuration so Sophos acts as the `.1` gateway on every subnet.

## Interface Configuration

`Configure > Network > Interfaces`

| Interface | Type | Zone | IP address | Mask | Status | Proxmox bridge |
|-----------|------|------|-----------|------|--------|----------------|
| Port1 | Physical | LAN | 10.0.40.1 | /24 | Connected | vmbr140 (Setup) |
| Port2 | Physical | WAN | 10.0.30.1 | /24 | Connected | vmbr130 (External) |
| Port3 | Physical | LAN | 10.0.10.1 | /24 | Connected | vmbr110 (LAN) |
| Port4 | Physical | DMZ | 10.0.20.1 | /24 | Connected | vmbr120 (DMZ) |
| GuestAP | WiFi | WiFi | 10.255.0.1 | /24 | Unplugged | — |

Note: Port1 (Setup/vmbr140) and Port3 (LAN/vmbr110) are both members of the LAN zone — management traffic and internal client traffic share the same zone and trust level.

## Zones

`Configure > Network > Zones`

| Zone | Member ports | Type | Device access allowed |
|------|-------------|------|-----------------------|
| LAN | Port1, Port3 | LAN | HTTPS, SSH, Ping, DNS, Web Proxy, User Portal, SSL VPN, SMTP Relay, SNMP, Captive Portal, Radius SSO, Clients |
| WAN | Port2 | WAN | — |
| DMZ | Port4 | DMZ | SSL VPN, User Portal, SNMP |
| VPN | — | VPN | SNMP |
| WiFi | GuestAP | LAN | HTTPS, SSH, Ping, DNS, Web Proxy, User Portal, SSL VPN, SMTP Relay, SNMP, Captive Portal, Radius SSO, Clients |

## WAN Link Manager

`Configure > Network > WAN link manager`

| Name | Gateway IP | Interface | Type | Status |
|------|-----------|-----------|------|--------|
| DHCP_Port2_GW | 10.0.30.110 | Port2 (10.0.30.1/24) | Active | Active |

The WAN gateway is `10.0.30.110` — the Kali Linux VM. In the lab topology Kali acts as the upstream/internet-facing gateway from Sophos's perspective.

## DNS

`Configure > Network > DNS`

- Mode: Static DNS
- DNS 1: `127.0.0.1` (Sophos resolves DNS queries itself)
- DNS 2/3: not configured
- IPv6: Static, not configured

## DHCP

`Configure > Network > DHCP`

DHCP is only active for the GuestAP WiFi network. All lab VMs use static IPs provisioned via Packer/OpenTofu.

| Name | Interface | Dynamic range | Status |
|------|-----------|--------------|--------|
| GuestAccess_DHCP | GuestAP (10.255.0.1) | 10.255.0.2 – 10.255.0.254 | Enabled |

## Firewall Rules

`Protect > Rules and policies` (Firewall rules tab)

Rules are evaluated top-to-bottom. Disabled rules are greyed out in the UI (example/template rules shipped with Sophos). 12 rules total.

### Group: Traffic to Internal Zones

| Pos | Name | Source | Destination | Service | Action | State | Security policies |
|-----|------|--------|-------------|---------|--------|-------|-------------------|
| 1 | ALLOW ALL | Any zone, Any host | Any zone, Any host | Any | Accept | **Disabled** | |
| 2 | [example] Traffic to Internal Zones | Any zone, Any host, Any live user | LAN, DMZ, WiFi, VPN, Any host | Any | Drop | **Disabled** | |
| 3 | DMZ to LAN | DMZ · windows2008\_server | LAN · wazuh | wazuhAgent | **Accept** | Enabled | IPS, AV, Web, App, QoS, HB, LinkedNAT, PRX, LOG |

### Group: Traffic to WAN

| Pos | Name | Source | Destination | Service | Action | State | Security policies |
|-----|------|--------|-------------|---------|--------|-------|-------------------|
| 4 | dmz to wan | DMZ, Any host | WAN, Any host | Any | **Accept** | Enabled | IPS, AV, Web, App, QoS, HB, LinkedNAT, PRX, LOG |
| 5 | [example] Traffic to WAN | Any zone, Any host | WAN, Any host | Any | Drop | **Disabled** | |
| 6 | LAN to WAN | LAN, Any host | WAN, Any host | Any | **Accept** | Enabled | IPS, AV, Web, App, QoS, HB, LinkedNAT, PRX, LOG |

### Group: Traffic to DMZ

| Pos | Name | Source | Destination | Service | Action | State | Security policies |
|-----|------|--------|-------------|---------|--------|-------|-------------------|
| 7 | [example] Traffic to DMZ | Any zone, Any host, Any live user | DMZ, Any host | Any | Drop | **Disabled** | |
| 8 | WAN to DMZ | WAN, Any host | DMZ · windows2008\_server | HTTP, HTTPS | **Accept** | Enabled | IPS, AV, Web, App, QoS, HB, LinkedNAT, PRX, LOG |
| 9 | LAN to DMZ | LAN, Any host | DMZ, Any host | Any | **Accept** | Enabled | IPS, AV, Web, App, QoS, HB, LinkedNAT, PRX, LOG |

### Ungrouped

| Pos | Name | Source | Destination | Service | Action | State | Security policies |
|-----|------|--------|-------------|---------|--------|-------|-------------------|
| 10 | Auto added firewall policy for MTA | Any zone, Any host | Any zone, Any host | SMTP, SMTP(S) | **Accept** | Enabled | IPS, AV, Web, App, QoS, HB, LinkedNAT |
| 11 | #Default\_Network\_Policy | LAN, Any host | WAN, Any host | Any | **Accept** | Enabled | IPS, AV, Web, App, QoS, HB, LinkedNAT |
| 12 | Drop all | Any zone, Any host | Any zone, Any host | Any | Drop | **Disabled** | |

### Key rules explained

- **Rule 3 (DMZ to LAN)**: The manually created rule allowing Win2008 (DMZ) to reach Wazuh (LAN) on the `wazuhAgent` service. Without this rule the Wazuh agent on Win2008 could not connect across the zone boundary.
- **Rule 8 (WAN to DMZ)**: Exposes the Win2008 web server (bWAPP/XAMPP) to the External/attacker segment on HTTP and HTTPS only — all other ports remain blocked from WAN to DMZ.
- **Rule 4 (dmz to wan)**: Allows Win2008 outbound internet access (required for Wazuh agent updates and package downloads).
- **Rule 12 (Drop all)**: Catch-all drop rule is currently disabled — unmatched traffic falls through to Sophos default behaviour rather than being explicitly dropped.

## NAT Rules

`Protect > Rules and policies` (NAT rules tab)

3 IPv4 rules, no IPv6 rules configured.

| Pos | Name | Original source | Original service | Original destination | Translated source | Outbound interface | ID | Last used |
|-----|------|----------------|-----------------|---------------------|-------------------|-------------------|----|-----------|
| 1 | #NAT\_Default\_Network\_Poli | Any host | Any service | Any host | MASQ | Any interface | #3 | Unused |
| 2 | Auto added NAT rule for MTA | Any host | SMTP, SMTP(S) | Any host | MASQ | Any interface | #1 | 2026-05-06 |
| 3 | Default SNAT IPv4 | Any host | Any service | Any host | MASQ | Port2 (WAN) | #2 | 2026-05-23 |

All rules use MASQUERADE (source NAT) — internal IPs are replaced with the Sophos WAN interface IP when traffic leaves to the external segment. **Default SNAT IPv4** (rule 3) is the primary active rule, locked to outbound Port2, handling all inter-zone traffic that exits to WAN.

## SSL/TLS Inspection

`Protect > Rules and policies` (SSL/TLS inspection rules tab)

SSL/TLS inspection is **globally enabled** (toggle active). Sophos acts as a man-in-the-middle: it terminates the client-side TLS connection, inspects the plaintext, then re-encrypts toward the destination using a lab CA certificate.

2 rules, evaluated top-to-bottom:

| ID | Name | Source | Destination | What | Profile | Action |
|----|------|--------|-------------|------|---------|--------|
| 1 | Exclusions by website... | Any zone, Any host, Anybody | Any zone, Any host | Local TLS exclusion list + Managed exclusion list | Maximum compatibility | **Don't decrypt** |
| 2 | Lab\_TLS\_interception | LAN, DMZ, Any host, Anybody | Any zone, Any host | Any website, Any service | Block insecure SSL | **Decrypt** |

**Rule 1** catches known exclusions (certificate-pinned apps, trusted vendor sites) and passes them through without inspection. **Rule 2** is the main lab interception rule — all HTTPS traffic originating from LAN or DMZ is decrypted and scanned. The "Block insecure SSL" profile means connections using weak ciphers or expired/untrusted server certificates are actively blocked rather than just flagged.

### CA Certificate

`System > Certificates > Certificate authorities`

| Name | CN | Valid from | Valid until | Type |
|------|----|-----------|-------------|------|
| Default | `Default_CA_LvrFuGKERk02RI5` | 2026-03-22 | 2036-12-31 | Internal (generated by Sophos) |
| SecurityAppliance\_SSL\_CA | `Sophos SSL CA_LvrFuGKERk02RI5` | 2015-08-01 | 2036-12-31 | Built-in |

**Default** is the CA Sophos uses to dynamically sign intercepted certificates during TLS inspection. Clients that do not have this CA in their trusted root store will see certificate warnings for every inspected HTTPS connection.

The remaining ~20 pages of "Built-in" CAs are Sophos's trusted root store (standard public CAs) used to validate server-side certificates during inspection — these do not need to be distributed to clients.

**CA distribution status:** The Default CA cert has **not** been pushed to lab VMs. Consequences per machine:

| Machine | Impact |
|---------|--------|
| Win7 | Browser certificate warnings on all HTTPS; does not affect Wazuh agent (port 1514) |
| Ubuntu 10.04 | Certificate warnings in browser; syslog unaffected |
| Win2008 | Certificate warnings in browser; Wazuh agent unaffected; bWAPP runs on HTTP |
| Kali | HTTPS-based scan tools may throw SSL errors when routing through firewall |

To distribute: export "Default" CA from this page (download icon), then on Windows import via `certmgr.msc` → Trusted Root Certification Authorities; on Ubuntu copy to `/usr/local/share/ca-certificates/` and run `sudo update-ca-certificates`.

## Intrusion Prevention (IPS)

`Protect > Intrusion prevention`

### DoS Attack Protection

`Protect > Intrusion prevention > DoS attacks`

All flood protections are currently **not applied** — no source or destination limits configured, no traffic dropped.

| Attack type | Source applied | Destination applied |
|-------------|---------------|---------------------|
| SYN Flood | No | No |
| UDP Flood | No | No |
| TCP Flood | No | No |
| ICMP Flood | No | No |
| IP Flood | No | No |

### IPS Policies

`Protect > Intrusion prevention > IPS policies`

| Setting | Value |
|---------|-------|
| IPS protection | **Enabled** |
| Firewall rules using IPS | 5 (rules 3, 4, 6, 8, 9) |
| Time of signature update | **No signatures** |

IPS is enabled and referenced by 5 firewall rules, but **no signature database is loaded**. Without signatures IPS cannot match or block any attack patterns — it is effectively inactive despite being toggled on. This is a known limitation of the Sophos Home Edition in isolated/offline lab environments where signature update servers are unreachable.

**Available IPS policies:**

Built-in templates (Sophos default, not deletable):

| Policy | Purpose |
|--------|---------|
| DMZ TO LAN | Secures servers hosted in LAN from DMZ traffic |
| DMZ TO WAN | Secures DMZ-based clients going to WAN |
| LAN TO DMZ | Secures LAN clients and DMZ servers |
| LAN TO WAN | Secures LAN-based clients going to WAN |
| WAN TO DMZ | Secures servers hosted in DMZ from WAN traffic |
| WAN TO LAN | Secures servers hosted in LAN from WAN traffic |

Custom policies (user-created):

| Policy | Description |
|--------|-------------|
| dmzpolicy | General policy for traffic flowing to DMZ |
| generalpolicy | General policy |
| lantowan\_general | General policy for LAN to WAN traffic |
| lantowan\_strict | Strict policy for LAN to WAN traffic |

## Web Application Firewall (WAF)

`Protect > Web server`

WAF is activated. No custom protection rules or virtual hosts have been configured — the feature is enabled at the engine level but no traffic is currently being directed through it. The firewall rule `WAN to DMZ` (rule 8) allows HTTP/HTTPS inbound to `windows2008_server` directly without WAF reverse-proxy involvement.

To use the WAF for Win2008/bWAPP traffic it would need a virtual host entry mapping an external IP/port to the internal server, with a protection policy applied. This has not been done.

## Routing

`Configure > Routing > Gateways`

No static routes configured. Sophos handles inter-segment routing natively because it has a directly connected interface in every subnet (LAN, DMZ, WAN). Only the default IPv4 gateway is defined:

| Name | Gateway IP | Interface | Health check | Status |
|------|-----------|-----------|-------------|--------|
| DHCP\_Port2\_GW | 10.0.30.110 | Port2 (WAN, 10.0.30.1/24) | On | Active |

Default route points to Kali Linux (`10.0.30.110`) — in the lab topology Kali acts as the simulated upstream internet gateway.

## Syslog / Log Forwarding

`Configure > System services > Log settings`

### Syslog Server

| Name | Server IP | Port | Facility | Severity | Format |
|------|-----------|------|----------|----------|--------|
| WazuhSiem | 10.0.10.170 | 514 | DAEMON | Information | Standard syslog protocol |

### Log Settings

All sub-log-types are enabled for both Local reporting and forwarding to WazuhSiem. The table below shows which categories are configured — `Suppress` = logs suppressed at category level, `Local` = stored locally on Sophos, `Siem` = forwarded to WazuhSiem.

| Category | Sub-type | Suppress | Local | Siem |
|----------|----------|----------|-------|------|
| Firewall | _(parent — suppress enabled)_ | yes | — | — |
| | Firewall rules | — | yes | yes |
| | Invalid traffic | — | yes | yes |
| | Local ACLs | — | yes | yes |
| | DoS attack | — | yes | yes |
| | Dropped ICMP redirected packet | — | yes | yes |
| | Dropped source routed packet | — | yes | yes |
| | Dropped fragmented traffic | — | yes | yes |
| | MAC filtering | — | yes | yes |
| | IP-MAC pair filtering | — | yes | yes |
| | IP spoof prevention | — | yes | yes |
| | SSL VPN tunnel | — | yes | yes |
| | Protected application server | — | yes | yes |
| | Heartbeat | — | yes | yes |
| | ICMP error message | — | yes | yes |
| | Bridge ACLs | — | yes | yes |
| IPS | Anomaly | — | yes | yes |
| | Signatures | — | yes | yes |
| Antivirus | HTTP, FTP, SMTP, POP3, IMAP, HTTPS, SMTPS, POPS, IMAPS | — | yes | yes |
| Anti-spam | SMTP, POP3, IMAP, SMTPS, POPS, IMAPS | — | yes | yes |
| Content filtering | Web filter, Application filter, Web content policy, SSL/TLS filter | — | yes | yes |
| Events | Admin events, Authentication events, System events | — | yes | yes |
| Web server protection | Web server protection events | — | yes | yes |
| Active threat response | MDR, Sophos X-Ops, Third-party threat feeds | — | yes | yes |
| Wireless | Access points & SSID | — | yes | yes |
| Heartbeat | Endpoint status | — | yes | yes |
| System health | Usage | — | no | yes |
| Zero-day protection | Zero-day protection events | — | yes | yes |
| SD-WAN | SD-WAN profile | — | yes | yes |

Note: "Firewall" parent row has "Suppress logs" checked — this suppresses the high-level category aggregate entry but does **not** suppress the individual sub-types, which are all still forwarded to WazuhSiem.

Custom Wazuh decoder and rules for parsing Sophos syslog messages are deployed via OpenTofu:
- `/var/ossec/etc/decoders/local_decoder.xml`
- `/var/ossec/etc/rules/local_rules.xml`
