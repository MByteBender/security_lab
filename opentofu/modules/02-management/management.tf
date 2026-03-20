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
  reboot = false

  operating_system {
    hotplug = ["network", "disk", "cpu"]
  }

  network_device {
    bridge = "vmbr0"
  }

  network_device {
    bridge = "vmbr140"
    model   = "virtio"
    mac_address = "AA:BB:CC:11:22:33"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      cpu,
      memory,
      node_name,
      scsi_hardware,
      network_device[0],
      disk,
      bios,
      # Add anything else OpenTofu keeps trying to "reset"
      # that you want to keep manual.
    ]
  }

}

resource "null_resource" "configure_network" {
  triggers = {
    mac = "AA:BB:CC:11:22:33"
  }

  provisioner "local-exec" {
    command = <<EOT
      sleep 20
      INTERFACE=$(ip -o link show | grep -i "aa:bb:cc:11:22:33" | awk -F': ' '{print $2}')
      echo $INTERFACE
      ip addr add 10.0.40.5 dev $INTERFACE || true
      ip link set dev $INTERFACE up
    EOT
  }
}