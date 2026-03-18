terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.0"
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
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true
}

resource "proxmox_virtual_environment_vm" "wazuh" {
  name      = "wazuh"
  node_name = "pve"
  vm_id     = 171
  pool_id   = "IT-sec"

  clone {
    vm_id = 170
    full  = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  network_device {
    bridge = "vmbr0"
  }

  agent {
    enabled = false
  }

  disk {
    datastore_id = "zfs-itsec"
    interface    = "scsi0"
    size         = 60
    file_format  = "raw"
  }
}
