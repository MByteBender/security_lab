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

  # NOTE: ip_config blocks are assigned sequentially to network_device blocks.
  # The order here MUST match the order of the ip_config blocks below.
  # eth0 → Management → 10.0.255.10/24
  network_device {
    bridge = "Management"
  }
  # eth1 → Intern → 10.0.10.10/24
  network_device {
    bridge = "Intern"
  }
  # eth2 → DMZ → 10.0.20.10/24
  network_device {
    bridge = "DMZ"
  }

  initialization {
    # eth0 - Management
    ip_config {
      ipv4 {
        address = "10.0.255.10/24"
        gateway = "10.0.255.1"
      }
    }
    # eth1 - Intern
    ip_config {
      ipv4 {
        address = "10.0.10.10/24"
      }
    }
    # eth2 - DMZ
    ip_config {
      ipv4 {
        address = "10.0.20.10/24"
      }
    }
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
