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
  type = string
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
  vm_id                = "110"
  vm_name              = "kali-template"
  pool                 = "IT-sec"
  template_description = "Kali Linux Rolling via Packer"
  qemu_agent      = true

  # Hardware Settings
  cores           = 2
  memory          = 4096

  network_adapters {
    model  = "virtio"
    bridge = "vmbr140"
  }

  scsi_controller = "virtio-scsi-pci"
  disks {
    disk_size    = "40G"
    storage_pool = "zfs-itsec"
    type         = "scsi"
  }

  boot_iso {
    type     = "ide"
    iso_file = "local:iso/kali-linux-2025.4-installer-amd64.iso"
    unmount  = true
  }

  bios = "seabios"
  machine = "q35"
  boot = "order=scsi0;ide0"

  http_directory = "http"
  boot_command = [
    "<esc><wait5>",
    "install ",
    "auto=true ",
    "priority=critical ",
    "fb=false ", # Disables framebuffer which often causes the keymap corruption
    "debian-installer/locale=en_US.UTF-8 ",
    "console-setup/ask_detect=false ",
    "keyboard-configuration/xkb-keymap=us ",
    "hw-detect/load_firmware=false ",
    "netcfg/link_wait_timeout=60 ",
    "netcfg/disable_autoconfig=true ",
    "netcfg/get_ipaddress=10.0.40.110 ",
    "netcfg/get_netmask=255.255.255.0 ",
    "netcfg/get_gateway=10.0.40.5 ",
    "netcfg/get_nameservers=8.8.8.8 ",
    "netcfg/confirm_static=true ",
    "netcfg/get_hostname=kali ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.seed ",
    # REMOVED: "initrd=initrd.gz" (This was the cause of the Line 113 error)
    # REMOVED: redundant locale/keymap lines
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
      "systemctl enable qemu-guest-agent",
      "sudo apt install kali-desktop-xfce kali-linux-default -y"
    ]
  }
}