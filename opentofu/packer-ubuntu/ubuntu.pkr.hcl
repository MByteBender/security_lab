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

source "proxmox-iso" "ubuntu-server" {
  # Proxmox Connection
  proxmox_url = var.proxmox_api_url
  username    = var.proxmox_api_token_id
  token       = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  # VM Specs for the Build
  node                 = "pve"
  vm_id                = "150"
  vm_name              = "ubuntu-template"
  pool                 = "IT-sec"
  template_description = "Ubuntu Server 24.04 LTS built via Packer"

  # Set the Hard Drive (virtio0) as the FIRST priority
  boot = "order=virtio0;scsi0"
  boot_iso {
        type         = "scsi"                 # Or "ide" depending on your preference
        iso_file     = "local:iso/ubuntu-25.10-live-server-amd64.iso"
        unmount      = true                   # Automatically removes the "CD" when finished
    }
  # Optional: un-comment to download automatically
  # iso_url = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
  # iso_checksum = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"

  scsi_controller = "virtio-scsi-pci"

  cores   = 2
  memory  = 2048

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disks {
    disk_size         = "20G"
    storage_pool      = "zfs-itsec"
    type              = "virtio"
  }

  # Cloud-Init "Autoinstall" Logic
  additional_iso_files {
    cd_files         = ["./http/user-data", "./http/meta-data"]
    cd_label         = "cidata"
    iso_storage_pool = "local" # Change to your ISO storage name
    unmount          = true
  }

  # Update the boot command to look at /cdrom/ instead of http
  boot_command = [
    "<wait><esc><wait>c<wait>",
    "linux /casper/vmlinuz autoinstall noprompt --- ds=nocloud;s=/cdrom/",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot<enter>"
  ]

  # SSH settings so Packer can log in to finish the setup
  ssh_username = "ubuntu"
  ssh_password = "${var.ssh_pass}"
  ssh_timeout  = "20m"
}

build {
  sources = ["source.proxmox-iso.ubuntu-server"]

  # Final cleanup and QEMU agent install
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y qemu-guest-agent",
      "sudo truncate -s 0 /etc/machine-id", # Clean machine ID for cloning
      "sudo apt-get clean"
    ]
  }
}