packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1"
    }
  }
}

variable "proxmox_api_url" { type = string }
variable "proxmox_api_token_id" { type = string }
variable "proxmox_api_token_secret" { type = string; sensitive = true }

source "proxmox-iso" "ubuntu-server" {
  # Proxmox Connection
  proxmox_url = var.proxmox_api_url
  username    = var.proxmox_api_token_id
  token       = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  # VM Specs for the Build
  node                 = "pve"
  vm_id                = "9000"
  vm_name              = "ubuntu-2404-template"
  template_description = "Ubuntu Server 24.04 LTS built via Packer"

  iso_file = "local:iso/ubuntu-24.04-live-server-amd64.iso"
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
    storage_pool      = "local-lvm"
    type              = "virtio"
  }

  # Cloud-Init "Autoinstall" Logic
  http_directory = "http"
  boot_command = [
    "<esc><wait>",
    "c<wait>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot<enter>"
  ]
  boot_wait = "5s"

  # SSH settings so Packer can log in to finish the setup
  ssh_username = "ubuntu"
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