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
    "<esc><wait>",
    "install ",
    # Force the interface selection here, BEFORE the preseed is even touched
    "netcfg/choose_interface=eth0 ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.seed ",
    "debian-installer=en_US ",
    "auto=true ",
    "locale=en_US ",
    "kbd-chooser/method=us ",
    "keyboard-configuration/xkb-keymap=de ",
    "netcfg/get_hostname=kali ",
    "netcfg/get_domain=local ",
    "fb=false ",
    "debconf/priority=critical ",
    "<enter>"
  ]

  ssh_username = "kali"
  ssh_password = var.kali_password
  ssh_timeout  = "60m"
}

build {
  sources = ["source.proxmox-iso.kali-linux"]

  provisioner "shell" {
    execute_command = "echo '${var.kali_password}' | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"

    # Use <<-EOT to start a multi-line string for the entire provisioner
    inline = [
      <<-EOT
        export DEBIAN_FRONTEND=noninteractive
        apt-get update
        apt-get install -y qemu-guest-agent kali-desktop-xfce kali-linux-default gvm nuclei
        systemctl enable qemu-guest-agent

        # 1. Find the interface name
        INTERFACE=$(ip -o link show | grep -i 'AA:14:00:10:00:00' | awk -F': ' '{print $2}')
        echo "Found interface: $INTERFACE"

        # 2. Write the config (The Bash heredoc now works because it's inside the HCL heredoc)
cat <<EOF | sudo tee /etc/network/interfaces.d/lab-setup
auto eth0
iface eth0 inet static
    address 10.0.30.10/24
    ip route add 10.0.10.0/24 via 10.0.30.1 dev eth1 2>/dev/null
    ip route add 10.0.20.0/24 via 10.0.30.1 dev eth1 2>/dev/null

auto eth1
iface eth1 inet static
    address 10.0.40.10/24
EOF

cat <<EOF | sudo tee /etc/NetworkManager/dispatcher.d/99-lab-routes
#!/bin/bash

if [ "\$2" = "up" ]; then

    logger "Lab routes execution attempted for interface \$1"
fi
EOF

        sudo chmod +x /etc/NetworkManager/dispatcher.d/99-lab-routes

        # 3. GVM Setup
        gvm-setup
        runuser -u _gvm -- gvmd --user=admin --new-password=${var.openvas_password}

        # 4. Cleanup
        apt-get autoremove -y
        apt-get clean
      EOT
    ]
  }
}