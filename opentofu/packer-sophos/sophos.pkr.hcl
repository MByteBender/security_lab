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

variable "sudo_password" {
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
  boot_wait = "30s"
boot_command = [
  # 1. Wait long enough for the 'Password' prompt to be solid
  "y<enter>",
  "<wait2m>y<enter>",

  "<wait90s>y<enter>",

  # 2. Clear any junk and attempt login
  "<wait15s>admin<enter>",

  # 3. Handle the 'Accept EULA' screen if it appears
  "<wait5s>a",

  # 5. Now we should be at the Main Menu (1-7). Select 4 for Device Console.
  "<wait15s>4<enter>",

  # 6. Type the enable command. We use <wait> to ensure the console is ready.
  "<wait10s>enableremote -i 172.16.16.100 -p 22<enter>",

  "<wait10m>"

  # 7. CRITICAL: By default, Sophos only allows the API from specific IPs.
  # This command tells it to allow the API from EVERYWHERE on the LAN.
  # 8. Exit back to main menu
  #"<wait2s>exit<enter>",
  #"0<enter>"
]
}

build {
  sources = ["source.proxmox-iso.sophos-firewall"]

  provisioner "shell-local" {
      inline = [
        "echo '${var.sudo_password}' | sudo -S ip addr add 172.16.16.100/24 dev ens18",
        "python3 bootstrap_sophos.py",
        "echo '${var.sudo_password}' | sudo -S ip addr del 172.16.16.100/24 dev ens18"
      ]
  }
}