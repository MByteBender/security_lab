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

variable "wazuh_admin_password" {
  type      = string
  sensitive = true
  default   = "Wazuh_Admin1!"  # Change this or override via .pkrvars.hcl
}

source "proxmox-iso" "wazuh-server" {
  # Proxmox Connection
  proxmox_url = var.proxmox_api_url
  username    = var.proxmox_api_token_id
  token       = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  qemu_agent = true

  # VM Specs for the Build
  node                 = "pve"
  vm_id                = "170"
  vm_name              = "wazuh-template"
  pool                 = "IT-sec"
  template_description = "Wazuh Server (all-in-one) on Ubuntu 24.04 LTS built via Packer"

  # Set the Hard Drive (virtio0) as the FIRST priority
  boot = "order=virtio0;scsi0"
  boot_iso {
        type         = "scsi"
        iso_file     = "local:iso/ubuntu-25.10-live-server-amd64.iso"
        unmount      = true
    }

  scsi_controller = "virtio-scsi-pci"

  # Wazuh recommends at least 4 cores and 8GB RAM for an all-in-one install
  cores   = 4
  memory  = 8192

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  disks {
    disk_size         = "60G"
    storage_pool      = "zfs-itsec"
    type              = "virtio"
  }

  # Cloud-Init "Autoinstall" Logic
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

  # SSH settings so Packer can log in to finish the setup
  ssh_username = "wazuh"
  ssh_password = "wazuh"
  ssh_timeout  = "40m"
}

build {
  sources = ["source.proxmox-iso.wazuh-server"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y qemu-guest-agent curl",

      # Install Wazuh all-in-one (manager + indexer + dashboard) via quickstart script
      "curl -sO https://packages.wazuh.com/4.14/wazuh-install.sh",
      "sudo bash wazuh-install.sh -a",

      # Set a known admin password using Wazuh's password tool
      "sudo /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh -u admin -p '${var.wazuh_admin_password}'",

      # Cleanup
      "sudo truncate -s 0 /etc/machine-id",
      "sudo apt-get clean",
      "sudo rm /etc/sudoers.d/90-cloud-init-users"
    ]
  }
}
