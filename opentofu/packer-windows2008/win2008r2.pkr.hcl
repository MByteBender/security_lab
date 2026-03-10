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

  boot = "order=sata0;ide2"

  # Network
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  iso_file = "local:iso/windows2008R2.iso"

  # Disks
  disks {
    disk_size         = "40G"
    storage_pool      = "zfs-itsec"
    type              = "sata" # Matches virtio-scsi-pci
  }

additional_iso_files {
    device           = "sata1"
    iso_file         = "local:iso/your_scripts.iso"
    unmount          = true
  }

  boot_wait = "10s"
  boot_command = [
    "<spacebar><wait>",             # Boot from CD
    "<wait15s><shift+f10><wait>",   # Wait for Language screen, then open CMD
    # We try D, E, and F just in case drive letters shift
    "setup.exe /unattend:D:\\Autounattend.xml || setup.exe /unattend:E:\\Autounattend.xml || setup.exe /unattend:F:\\Autounattend.xml<enter>"
  ]
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

