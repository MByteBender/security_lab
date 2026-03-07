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

source "proxmox-iso" "ubuntu-10-04-desktop" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  # Legacy 10.04 Settings
  qemu_agent = false # 10.04 lacks a modern guest agent by default

  node                 = "pve"
  vm_id                = "152"
  vm_name              = "ubuntu-10-04-desktop-alt"
  pool                 = "IT-sec"
  template_description = "Ubuntu 10.04 Desktop (Alternate ISO) via Packer"

  boot = "order=ide0;ide1"

  boot_iso {
    type     = "ide"
    iso_file = "local:iso/ubuntu-10.04.4-alternate-i386.iso"
    unmount  = true
  }

  # Hardware Compatibility (10.04 is happier with these)
  scsi_controller = "lsi"
  cores           = 2
  memory          = 2048

  network_adapters {
    model  = "e1000"
    bridge = "vmbr0"
  }

  disks {
    disk_size    = "20G"
    storage_pool = "zfs-itsec"
    type         = "ide"
  }

# This creates a second CD drive.
  # In 10.04, this usually appears as /dev/sr1 or /dev/sdb
  additional_iso_files {
    cd_files         = ["./http/preseed.seed"]
    cd_label         = "OEMDRV" # Some old installers look for this label specifically
    iso_storage_pool = "local"
    unmount          = true
  }

boot_command = [
  "<wait15>",
  "<enter><wait><f6><wait><esc>",
  "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
  "install ",
  "auto=true ",
  "priority=critical ",
  # We force the installer to start the network before looking for the file
  "netcfg/choose_interface=auto ",
  "netcfg/get_hostname=ubuntu-desktop ",
  "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.seed ",
  "locale=en_US ",
  "console-setup/layoutcode=us ",
  "initrd=/install/initrd.gz ",
  "-- <enter>"
]
  ssh_username = "ubuntu"
  ssh_password = "ubuntu" # Must match what you put in preseed.seed
  ssh_timeout  = "45m"      # Desktop installs take longer than server
}

build {
  sources = ["source.proxmox-iso.ubuntu-10-04-desktop"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y build-essential",
      "sudo apt-get clean"
    ]
  }
}