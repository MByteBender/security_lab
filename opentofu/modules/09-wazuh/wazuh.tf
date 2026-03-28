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

variable "proxmox_api_token" {
  type    = string
  sensitive = true
}

variable "vm_id" {
  type = string
}

variable "name" {
  type = string
}

variable "clone_vm_id" {
  type = string
}

resource "proxmox_virtual_environment_vm" "wazuh" {
  name      = var.name
  node_name = "pve"
  vm_id     = var.vm_id
  pool_id   = "IT-sec"

  clone {
    vm_id = var.clone_vm_id
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
    datastore_id = "zfs-itsec"
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
    enabled = true
  }

  disk {
    datastore_id = "zfs-itsec"
    interface    = "scsi0"
    size         = 30
    file_format  = "raw"
  }
}
