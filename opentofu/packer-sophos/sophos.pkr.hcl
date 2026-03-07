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

source "proxmox-iso" "sophos-firewall" {
  # Proxmox Connection
  proxmox_url = var.proxmox_api_url
  username    = var.proxmox_api_token_id
  token       = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  # VM Specs for the Build
  node                 = "pve"
  vm_id                = "160"
  vm_name              = "sophos-template"
  pool                 = "IT-sec"
  template_description = "Sophos Firewall 21.0.1 MR 1 277 built via Packer"

    boot_iso {
        type         = "scsi"                 # Or "ide" depending on your preference
        iso_file     = "local:iso/SW-21.0.1_MR-1-277.iso"
        unmount      = true                   # Automatically removes the "CD" when finished
    }
  # Optional: un-comment to download automatically
  # iso_url = "https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
  # iso_checksum = "file:https://releases.ubuntu.com/24.04/SHA256SUMS"

  scsi_controller = "virtio-scsi-pci"

  cores   = 4
  memory  = 6016

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disks {
    disk_size         = "60G"
    storage_pool      = "zfs-itsec"
    type              = "virtio"
  }

build {
  sources = ["source.proxmox-iso.sophos-firewall"]

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