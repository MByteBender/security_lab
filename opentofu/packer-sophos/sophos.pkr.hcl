packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1"
    }
  }
}

# --- Fixed Variables ---
variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "vm_ip" {
  type    = string
  default = "172.16.16.16"
}

source "proxmox-iso" "sophos-firewall" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret # This maps to the secret
  insecure_skip_tls_verify = true

  # VM Specs
  node                 = "pve"
  vm_id                = "170"
  vm_name              = "sophos-template"
  pool                 = "IT-sec"
  template_description = "Sophos FW 21.0.1 MR-1 - Auto-Configured for Lab"

  boot_iso {
    type     = "ide"
    iso_file = "local:iso/SW-21.0.1_MR-1-277.iso"
    unmount  = true
  }

  scsi_controller = "virtio-scsi-single"
  cores           = 4
  memory          = 6016

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0" # Port1 (LAN)
  }

  disks {
    disk_size    = "60G"
    storage_pool = "zfs-itsec"
    type         = "scsi"
    discard      = true
    io_thread    = true
  }

  # --- THE AUTOMATION SECTION ---

  # 1. No SSH needed for Sophos
  communicator = "none"

  # 2. Detailed Keystroke Sequence
  boot_wait = "60s"
  boot_command = [
    "<enter>",
    "<wait10s>y<enter>",
    "<wait2m>y<enter>"
  ]
}

build {
  sources = ["source.proxmox-iso.sophos-firewall"]

  provisioner "shell-local" {
    # This runs on your Packer host machine
    inline = [
      "echo 'Adding temporary IP alias...'",
      "sudo ip addr add 172.16.16.100/24 dev eth0", # Use your actual interface name

      "echo 'Running Python bootstrap...'",
      "python3 bootstrap_sophos.py",

      "echo 'Cleaning up IP alias...'",
      "sudo ip addr del 172.16.16.100/24 dev eth0"
    ]
  }
}