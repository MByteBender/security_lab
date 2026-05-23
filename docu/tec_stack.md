# Infrastructure & Technology Stack

## Platform

| Component | Value |
|-----------|-------|
| Hypervisor | Proxmox VE, node `pve` |
| IaC | OpenTofu (Terraform-compatible), provider `bpg/proxmox` 0.70.0 |
| VM Templating | Packer, plugin `hashicorp/proxmox ~> 1` |
| Storage | `zfs-itsec` (ZFS) |
| Resource Pool | `IT-sec` |

## Network Segments

Defined in `modules/01-networks/networks.tf`. All bridges are isolated (no uplink).

| Bridge | Subnet | Role |
|--------|--------|------|
| vmbr110 | 10.0.10.0/24 | LAN — internal clients |
| vmbr120 | 10.0.20.0/24 | DMZ — web server |
| vmbr130 | 10.0.30.0/24 | External — attacker segment |
| vmbr140 | 10.0.40.0/24 | Setup — provisioning / management |
| vmbr1255 | 10.0.255.0/24 | Management |

## Ubuntu Router / Bridge (`ubuntu-router`, VM 131) — deactivated

Provisioned via `modules/05-ubuntu/` for initial setup only (bridged all segments via Linux `br0`). Deactivated after initial provisioning; Sophos Firewall handles all inter-segment routing in the running lab.

## VM Inventory

| VM ID | Template ID | Hostname | OS | Network IPs |
|-------|-------------|----------|----|-------------|
| 121 | 125 | sophos | Sophos Firewall 21.0.1 MR-1 | vmbr140: 10.0.40.1 · vmbr130: 10.0.30.1 · vmbr110: 10.0.10.1 · vmbr120: 10.0.20.1 |
| 111 | 110 | kali | Kali Linux Rolling 2025.4 | vmbr140: 10.0.40.110 · vmbr130: 10.0.30.110 · vmbr0: DHCP |
| 141 | 140 | ubuntu-vintage | Ubuntu 10.04 LTS i386 | vmbr140: 10.0.40.140 · vmbr110: 10.0.10.140 |
| 151 | 150 | win7 | Windows 7 Professional x64 | vmbr140: 10.0.40.150 · vmbr110: 10.0.10.150 |
| 161 | 160 | win2008 | Windows Server 2008 R2 | vmbr140: 10.0.40.160 · vmbr120: 10.0.20.160 |
| 170 | 170 | wazuh | Ubuntu 25.10 Server | vmbr140: 10.0.40.170 · vmbr110: 10.0.10.170 · vmbr0: DHCP |
| 131 | 130 | ubuntu-router | Ubuntu 25.10 Server | deactivated — setup only |

## Services per Machine

### Sophos Firewall — 10.0.40.1 / 10.0.30.1 / 10.0.10.1 / 10.0.20.1

Acts as the primary gateway and security enforcement point for all segments (EXT, LAN, DMZ) after the Ubuntu Router was deactivated. Initial bootstrap configured via Packer boot commands and XML API; all firewall rules and routing were configured manually via the web UI after provisioning and are **not reflected in the repository**.

| Service | Port | Notes |
|---------|------|-------|
| Web Admin UI | 4443 | HTTPS |
| XML API | 4444 | HTTP, `AllowedIPAddress: 192.168.1.0/24` |
| Syslog (to Wazuh) | 514/UDP | Sophos forwards its own logs to Wazuh at 10.0.10.170 |

**Manually configured firewall rules (web UI, not in repo):**

| Rule | Source | Destination | Port | Purpose |
|------|--------|-------------|------|---------|
| Allow Wazuh agent (DMZ → LAN) | 10.0.20.160 | 10.0.10.170 | 1514/UDP | Win2008 Wazuh agent traffic routed through Sophos to reach SIEM |

### Kali Linux — 10.0.30.110 / 10.0.40.110

Packages installed via Packer (`apt-get install -y`):

| Package | Notes |
|---------|-------|
| `kali-desktop-xfce` | Desktop environment |
| `kali-linux-default` | Default Kali toolset (includes nmap, metasploit, etc.) |
| `gvm` | Greenbone Vulnerability Manager (OpenVAS) — installed; initial `gvm-setup` and password config are not run during provisioning and must be done manually |
| `nuclei` | Template-based scanner, templates updated via `nuclei -ut` on build |
| `qemu-guest-agent` | Proxmox integration |

