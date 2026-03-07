packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1"
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

variable "ubuntu_password" {
  type    = string
  sensitive = true
}

variable "ubuntu_password_plain" {
  type    = string
  sensitive = true
}

source "proxmox-iso" "ubuntu-desktop-10-04" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  # 10.04 might need the older 'virtio' or even 'ide' for stability
  qemu_agent = false # 10.04 doesn't have native easy guest-agent support

  node                 = "pve"
  vm_id                = "151"
  vm_name              = "ubuntu-10-04-desktop"
  pool                 = "IT-sec"
  template_description = "Ubuntu 10.04 Desktop built via Packer"

  boot = "order=ide0;ide1" # Older OS often prefers IDE for the boot drive

  boot_iso {
    type     = "ide"
    iso_file = "local:iso/ubuntu-10.04.4-desktop-i386.iso"
    unmount  = true
  }

  scsi_controller = "lsi" # More compatible with 2010-era kernels

  cores   = 2
  memory  = 2048

  network_adapters {
    model  = "e1000" # More likely to have drivers in 10.04 than virtio
    bridge = "vmbr0"
  }

  disks {
    disk_size    = "20G"
    storage_pool = "zfs-itsec"
    type         = "ide"
  }

  # 10.04 uses a local HTTP server or Floppy for preseed,
  # but here we'll use the boot_command to point to a preseed file.
  http_directory = "http"

  # The 10.04 Boot Command (Legacy Preseed Style)
boot_command = [
    "<wait10>",          // Give Proxmox/BIOS plenty of time to start the VGA
    "<esc><wait>",       // Clear the "language icon" screen
    "<esc><wait>",       // If the language menu is open, clear it
    "<f6><wait><esc>",   // F6 opens the options menu, ESC closes the popup but keeps the line open
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>", // Backspace to clear "quiet splash --"
    "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
    "auto=true ",
    "priority=critical ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.seed ",
    "debian-installer/locale=en_US ",
    "console-setup/layoutcode=us ",
    "hostname=ubuntu-desktop ",
    "initrd=/casper/initrd.lz ",
    "root=/dev/ram0 ",
    "boot=casper ",
    "automatic-ubiquity ",
    "-- <enter>"
  ]

  ssh_username = "ubuntu"
  ssh_password = "ubuntu" # Match what's in your preseed
  ssh_timeout  = "20m"
}

build {
  sources = ["source.proxmox-iso.ubuntu-desktop-10-04"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y x11vnc", # Example desktop tool
      "sudo apt-get clean"
    ]
  }
}