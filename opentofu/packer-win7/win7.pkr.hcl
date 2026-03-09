packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type    = string
  sensitive = true
}

source "proxmox-iso" "win7" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  node                 = "pve"
  vm_name              = "win7-packer-template"
  template_description = "Windows 7 Professional with VirtIO"
  
  # VM Hardware
  cores                = 2
  memory               = 4096
  scsi_controller      = "virtio-scsi-pci"
  os                   = "win7"
  
  # Network
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Disks
  disks {
    disk_size         = "40G"
    format            = "raw"
    storage_pool      = "local-lvm"
    type              = "scsi" # Matches virtio-scsi-pci
  }

  # ISOs: 1. Windows 7 ISO, 2. VirtIO Drivers ISO
  iso_file = "local:iso/windows_7_install.iso"
  
# How Packer sends the answer file to the VM
  floppy_files         = ["./http/Autounattend.xml"]

  # Packer needs to know how to talk to the VM after install
  # For a "default" build without WinRM/SSH, you might just want it to finish.
  communicator         = "none"
  shutdown_timeout     = "30m"
}

build {
  sources = ["source.proxmox-iso.win7"]

  # Optional: Install updates or software via PowerShell
  provisioner "powershell" {
    inline = [
      "dir env:",
      "Get-Service"
    ]
  }
}