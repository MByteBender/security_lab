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

variable "vm_id" {
  type = string
}

variable "name" {
  type = string
}

resource "proxmox_virtual_environment_vm" "management" {
  name      = var.name
  node_name = "pve"
  vm_id     = var.vm_id

  network_device {
    bridge = "vmbr0"
  }

  network_device {
    bridge = "vmbr140"
    mac_address = "AA:BB:CC:11:22:33"
  }

  lifecycle {
    ignore_changes = [
      cores,
      cpu,
      memory,
      node_name,
      # Add anything else OpenTofu keeps trying to "reset"
      # that you want to keep manual.
    ]
  }

  provisioner "local-exec" {
    command = <<EOT
        INTERFACE=$(ip -o link show | grep -i "aa:bb:cc:11:22:33" | awk -F': ' '{print $2}')
        ip addr add 10.0.40.5 dev $INTERFACE
        ip link set $INTERFACE up
    EOT
  }
}