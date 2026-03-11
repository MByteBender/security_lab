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

# 1. Define the SDN Zone (The 'Container')
resource "proxmox_virtual_environment_network_sdn_zone" "internal_zone" {
  name = "internal"
  type = "simple"
}

# 2. Define the 4 Isolated Networks
resource "proxmox_virtual_environment_network_sdn_vnet" "isolated_nets" {
  for_each = toset(["net101", "net102", "net103", "net104"])

  name    = each.value
  zone_id = proxmox_virtual_environment_network_sdn_zone.internal_zone.id
}

# 3. (Optional) Define IP ranges for them
resource "proxmox_virtual_environment_network_sdn_subnet" "subnets" {
  for_each = {
    "net101" = "10.0.1.0/24"
    "net102" = "10.0.2.0/24"
    "net103" = "10.0.3.0/24"
    "net104" = "10.0.4.0/24"
  }

  vnet_id = each.key
  cidr    = each.value
  # No gateway defined = No internet/inter-vnet routing = Total Isolation
}