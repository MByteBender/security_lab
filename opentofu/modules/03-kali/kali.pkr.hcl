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

variable "openvas_password" {
  type      = string
  sensitive = true
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
  cores           = 3
  memory          = 9032 # Kali Desktop likes 4GB+

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  network_adapters {
    model  = "virtio"
    bridge = "vmbr140"
    mac_address = "AA:14:00:10:00:00"
  }

  scsi_controller = "virtio-scsi-pci"
  disks {
    disk_size    = "30G"
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
    # Using the inline parameter is cleaner for multi-line scripts
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "sudo apt-get update",
      "sudo apt-get install -y qemu-guest-agent kali-desktop-xfce kali-linux-default gvm nuclei",
      "sudo systemctl enable qemu-guest-agent",

      # CREATE PERSISTENT NETWORK CONFIG
      # We write to a file so it survives the reboot into the Tofu clone
      "cat <<EOF | sudo tee /etc/network/interfaces.d/lab-setup
auto ens19
iface ens19 inet static
    address 10.0.40.10/24
    # The routes are added every time this interface comes up
    post-up ip route add 10.0.10.0/24 via 10.0.30.1
    post-up ip route add 10.0.20.0/24 via 10.0.30.1
EOF",

      # GVM Setup (Note: this is very slow)
      "sudo gvm-setup",
      "sudo runuser -u _gvm -- gvmd --user=admin --new-password=${var.openvas_password}",

      # Cleanup to reduce image size
      "sudo apt-get autoremove -y",
      "sudo apt-get clean"
    ]
  }
}