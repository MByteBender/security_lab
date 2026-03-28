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
  agent {
    enabled = true
    timeout = "2m" # Optional: gives the agent time to start up
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
    ignore_changes = all
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
      ip addr add 10.0.40.5 dev $INTERFACE
      ip link set dev $INTERFACE up
      ip route add 10.0.40.0/24 dev ens19
      ip route add 10.0.10.0/24 via 10.0.40.1 dev $INTERFACE
      ip route add 10.0.20.0/24 via 10.0.40.1 dev $INTERFACE
      ip route add 10.0.30.0/24 via 10.0.40.1 dev $INTERFACE
    EOT
  }
}