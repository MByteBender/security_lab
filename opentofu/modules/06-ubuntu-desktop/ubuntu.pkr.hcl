packer {
  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = "~> 1"
    }
  }
}

variable "proxmox_api_url"               { type = string }
variable "proxmox_api_token_id"          { type = string }
variable "proxmox_api_token_secret"      {
    type = string
    sensitive = true
}
variable "ubuntu_password"               {
    type = string
    sensitive = true
    }
variable "ubuntu_password_plain"         {
    type = string
    sensitive = true
    }

source "proxmox-iso" "ubuntu-10-04-desktop" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  node                 = "pve"
  vm_id                = "140"
  vm_name              = "ubuntu-10-04-desktop-alt"
  pool                 = "IT-sec"
  template_description = "Ubuntu 10.04 Desktop Alternate via Packer"

  cores   = 2
  memory  = 2048

  network_adapters {
    model  = "e1000"
    bridge = "vmbr140"
  }

  scsi_controller = "lsi"

  disks {
    type         = "scsi"
    disk_size    = "20G"
    storage_pool = "zfs-itsec"
  }

  boot = "order=ide0"

  boot_iso {
    type     = "ide"
    iso_file = "local:iso/ubuntu-10.04.4-alternate-i386.iso"
    unmount  = true
  }

  http_directory = "http"
  http_bind_address = "10.0.40.5"
  http_port_min = 8069
  http_port_max = 8069

  boot_wait = "5s"

boot_command = [
    "<esc><wait>",
    "install ",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg ",
    "netcfg/disable_autoconfig=true ",
    "netcfg/get_ipaddress=192.168.1.10 ",
    "netcfg/get_netmask=255.255.255.0 ",
    "netcfg/get_gateway=192.168.1.1 ", # Even if it doesn't exist, d-i wants a value
    "netcfg/get_nameservers=1.1.1.1 ",
    "netcfg/confirm_static=true ",
    "hostname=ubuntu-vintage ",
    "fb=false debconf/priority=critical ",
    "<enter>"
  ]
}

  ssh_username = "ubuntu"
  ssh_password = "ubuntu"
  ssh_timeout  = "45m"
  ssh_host     = "10.0.40.140"

  ssh_key_exchange_algorithms = [
    "diffie-hellman-group14-sha1",
    "diffie-hellman-group1-sha1"
  ]

  ssh_ciphers = [
    "aes128-ctr",
    "aes192-ctr",
    "aes256-ctr",
    "aes128-cbc",
    "3des-cbc"
  ]
}

build {
  sources = ["source.proxmox-iso.ubuntu-10-04-desktop"]

  provisioner "shell" {
    execute_command = "echo ubuntu | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "echo testing"
    ]
  }
}