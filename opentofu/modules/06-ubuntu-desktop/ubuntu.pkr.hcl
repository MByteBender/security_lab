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

  qemu_agent = false

  node                 = "pve"
  vm_id                = "140"
  vm_name              = "ubuntu-10-04-desktop-alt"
  pool                 = "IT-sec"
  template_description = "Ubuntu 10.04 Desktop (Alternate ISO) via Packer"

  cores           = 2
  memory          = 2048

  network_adapters {
    model  = "e1000"
    bridge = "vmbr140"
  }

  scsi_controller = "lsi"
  disks {
    disk_size    = "20G"
    storage_pool = "zfs-itsec"
    type         = "ide"
  }

  boot = "order=ide0;ide1"
  boot_iso {
    type     = "ide"
    iso_file = "local:iso/ubuntu-10.04.4-alternate-i386.iso"
    unmount  = true
  }

  /*additional_iso_files {
    cd_files = [
      "./http/preseed.seed",
      "./http/openssh-client_5.3p1-3ubuntu3_amd64.deb",
      "./http/openssh-server_5.3p1-3ubuntu3_amd64.deb",
    ]
    cd_label = "PRESEED"
    iso_storage_pool = "local"
  }*/

  http_directory = "http"
  http_bind_address = "10.0.40.5"
  http_port_min    = 8069
http_port_max    = 8069
boot_command = [
  "<wait15>",
  "<enter><wait><f6><wait><esc>",
  "<bs><bs><bs><bs><bs><bs><bs><bs><bs><bs>",
  "install ",
  "auto=true ",
  "priority=critical ",
  "locale=en_US ",
  "kbd-chooser/method=us ",
  "netcfg/disable_dhcp=true ",
  "netcfg/confirm_static=true ",
  "netcfg/choose_interface=auto "
  "netcfg/choose_interface=eth0 ",,
  "netcfg/get_ipaddress=10.0.40.140 ",
  "netcfg/get_netmask=255.255.255.0 ",
  "netcfg/get_gateway=10.0.40.1 ",
  "netcfg/get_nameservers=8.8.8.8 ",
  "netcfg/link_wait_timeout=10 ",
  # Change the line below:
  "preseed/url=http<wait>:<wait>//10.0.40.5<wait>:<wait>{{ .HTTPPort }}<wait>/preseed.seed ",
  "initrd=/install/initrd.gz ",
  "-- <enter>"
]

  ssh_username = "ubuntu"
  ssh_password = "ubuntu" # Must match what you put in preseed.seed
  ssh_timeout  = "45m"      # Desktop installs take longer than server
  ssh_host = "10.0.40.140"


  # 2. Allow the older Key Exchange methods
  ssh_key_exchange_algorithms = [
    "diffie-hellman-group14-sha1",
    "diffie-hellman-group1-sha1"
  ]

  # 3. Allow the older Ciphers
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
    # Update your provisioner block to use single quotes around the variable
    execute_command = "echo ubuntu | sudo -S sh -c '{{ .Vars }} {{ .Path }}'"

        inline = [
          "echo testing"
        ]
    }
}