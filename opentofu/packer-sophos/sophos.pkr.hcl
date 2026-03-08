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
    # 1. Start Installation (Screen 1)
    "<enter><wait5s>y<enter>", 
    
    # 2. Wait for the "Firmware Installed" message (Screen 2)
    # This usually takes 2-4 minutes.
    "<wait1m>", 
    
    # 3. Trigger the Reboot (Screen 2 - Where you are now)
    "y<enter>", 
    
    # 4. Wait for the actual Sophos OS to boot up 
    # This is where the 10-minute timer belongs.
    "<wait2m>",
    
    # Part 3: Handle Mandatory Password Change
    "admin<enter>",              

  ]
}

build {
  sources = ["source.proxmox-iso.sophos-firewall"]

  provisioner "local-exec" {
    command = "python3 bootstrap_sophos.py --ip ${var.vm_ip}"
  }
}