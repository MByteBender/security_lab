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

source "proxmox-iso" "ubuntu-server" {
  # Proxmox Connection
  proxmox_url = var.proxmox_api_url
  username    = var.proxmox_api_token_id
  token       = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  qemu_agent = true

  # VM Specs for the Build
  node                 = "pve"
  vm_id                = "130"
  vm_name              = "ubuntu-template"
  pool                 = "IT-sec"
  template_description = "Ubuntu Server 24.04 LTS built via Packer"

  cores   = 2
  memory  = 2048

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  scsi_controller = "virtio-scsi-pci"
  disks {
    disk_size         = "20G"
    storage_pool      = "zfs-itsec"
    type              = "virtio"
  }

  boot = "order=virtio0;scsi0"
  boot_iso {
        type         = "scsi"
        iso_file     = "local:iso/ubuntu-25.10-live-server-amd64.iso"
        unmount      = true
    }

  additional_iso_files {
    cd_files         = ["./http/user-data", "./http/meta-data"]
    cd_label         = "cidata"
    iso_storage_pool = "local"
    unmount          = true
  }

  boot_command = [
    "<wait><esc><wait>c<wait>",
    "linux /casper/vmlinuz autoinstall noprompt --- ds=nocloud;s=/cdrom/",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot<enter>"
  ]

  ssh_username = "ubuntu"
  ssh_password = "ubuntu"
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
      "sudo apt-get clean",
      "sudo rm /etc/sudoers.d/90-cloud-init-users"
    ]
  }
}