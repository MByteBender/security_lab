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
    bridge = "vmbr0"
  }

  network_device {
    bridge = "vmbr140"
    firewall = false
    mac_address = "AA:14:00:17:00:00"
  }
  # eth1 → Intern → 10.0.10.10/24
  network_device {
    bridge = "vmbr110"
    firewall = false
    mac_address = "AA:11:00:17:00:00"
  }
  # eth2 → DMZ → 10.0.20.10/24
  network_device {
    bridge = "vmbr120"
    firewall = false
    mac_address = "AA:12:00:17:00:00"
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

  connection {
    type     = "ssh"
    user     = "wazuh"             # Use the user defined in your Packer/Cloud-Init
    password = "wazuh"   # Or use private_key = file("~/.ssh/id_rsa")
    host     = "10.0.40.170"
  }

  provisioner "file" {
    source = "${path.module}/http/01-netcfg.yaml"
    destination = "/home/wazuh/01-netcfg.yaml"
  }

  provisioner "remote-exec" {
      inline = [
        <<-EOT
        sudo "wazuh" | sudo -S mv /home/wazuh/01-netcfg.yaml /etc/netplan/01-netcfg.yaml
        sudo "wazuh" | sudo -S netplan apply
        EOT
      ]
  }

}
