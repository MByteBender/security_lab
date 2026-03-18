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

variable "proxmox_api_token" {
  type    = string
  sensitive = true
}

# ---------------------------------------------------------
# 1. The Network Layer
# This module "owns" the bridges. We point to your folder.
# ---------------------------------------------------------
module "networks" {
  source    = "./modules/01-networks"   # Path to your network folder
  proxmox_api_url   = var.proxmox_api_url
  proxmox_api_token = var.proxmox_api_token
}

# ---------------------------------------------------------
# 2. The VM Layer
# ---------------------------------------------------------
module "kali" {
  source     = "./modules/02-kali"
  proxmox_api_url   = var.proxmox_api_url
  proxmox_api_token = var.proxmox_api_token
  name              = "kali"
  vm_id             = 111
  clone_vm_id       = 110
  depends_on        = [module.networks]
}

module "sophos" {
  source     = "./modules/02-sophos"
  proxmox_api_url   = var.proxmox_api_url
  proxmox_api_token = var.proxmox_api_token
  name              = "sophosFirewall"
  vm_id             = 121
  clone_vm_id       = 120
  depends_on = [module.networks]
}

module "ubuntu" {
  source     = "./modules/03-ubuntu"
  proxmox_api_url   = var.proxmox_api_url
  proxmox_api_token = var.proxmox_api_token
  name              = "ubuntu"
  vm_id             = 131
  clone_vm_id       = 130
  depends_on = [module.networks]
}

module "ubuntuDesktop" {
  source     = "./modules/05-ubuntu-desktop"
  proxmox_api_url   = var.proxmox_api_url
  proxmox_api_token = var.proxmox_api_token
  name              = "ubuntuDesktop"
  vm_id             = 141
  clone_vm_id       = 140
  depends_on = [module.networks]
}

module "win7" {
  source     = "./modules/06-win7"
  proxmox_api_url   = var.proxmox_api_url
  proxmox_api_token = var.proxmox_api_token
  name              = "win7"
  vm_id             = 151
  clone_vm_id       = 150
  depends_on = [module.networks]
}

module "windows2008" {
  source     = "./modules/07-windows2008"
  proxmox_api_url   = var.proxmox_api_url
  proxmox_api_token = var.proxmox_api_token
  name              = "windows2008Server"
  vm_id             = 161
  clone_vm_id       = 160
  depends_on = [module.networks]
}

