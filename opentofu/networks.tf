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
# 1. Create the 'Simple' Zone (The container for your 4 networks)
resource "proxmox_virtual_environment_sdn_zone_simple" "internal_zone" {
  id      = "internal" # Note: 'id' is often used instead of 'name' in newer bpg versions
  nodes   = ["pve"]    # Which nodes can see this network
}

# 2. Create the 4 Isolated VNets
resource "proxmox_virtual_environment_sdn_vnet" "isolated_nets" {
  for_each = toset(["net101", "net102", "net103", "net104"])

  id      = each.value
  zone_id = proxmox_virtual_environment_sdn_zone_simple.internal_zone.id
}

# 3. The 'Magic' Step: This resource triggers the reload
# so you don't have to click "Apply" in the GUI.
resource "proxmox_virtual_environment_sdn_applier" "apply_sdn" {
  # This tells Proxmox to actually push the config to the nodes
  # It depends on the VNets being finished first.
  depends_on = [proxmox_virtual_environment_sdn_vnet.isolated_nets]
}