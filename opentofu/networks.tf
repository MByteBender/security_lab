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


# Create 4 isolated bridges
resource "proxmox_virtual_environment_network_linux_bridge" "isolated_nets" {
  for_each = toset(["10", "20", "30", "40"])

  node_name = "pve"
  name      = "vmbr${each.value}"

  # Crucial for isolation: DO NOT put anything in 'bridge_ports'
  # This makes it a "Virtual Switch" that doesn't touch physical wires.
  comment   = "Isolated network ${each.value}"
}

# This is the "Magic Button" that applies the changes to the system
resource "proxmox_virtual_environment_network_config" "apply_changes" {
  node_name = "pve"
  apply     = true

  # Ensure this only runs AFTER the bridges are created
  depends_on = [proxmox_virtual_environment_network_linux_bridge.isolated_nets]
}