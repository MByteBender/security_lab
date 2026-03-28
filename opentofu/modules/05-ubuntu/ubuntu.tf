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

  # NOTE: Packer templates usually already have a disk.
  # Proxmox will automatically resize the disk if you specify a larger size here.
  disk {
    datastore_id = "zfs-itsec"
    interface    = "scsi0"
    size         = 20      # Resize template disk to 40GB
    file_format  = "raw"
  }
}

resource "null_resource" "configure_network" {
  # This ensures the script only runs AFTER the VM is created
  depends_on = [proxmox_virtual_environment_vm.ubuntu]

  connection {
    type     = "ssh"
    user     = "ubuntu"
    password = var.ubuntu_password_plain
    host     = proxmox_virtual_environment_vm.ubuntu.ipv4_addresses[1][0] # Grabs the first assigned IP
  }

  provisioner "remote-exec" {
    inline = [
      "sudo rm -f /etc/netplan/*.yaml",
      "echo 'network:
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
      addresses:
        - 192.168.110.10/24
        - 192.168.120.10/24
        - 192.168.130.10/24
        - 192.168.140.10/24
        - 10.255.0.10/24
      routes:
        - to: default
          via: 192.168.110.1
      parameters:
        stp: false
        forward-delay: 0' | sudo tee /etc/netplan/60-static-bridge.yaml",
      "sudo netplan apply"
    ]
  }
}