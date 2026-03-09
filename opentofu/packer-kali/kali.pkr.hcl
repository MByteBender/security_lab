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

variable "kali_password" {
  type = string;
  default = "kali"
}

source "proxmox-iso" "kali-linux" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  # VM Specs
  node                 = "pve"
  vm_id                = "190"
  vm_name              = "kali-packer-template"
  pool                 = "IT-sec"
  template_description = "Kali Linux Rolling via Packer"

  # Modern Hardware Settings
  qemu_agent      = true
  scsi_controller = "virtio-scsi-pci"
  cores           = 2
  memory          = 4096 # Kali Desktop likes 4GB+

  network_adapters {
    model  = "virtio" # Use virtio for modern Linux
    bridge = "vmbr0"
  }

  disks {
    disk_size    = "40G" # Kali tools take up space
    storage_pool = "zfs-itsec"
    type         = "scsi"
  }

  # ISO Settings
  boot_iso {
    type     = "ide"
    iso_file = "local:iso/kali-linux-2025.4-installer-amd64.iso" # Update to your path
    unmount  = true
  }

  http_directory = "http"

  # Boot Command for Kali Installer
  # This sequence selects 'Install', then feeds the preseed URL
  boot_command = [
    "<esc><wait>",
    "install ",
    "auto=true ",
    "priority=critical ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/kali.preseed ",
    "hostname=kali ",
    "domain=local ",
    "interface=auto ",
    "vga=788 ",
    "initrd=initrd.gz ",
    "--- <enter>"
  ]

  ssh_username = "kali"
  ssh_password = var.kali_password
  ssh_timeout  = "60m"
}

build {
  sources = ["source.proxmox-iso.kali-linux"]

  provisioner "shell" {
    # Kali uses passwordless sudo for the default user in many cases,
    # but here we provide the password for the sudo -S command
    execute_command = "echo '${var.kali_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "apt-get update",
      "apt-get install -y qemu-guest-agent",
      "systemctl enable qemu-guest-agent"
    ]
  }
}}