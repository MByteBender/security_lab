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

variable "clone_vm_id" {
  type = string
}

resource "proxmox_virtual_environment_file" "network_config" {
  content_data = <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ens18: {dhcp4: no}
    ens19: {dhcp4: no}
    ens20: {dhcp4: no}
    ens21: {dhcp4: no}
    ens22: {dhcp4: no}
  bridges:
    br0:
      interfaces: [ens18, ens19, ens20, ens21, ens22]
      addresses: [192.168.110.10/24, 192.168.120.10/24] # etc...
EOF

  file_name = "network-config.yaml"
  node_name = "pve"
  datastore_id = "local"
  content_type = "snippets"
}

resource "proxmox_virtual_environment_vm" "ubuntu" {
  name      = var.name
  node_name = "pve"        # The name of your Proxmox node
  vm_id     = var.vm_id
  pool_id      = "IT-sec"

  # --- CLONE SETTINGS ---
  clone {
    vm_id = var.clone_vm_id
    full  = true           # Use 'true' for a standalone copy, 'false' for a linked clone
  }

  # --- HARDWARE SPECS ---
  cpu {
    cores = 2
    type  = "host"         # 'host' provides best performance for Linux guests
  }

  memory {
    dedicated = 4096       # RAM in MB
  }

  network_device {
    bridge = "vmbr110"
  }

  network_device {
    bridge = "vmbr120"
  }

  network_device {
    bridge = "vmbr130"
  }

  network_device {
    bridge = "vmbr140"
  }

  network_device {
    bridge = "vmbr1255"
  }

  agent {
    enabled = false # Tell Proxmox not to look for the agent
  }

  cicustom = "network=local:snippets/network-config.yaml"

  # NOTE: Packer templates usually already have a disk.
  # Proxmox will automatically resize the disk if you specify a larger size here.
  disk {
    datastore_id = "zfs-itsec"
    interface    = "scsi0"
    size         = 20      # Resize template disk to 40GB
    file_format  = "raw"
  }

}