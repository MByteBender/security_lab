packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
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

source "proxmox-iso" "win7" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  node                 = "pve"
  vm_id                = "150"
  vm_name              = "win7-packer-template"
  pool                 = "IT-sec"
  template_description = "Windows 7 Professional with VirtIO"
  os                   = "win7"

  # VM Hardware
  cores                = 2
  memory               = 4096

  network_adapters {
    bridge = "vmbr140"
    model  = "e1000"
    mac_address = "AA:14:00:15:00:00"
  }

  scsi_controller      = "virtio-scsi-single"
  disks {
    disk_size         = "10G"
    storage_pool      = "zfs-itsec"
    type              = "sata"
  }

  iso_file = "local:iso/win7_64_bit.iso"
  boot_command = [
    "<wait1m>",
    "<enter><wait15s>",
    "<enter><wait150s>",
    "<enter><wait5s><enter><wait5s><enter>",
    "<wait1m><enter>",


    "<leftSuper><wait2s>powershell<wait2s><enter><wait2s>",

    "$targetMac = 'AA:14:00:15:00:00'<enter><wait1s>",
    "$adapter = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.MACAddress -eq $targetMac }<enter><wait1s>",
    "if ($adapter) { ",
    "  $interface = $adapter.NetConnectionID; ",
    "  netsh interface ip set address name=\"$interface\" source=static addr=10.0.10.150 mask=255.255.255.0 gateway=10.0.40.1; ",
    "} ",
    "<enter><wait2s>",

    "netsh interface set interface name=\"$interface\" admin=disabled<enter><wait2s>",
    "netsh interface set interface name=\"$interface\" admin=enabled<enter><wait2s>",
    "netsh advfirewall firewall add rule name=\"Allow Ping\" protocol=ICMPV4 dir=in action=allow<enter><wait2s>",

    # 1. Enable WinRM service and set to Auto-start
    "powershell -Command \"Set-Service WinRM -StartupType Automatic\"<enter><wait2s>",
    "powershell -Command \"Start-Service WinRM\"<enter><wait5s>",

    # 2. Configure WinRM for Basic Auth and Unencrypted traffic (standard for Packer)
    "powershell -Command \"winrm quickconfig -q\"<enter><wait2s>",
    "winrm set winrm/config/service/auth '@{Basic=\"true\"}'<enter><wait2s>",
    "winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}'<enter><wait2s>",

    # 3. Explicitly allow WinRM through Windows Firewall
    "netsh advfirewall firewall add rule name=\"WinRM 5985\" protocol=TCP dir=in localport=5985 action=allow<enter><wait2s>"

  ]

  additional_iso_files {
    device                 = "sata1"
    unmount                = true
    cd_files               = ["./http/Autounattend.xml"]
    iso_storage_pool       = "local"
  }

  # Packer needs to know how to talk to the VM after install
  # For a "default" build without WinRM/SSH, you might just want it to finish.
  communicator         = "none"
  unmount_iso          = true

  # enter
}

build {
  sources = ["source.proxmox-iso.win7"]

  # Optional: Install updates or software via PowerShell
  #provisioner "powershell" {
  #  inline = [
  #    "dir env:",
  #    "Get-Service"
  #  ]
  #}
}

