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
  default = "172.16.50.180"
}

source "proxmox-iso" "sophos-firewall" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret # This maps to the secret
  insecure_skip_tls_verify = true

  # VM Specs
  node                 = "pve"
  vm_id                = "125"
  vm_name              = "sophos-template"
  pool                 = "IT-sec"
  template_description = "Sophos FW 21.0.1 MR-1 - Auto-Configured for Lab"

  cores           = 4
  memory          = 6016

  network_adapters {
    model  = "virtio"
    bridge = "vmbr140"
  }

  scsi_controller = "virtio-scsi-single"
  disks {
    disk_size    = "10G"
    storage_pool = "zfs-itsec"
    type         = "scsi"
    discard      = true
    io_thread    = true
  }

additional_iso_files {
    cd_label         = "sophos_cfg"
    iso_storage_pool = "local" # The Proxmox datastore to temporarily hold the generated ISO

    # Option A: Read the local file and map it to a specific path on the generated ISO
     cd_files = ["${path.root}/import"]
  }

  boot_iso {
    type     = "ide"
    iso_file = "local:iso/SW-21.0.1_MR-1-277.iso"
    unmount  = true
  }

  boot_wait = "30s"
  boot_command = [
    # 1. Wait long enough for the 'Password' prompt to be solid
    "y<enter>",
    "<wait2m>y<enter>",

    "<wait70s>y<enter>",

    # 2. Clear any junk and attempt login
    "<wait15s>admin<enter>",

    # 3. Handle the 'Accept EULA' screen if it appears
    "<wait5s>a",

    "<wait10s>1<enter>",
    "<wait2s>1<enter>",
    "<wait2s><enter>",
    "<wait2s><enter>y<enter>",
    "<wait2s>10.0.40.2<enter>",
    "<enter><wait10s>",
    "<enter>n<enter>",
    "<wait5s>0<enter>",

    # Currently not needed
    # 5. Now we should be at the Main Menu (1-7). Select 4 for Device Console.
    #"<wait10s>4<enter>",
    # 6. Type the enable command. We use <wait> to ensure the console is ready.
    #"<wait6s>enableremote serverip 172.16.50.180 port 22<enter>",
  ]

  communicator = "none"
}

build {
  sources = ["source.proxmox-iso.sophos-firewall"]

  provisioner "shell-local" {
    inline = ["sleep 500"]
  }
}