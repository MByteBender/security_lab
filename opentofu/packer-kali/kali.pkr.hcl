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
  type      = string
  sensitive = true
}

variable "kali_password" {
  type      = string
  sensitive = true
  default   = "kali"
}

source "proxmox-iso" "kali-template" {
  # Proxmox Connection
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  qemu_agent = true

  # VM Specs
  node                 = "pve"
  vm_id                = "160"
  vm_name              = "kali-template"
  pool                 = "IT-sec"
  template_description = "Kali Linux 2025.4 with Nuclei and OpenVAS/GVM — built via Packer"

  # Boot from disk first, then ISO
  boot = "order=virtio0;scsi0"
  boot_iso {
    type     = "scsi"
    iso_file = "local:iso/kali-linux-2025.4-installer-amd64.iso"
    unmount  = true
  }

  scsi_controller = "virtio-scsi-pci"

  # OpenVAS/GVM is memory-hungry — 4 GB minimum recommended
  cores  = 4
  memory = 6016

  network_adapters {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # 60 GB to accommodate GVM NVT feeds and Kali tool suite
  disks {
    disk_size    = "60G"
    storage_pool = "zfs-itsec"
    type         = "virtio"
  }

  # Packer starts an HTTP server and serves ./http/ so the installer can fetch
  # preseed.cfg before partitioning starts — no second CD needed.
  http_directory    = "./http"
  # Bind to all interfaces so the Proxmox VM can reach the HTTP server.
  http_bind_address = "0.0.0.0"
  # Fixed port so you can open exactly this port in UFW on the management server:
  #   sudo ufw allow 8802/tcp
  http_port_min     = 8802
  http_port_max     = 8802

  # Wait for the ISOLINUX menu to fully render, then drop to the boot: prompt.
  # "install" is the ISOLINUX label for the text installer in the Kali ISO.
  # "auto" (standalone) sets auto-install/enable=true in the Debian installer.
  # "auto=true" is NOT valid in modern Debian/Kali installer (Debian 12 based).
  boot_wait = "15s"
  boot_command = [
    "<esc><wait2>",
    "install auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<enter>"
  ]

  # SSH access — provisioner connects after installer reboots
  ssh_username = "kali"
  ssh_password = var.kali_password
  # gvm-setup downloads NVT feeds which can take 30–60 min
  ssh_timeout = "90m"
}

build {
  sources = ["source.proxmox-iso.kali-template"]

  # -----------------------------------------------------------------------
  # 1. Base system update
  # -----------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y qemu-guest-agent curl wget git"
    ]
  }

  # -----------------------------------------------------------------------
  # 2. Nuclei — fast, template-based vulnerability scanner by ProjectDiscovery
  #    https://docs.projectdiscovery.io/quickstart
  # -----------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      # nuclei is available directly in the Kali repositories
      "sudo apt-get install -y nuclei",
      # Pull the latest community templates after install
      "nuclei -update-templates || true"
    ]
  }

  # -----------------------------------------------------------------------
  # 3. OpenVAS / GVM — open-source vulnerability assessment (like Nessus)
  #    https://www.openvas.org
  # -----------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y gvm",
      # gvm-setup initialises the PostgreSQL databases and downloads NVT feeds.
      # This step takes 30–60 minutes depending on network speed.
      "sudo gvm-setup",
      # Verify the setup completed cleanly
      "sudo gvm-check-setup"
    ]
    # Allow up to 80 minutes for gvm-setup to download feeds
    timeout = "80m"
  }

  # -----------------------------------------------------------------------
  # 4. Template cleanup
  # -----------------------------------------------------------------------
  provisioner "shell" {
    inline = [
      "sudo apt-get clean",
      "sudo truncate -s 0 /etc/machine-id"
    ]
  }
}
