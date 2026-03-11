terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.0" # Use the latest stable version
    }
  }
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type    = string
  sensitive = true
}

variable "proxmox_api_token" {
  type    = string
  sensitive = true
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure = true # Set to false if you have a valid SSL cert
}

# LAN network
resource "proxmox_virtual_environment_network_linux_bridge" "lan" {
  node_name = "pve"    # Your Proxmox node name
  name      = "vmbr10"  # The name of the new bridge

  # The IPv4 address for the Proxmox host on this bridge
  address   = "10.0.10.0/24"

  # Enables VLAN tagging for VMs
  vlan_aware = true

  comment = "General VLAN Bridge managed by OpenTofu"
}

# DMZ network
resource "proxmox_virtual_environment_network_linux_bridge" "dmz" {
  node_name = "pve"    # Your Proxmox node name
  name      = "vmbr20"  # The name of the new bridge

  # The IPv4 address for the Proxmox host on this bridge
  address   = "10.0.20.0/24"

  # Enables VLAN tagging for VMs
  vlan_aware = true

  comment = "General VLAN Bridge managed by OpenTofu"
}

# fake Internet network
resource "proxmox_virtual_environment_network_linux_bridge" "extern" {
  node_name = "pve"    # Your Proxmox node name
  name      = "vmbr30"  # The name of the new bridge

  # The IPv4 address for the Proxmox host on this bridge
  address   = "10.0.30.0/24"

  comment = "General VLAN Bridge managed by OpenTofu"
}

# Management network
resource "proxmox_virtual_environment_network_linux_bridge" "management" {
  node_name = "pve"    # Your Proxmox node name
  name      = "vmbr192"  # The name of the new bridge

  # The IPv4 address for the Proxmox host on this bridge
  address   = "192.168.0.0/24"

  comment = "General VLAN Bridge managed by OpenTofu"
}