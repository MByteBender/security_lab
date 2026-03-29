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
    type     = "winrm"
    user     = "Administrator"             # Use the user defined in your Packer/Cloud-Init
    password = "Packer123!"   # Or use private_key = file("~/.ssh/id_rsa")
    host     = "10.0.40.160"
    https    = false                     # Set to true only if you configured SSL in Packer
    port     = 5985                      # Standard WinRM HTTP port
    timeout  = "10m"                     # Windows 2008 boot times can be slow
  }

provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Bypass -Command \"$targetMac = 'AA:12:00:16:00:00'; $interface = (gwmi Win32_NetworkAdapter | Where-Object { $_.MACAddress -eq $targetMac }).NetConnectionID; if ($interface) { netsh interface ip set address name=\\\"$interface\\\" source=static addr=10.0.10.140 mask=255.255.255.0 gateway=10.0.40.1; route -p add 10.0.20.0 mask 255.255.255.0 10.0.40.1; route -p add 10.0.30.0 mask 255.255.255.0 10.0.40.1 }\""
    ]
  }
}