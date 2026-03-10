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

source "proxmox-iso" "win2008r2" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  node                 = "pve"
  vm_id                = "140"
  vm_name              = "win2008R2-packer-template"
  pool                 = "IT-sec"
  template_description = "Windows 7 Professional with VirtIO"
  
  # VM Hardware
  memory        = 4096
  cores          = 2
  scsi_controller      = "virtio-scsi-single"
  os                   = "win7"
  communicator         = "winrm"
  winrm_username       = "Administrator"
  winrm_password       = "Packer123!"
  winrm_timeout        = "6h"

  # Network
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  iso_file = "local:iso/windows2008R2.iso"

  boot_command = [
    "<wait10m>",
  ]


  # Disks
  disks {
    disk_size         = "40G"
    storage_pool      = "zfs-itsec"
    type              = "sata" # Matches virtio-scsi-pci
  }

  # ISOs: 1. Windows 7 ISO, 2. VirtIO Drivers ISO
  additional_iso_files {
    cd_files = ["./Autounattend.xml"]
    iso_storage_pool = "local"
  }

  unmount_iso          = true

}

build {
  sources = ["source.proxmox-iso.win2008r2"]

  # Optional: Install updates or software via PowerShell
  #provisioner "powershell" {
  #  inline = [
  #    "dir env:",
  #    "Get-Service"
  #  ]
  #}
}

