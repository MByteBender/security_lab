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
  vm_id                = "165"
  vm_name              = "win7-packer-template"
  pool                 = "IT-sec"
  template_description = "Windows 7 Professional with VirtIO"
  
  # VM Hardware
  cores                = 2
  memory               = 4096
  scsi_controller      = "virtio-scsi-single"
  os                   = "win7"
  
  # Network
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  iso_file = "local:iso/win7_64_bit.iso"

  # enter
  # wait
  # enter name


  boot_command = [
    "<wait1m>",
    "<enter><wait15s>",
    "<enter><wait2m>",
    "<enter><wait20s><enter>",
    "<wait20m>",
  ]


  # Disks
  disks {
    disk_size         = "40G"
    storage_pool      = "zfs-itsec"
    type              = "sata" # Matches virtio-scsi-pci
  }

  # ISOs: 1. Windows 7 ISO, 2. VirtIO Drivers ISO
  additional_iso_files {
    device                 = "sata1"
    unmount                = true
    cd_files               = ["./http/Autounattend.xml"]
    iso_storage_pool       = "local"
  }

  # Packer needs to know how to talk to the VM after install
  # For a "default" build without WinRM/SSH, you might just want it to finish.
  communicator         = "none"
  unmount_iso          = true

  # enter
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

