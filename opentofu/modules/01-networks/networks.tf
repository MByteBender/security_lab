terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.0"
    }
  }
}

# --- 1. Variables ---
variable "proxmox_api_url" { type = string }
variable "proxmox_api_token" {
    type = string
    sensitive = true
}
variable "pve_node_name" {
    type = string
    default = "pve"
}

# --- 2. Create the 4 Isolated Bridges ---
resource "proxmox_virtual_environment_network_linux_bridge" "lan" {
  node_name = var.pve_node_name
  name      = "vmbr110"
  comment   = "Tofu-Isolated-Net-110"
}

resource "proxmox_virtual_environment_network_linux_bridge" "dmz" {
  node_name = var.pve_node_name
  name      = "vmbr120"
  comment   = "Tofu-Isolated-Net-120"
  depends_on = [
      proxmox_virtual_environment_network_linux_bridge.lan
  ]
}

resource "proxmox_virtual_environment_network_linux_bridge" "extern" {
  node_name = var.pve_node_name
  name      = "vmbr130"
  comment   = "Tofu-Isolated-Net-130"
  depends_on = [
      proxmox_virtual_environment_network_linux_bridge.dmz
  ]
}

resource "proxmox_virtual_environment_network_linux_bridge" "setup" {
  node_name = var.pve_node_name
  name      = "vmbr140"
  comment   = "Tofu-Isolated-Net-140"
  depends_on = [
      proxmox_virtual_environment_network_linux_bridge.extern
  ]
}

resource "proxmox_virtual_environment_network_linux_bridge" "management" {
  node_name = var.pve_node_name
  name      = "vmbr1255"
  comment   = "Tofu-Isolated-Net-1255"

  depends_on = [
      proxmox_virtual_environment_network_linux_bridge.setup
  ]
}
