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


# Create 4 isolated bridges using the v0.70+ resource naming
resource "proxmox_virtual_environment_hardware_network_bridge" "isolated_nets" {
  for_each = toset(["10", "20", "30", "40"])

  node_name = "pve"
  name      = "vmbr${each.value}"

  # No ports = isolated
  comment   = "Isolated network ${each.value}"
}

# The Apply resource also likely changed names to:
resource "proxmox_virtual_environment_node_network_config" "apply" {
  node_name = "pve"
  apply     = true

  depends_on = [proxmox_virtual_environment_hardware_network_bridge.isolated_nets]
}