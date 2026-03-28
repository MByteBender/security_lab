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

source "proxmox-iso" "ubuntu-server" {
  # Proxmox Connection
  proxmox_url = var.proxmox_api_url
  username    = var.proxmox_api_token_id
  token       = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  qemu_agent = true

  # VM Specs for the Build
  node                 = "pve"
  vm_id                = "130"
  vm_name              = "ubuntu-template"
  pool                 = "IT-sec"
  template_description = "Ubuntu Server 24.04 LTS built via Packer"

  cores   = 2
  memory  = 2048

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  scsi_controller = "virtio-scsi-pci"
  disks {
    disk_size         = "10G"
    storage_pool      = "zfs-itsec"
    type              = "virtio"
  }

  boot = "order=virtio0;scsi0"
  boot_iso {
        type         = "scsi"
        iso_file     = "local:iso/ubuntu-25.10-live-server-amd64.iso"
        unmount      = true
    }

  additional_iso_files {
    cd_files         = ["./http/user-data", "./http/meta-data"]
    cd_label         = "cidata"
    iso_storage_pool = "local"
    unmount          = true
  }

  boot_command = [
    "<wait><esc><wait>c<wait>",
    "linux /casper/vmlinuz autoinstall noprompt --- ds=nocloud;s=/cdrom/",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot<enter>"
  ]

  ssh_username = "ubuntu"
  ssh_password = "ubuntu"
  ssh_timeout  = "20m"
}

build {
  sources = ["source.proxmox-iso.ubuntu-server"]

  # 1. Upload the specific 5-bridge netplan from your local machine
  provisioner "file" {
    source      = "./http/5-bridge-netplan.yaml"
    destination = "/tmp/5-bridge-netplan.yaml"
  }

  provisioner "shell" {
    inline = [
      "sudo apt-get update && sudo apt-get install -y bridge-utils iptables-persistent curl",

      # 2. Install AdGuard Home
      "curl -s -S -L https://raw.githubusercontent.com/AdguardTeam/AdGuardHome/master/scripts/install.sh | sh -s -- -v",

      # 3. Setup DNS Hijacking
      #"sudo iptables -t nat -A PREROUTING -i br0 -p udp --dport 53 -j REDIRECT --to-ports 53",
      #"sudo iptables -t nat -A PREROUTING -i br0 -p tcp --dport 53 -j REDIRECT --to-ports 53",
      #"echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections",
      #"sudo sh -c 'iptables-save > /etc/iptables/rules.v4'",

      # 4. Replace the default network config with our 5-bridge plan
      "sudo rm -f /etc/netplan/*.yaml",
      "sudo mv /tmp/5-bridge-netplan.yaml /etc/netplan/60-static-bridge.yaml",
      "sudo chown root:root /etc/netplan/60-static-bridge.yaml",
      "sudo chmod 600 /etc/netplan/60-static-bridge.yaml",

      # 5. Disable Cloud-Init network management so it doesn't overwrite our file on clone
      "echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg",

      # Cleanup for a clean template
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt-get clean"
    ]
  }
}