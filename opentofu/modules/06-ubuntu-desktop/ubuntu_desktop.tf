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

variable "ubuntu_password_plain" {
    type = string
}

resource "proxmox_virtual_environment_vm" "ubuntuDesktop" {
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
  }

  network_device {
    bridge = "vmbr110"
    mac_address = "AA:11:00:14:00:00"
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
    user     = "ubuntu"             # Use the user defined in your Packer/Cloud-Init
    password = var.ubuntu_password_plain   # Or use private_key = file("~/.ssh/id_rsa")

    host     = "10.0.40.140"
  }

  provisioner "remote-exec" {
    execute_command = "echo '${var.kali_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    command = <<EOT
      sleep 20
      INTERFACE=$(ip -o link show | grep -i "AA:11:00:14:00:00" | awk -F': ' '{print $2}')
      echo $INTERFACE
      ip addr add 10.0.10.140 dev $INTERFACE
      ip link set dev $INTERFACE up
      ip route add 10.0.20.0/24 via 10.0.40.1 dev $INTERFACE
      ip route add 10.0.30.0/24 via 10.0.40.1 dev $INTERFACE
    EOT
  }

}