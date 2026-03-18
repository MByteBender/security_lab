# LAN network
resource "proxmox_virtual_environment_network_linux_bridge" "intern" {
  node_name = "pve"    # Your Proxmox node name
  name      = "Intern"  # The name of the new bridge
  # Enables VLAN tagging for VMs
  vlan_aware = true

  comment = "General VLAN Bridge managed by OpenTofu"
}

# DMZ network
resource "proxmox_virtual_environment_network_linux_bridge" "dmz" {
  node_name = "pve"    # Your Proxmox node name
  name      = "DMZ"  # The name of the new bridge
  # Enables VLAN tagging for VMs
  vlan_aware = true

  comment = "General VLAN Bridge managed by OpenTofu"
}

# fake Internet network
resource "proxmox_virtual_environment_network_linux_bridge" "untrusted" {
  node_name = "pve"    # Your Proxmox node name
  name      = "Untrusted"  # The name of the new bridge
  comment = "General VLAN Bridge managed by OpenTofu"
}

# Management network
resource "proxmox_virtual_environment_network_linux_bridge" "management" {
  node_name = "pve"    # Your Proxmox node name
  name      = "Management"  # The name of the new bridge
  comment = "General VLAN Bridge managed by OpenTofu"
}