# Wazuh SIEM

Wazuh is deployed as an all-in-one instance (manager + indexer + dashboard) on the LAN segment. It receives security events from enrolled agents and syslog sources across all segments.

## Deployment

| Item | Value |
|------|-------|
| Host | Ubuntu 25.10 Server, VM 170 |
| LAN IP | 10.0.10.170 |
| Management IP | 10.0.40.170 |
| Installation | Packer quickstart: `wazuh-install.sh -a` |
| Custom config | Deployed via OpenTofu at provision time |

## Components and Ports

| Component | Port | Protocol | Notes |
|-----------|------|----------|-------|
| Wazuh Manager (agent listener) | 1514 | UDP | Enrolled agents send events here |
| Wazuh Indexer (OpenSearch) | 9200 | TCP | Internal only |
| Wazuh Dashboard | 443 | HTTPS | Web UI, admin credentials set via `wazuh-passwords-tool.sh` |

**Dashboard access:** `https://10.0.10.170` or `https://10.0.40.170` from the management network.

## Log Sources

### Enrolled Agents

| Host | OS | Agent version | Agent IP | Routing |
|------|----|--------------|---------|---------|
| win7 (10.0.10.150) | Windows 7 Pro | 4.14.5 | 10.0.10.150 | Direct — same LAN subnet as Wazuh |
| win2008 (10.0.20.160) | Windows Server 2008 R2 | 4.14.5 | 10.0.20.160 | Routed via Sophos (DMZ → LAN); requires manual firewall rule `10.0.20.160 → 10.0.10.170:1514/UDP` |

Win2008 has no LAN interface — only vmbr120 (DMZ). Agent traffic therefore passes through the Sophos gateway at 10.0.20.1, which forwards it to 10.0.10.170 via a manually configured firewall rule (not in the repository).

### Syslog Sources (agentless)

| Host | Why no agent | Syslog sent to |
|------|-------------|----------------|
| ubuntu-vintage (10.0.10.140) | Ubuntu 10.04 LTS — no supported Wazuh agent package | 10.0.10.170 |
| Sophos Firewall (10.0.10.1) | Appliance OS — syslog forwarding configured in web UI | 10.0.10.170 |

Wazuh Manager listens for syslog on UDP 514 by default. Sophos forwards firewall, IPS, and system logs.

## Custom Decoder — `sophos_fw`

Deployed to `/var/ossec/etc/decoders/local_decoder.xml`.

The decoder chain triggers on any log line containing `device_name="SFW"` (the Sophos syslog identifier) and then extracts four fields via child decoders:

| Decoder stage | Field extracted | Regex |
|---------------|----------------|-------|
| Root | prematch trigger | `device_name="SFW"` |
| Child 1 | `srcip` | `src_ip="(\d+.\d+.\d+.\d+)"` |
| Child 2 | `dstip` | `dst_ip="(\d+.\d+.\d+.\d+)"` |
| Child 3 | `dstport` | `dst_port=(\d+)` |
| Child 4 | `log_component` | `log_component="(\w+\s*\w*)"` |

`log_component` captures the Sophos subsystem that generated the event (e.g. `Firewall`, `IPS`, `IP Spoof`).

## Custom Rules — `sophos_firewall` group

Deployed to `/var/ossec/etc/rules/local_rules.xml`. Rule IDs in the 110000 range.

| Rule ID | Level | Condition | Description |
|---------|-------|-----------|-------------|
| 110000 | 0 | `decoded_as: sophos_fw` | Base rule — matches all Sophos syslog events; level 0 suppresses alerting on raw traffic |
| 110001 | 3 | `if_sid 110000` + match `Denied\|Deny` | Blocked connection — triggers on any Sophos deny action |
| 110002 | 7 | `if_sid 110000` + match `category="IPS"` | IPS event detected — elevated level for potential attack traffic |
| 110005 | 0 | `if_sid 110001` + srcip `0.0.0.0` | Noise filter — suppresses DHCP discover/request deny noise |
| 110006 | 0 | `if_sid 110001` + srcip `169.254.0.0/16` | Noise filter — suppresses APIPA link-local deny noise |

Rule 110001 fires for every blocked connection but rules 110005/110006 immediately override it (level 0 = no alert) for the two high-volume noise sources. IPS events (110002, level 7) are never suppressed.

## Deployment via OpenTofu

The OpenTofu wazuh module (`modules/09-wazuh/wazuh.tf`) uploads both config files via SSH and places them with the correct permissions:

```
/var/ossec/etc/decoders/local_decoder.xml  — root:wazuh 660
/var/ossec/etc/rules/local_rules.xml       — root:wazuh 660
```

After placement, `systemctl restart wazuh-manager` is run to load the new rules and decoder.

## Windows Security Log Events (Agent)

During the vulnerability scan credential audit phase, Wazuh agents on Win7 and Win2008 will forward Windows Security Log events to the manager:

| Event ID | Meaning |
|----------|---------|
| 4625 | Failed logon |
| 4624 | Successful logon |
| 4776 | NTLM credential validation attempt |
