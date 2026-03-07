packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1"
    }
  }
}

variable "proxmox_api_url"          { type = string }
variable "proxmox_api_token_id"     { type = string }
variable "proxmox_api_token_secret" { type = string; sensitive = true }

source "proxmox-iso" "sophos-firewall" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  # VM Specs
  node                 = "pve"
  vm_id                = "160"
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
  network_adapters {
    model  = "virtio"
    bridge = "vmbr0" # Port2 (WAN)
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
  boot_wait = "10s"
  boot_command = [
    # Part 1: Initial Install
    "y<enter>", 
    
    # Part 2: Wait for Install + Reboot (Usually takes 5-8 mins on ZFS)
    "<wait10m>", 
    
    # Part 3: Handle Mandatory Password Change
    "admin<enter>",              # Initial User
    "<wait2s>admin<enter>",      # Initial Pass
    "<wait2s>LabPassword123!<enter>", # NEW Password
    "<wait2s>LabPassword123!<enter>", # Confirm NEW Password
    
    # Part 4: Access Console to enable API (Optional but recommended for Ansible)
    "<wait5s>4<enter>",          # Option 4: Device Console
    "<wait2s>system system_modules api status enable<enter>",
    "<wait1s>exit<enter>",       # Exit Console
    
    # Part 5: Shutdown to finalize Template
    "<wait2s>0<enter>",          # Option 0: Logout/Shutdown
    "<wait1s>y<enter>"           # Confirm Shutdown
  ]
}

build {
  sources = ["source.proxmox-iso.sophos-firewall"]
  # No provisioners needed!
}