Uploaded by OpenTofu: `vulnerabilityScan.sh` → `/home/kali/` (4-stage scan: nmap, nuclei, credential audit)

### Ubuntu 10.04 Desktop — 10.0.10.140 / 10.0.40.140

All software installed and configured via OpenTofu provisioners (`.deb` packages from old-releases.ubuntu.com):

| Service | Port | Version | Configuration |
|---------|------|---------|---------------|
| Samba | 139, 445 | 3.4.7 | `security=share`, `null passwords=yes`, share `[Highly_Sensitive_Files]` maps `/` with `guest ok=yes`, `read only=no` |
| vsftpd | 21 | 2.2.2 | `anonymous_enable=YES`, `anon_upload_enable=YES`, `anon_mkdir_write_enable=YES`, no password |
| CUPS | 631 | 1.4.3 | `Listen *:631`, all locations `Allow all`, remote admin enabled |
| nc listener (fake SSH) | 2222 | — | Persistent `while true` loop, sends banner `SSH-2.0-OpenSSH_4.3` |
| nc listener (shell) | 6667 | — | Persistent `mkfifo /tmp/f` + `/bin/bash -i` reverse shell |

Additional hardening removals applied via OpenTofu:
- `kernel.randomize_va_space=0` (ASLR disabled)
- AppArmor stopped and removed from init (`update-rc.d -f apparmor remove`)
- iptables flushed, all chains set to ACCEPT

### Windows 7 Professional — 10.0.10.150 / 10.0.40.150

Configured via OpenTofu WinRM provisioners:

| Service | Port | Notes |
|---------|------|-------|
| WinRM | 5985 | HTTP, basic auth, `AllowUnencrypted=true` |
| SMB | 445 | SMB1 enabled, `enablesecuritysignature=0`, `requiresecuritysignature=0`, `restrictanonymous=0` |
| Wazuh Agent | — | 4.14.5, manager: `10.0.10.170` |

Applied: KB4474419 (SHA-2 code signing support), all firewall profiles disabled  
Share: `LabShare` → `C:\Users`  
Local user: `worker1` / `Password123`

### Windows Server 2008 R2 — 10.0.20.160 / 10.0.40.160

Configured via OpenTofu WinRM provisioners:

| Service | Port | Version | Notes |
|---------|------|---------|-------|
| Apache (XAMPP) | 80 | 2.4 (XAMPP 5.6.40) | Installed as service, started |
| MySQL (XAMPP) | 3306 | 5.6.40 | Installed as service, started |
| bWAPP | 80 | v2.2 | Extracted to `C:\xampp\htdocs`, initialized via `install.php?install=yes` |
| RDP | 3389 | — | `SetAllowTSConnections(1,1)`, NLA disabled `SetUserAuthenticationRequired(0)` |
| WinRM | 5985 | — | HTTP, basic auth, unencrypted |
| Wazuh Agent | — | 4.14.5 | Manager: `10.0.10.170` |

Applied: KB4474419 (SHA-2), TLS 1.2 enabled via registry (`SCHANNEL\Protocols\TLS 1.2`)  
Firewall rule: TCP port 80 inbound allowed  
Local user: `Administrator` / `Packer123!`

### Wazuh SIEM — 10.0.10.170 / 10.0.40.170

Installed via Packer quickstart script (`wazuh-install.sh -a`):

| Component | Port | Notes |
|-----------|------|-------|
| Wazuh Manager (agent) | 1514/UDP | Receives enrolled agents |
| Wazuh Indexer (OpenSearch) | 9200 | Internal only |
| Wazuh Dashboard | 443 | HTTPS, admin password set via `wazuh-passwords-tool.sh` |

Custom configs deployed via OpenTofu:
- `/var/ossec/etc/decoders/local_decoder.xml` — Sophos log decoder
- `/var/ossec/etc/rules/local_rules.xml` — Sophos alert rules
- Permissions: `root:wazuh 660`, wazuh-manager restarted after deploy
