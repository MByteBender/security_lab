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

resource "proxmox_virtual_environment_vm" "windowsServer" {
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
    bridge = "vmbr140"
    model  = "e1000"
    firewall = false
    mac_address = "AA:14:00:16:00:00"
  }

  network_device {
    model  = "e1000"
    bridge = "vmbr120"
    firewall = false
    mac_address = "AA:12:00:16:00:00"
  }

  agent {
    enabled = false # Tell Proxmox not to look for the agent
  }

  # NOTE: Packer templates usually already have a disk.
  # Proxmox will automatically resize the disk if you specify a larger size here.
  disk {
    datastore_id = "zfs-itsec"
    interface    = "scsi0"
    size         = 40      # Resize template disk to 40GB
    file_format  = "raw"
  }

  connection {
    type     = "ssh"
    user     = "Administrator"             # Use the user defined in your Packer/Cloud-Init
    password = "Packer123!"   # Or use private_key = file("~/.ssh/id_rsa")
    host     = "10.0.40.160"
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        INTERFACE=$(ip -o link show | grep -i "AA:12:00:16:00:00" | awk -F': ' '{print $2}')
        echo $INTERFACE
        echo Packer123! | sudo -S ip addr add 10.0.20.160/24 dev $INTERFACE || true
        sudo ip link set $INTERFACE up

        # Add secondary IP for the gateway subnet if needed
        sudo ip addr add 10.0.30.5/24 dev $INTERFACE || true

        # Add the routes
        sudo ip route add 10.0.10.0/24 via 10.0.30.1 dev $INTERFACE || true
        sudo ip route add 10.0.30.0/24 via 10.0.30.1 dev $INTERFACE || true

        echo "Networking configuration complete."
      EOT
    ]
  }
}