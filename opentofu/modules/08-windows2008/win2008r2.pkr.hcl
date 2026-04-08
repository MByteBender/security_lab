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

source "proxmox-iso" "win2008r2" {
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true

  node                 = "pve"
  vm_id                = "160"
  vm_name              = "win2008R2-packer-template"
  pool                 = "IT-sec"
  template_description = "Windows 7 Professional with VirtIO"
  os                   = "win7"

  # VM Hardware
  memory        = 4096
  cores          = 2

  network_adapters {
    model  = "e1000"
    bridge = "vmbr140"
    firewall = false
  }

  scsi_controller      = "virtio-scsi-single"
  disks {
    disk_size         = "10G"
    storage_pool      = "zfs-itsec"
    type              = "sata"
  }

  iso_file = "local:iso/windows2008R2.iso"
  boot = "order=sata0;ide2"
  unmount_iso          = true
  additional_iso_files {
    cd_files = ["./http/Autounattend.xml"]
    iso_storage_pool = "local"
  }

  http_directory = "http"
  boot_wait = "10s"
  boot_command = [
    "<spacebar><wait>",               # 1. Press any key to boot from CD
    "<wait30s>",                      # 2. Wait for the "Install Now" screen to load
    "<shift+f10><wait>",             # 3. Open the Command Prompt (The Magic Trick)
    # 4. Manually trigger the setup using Packer's built-in web server
    "setup.exe /unattend:http://{{ .HTTPIP }}:{{ .HTTPPort }}/Autounattend.xml<enter>",
    "<wait2m><enter><wait3s>",
    "Packer123!<tab>Packer123!",
    "<enter><wait2s><enter><wait10s>",

    "<leftSuper><wait2s>powershell<wait2s><enter><wait2s>",

    "$targetMac = 'AA:11:00:15:00:00'<enter><wait1s>",
    "$adapter = Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.MACAddress -eq $targetMac }<enter><wait1s>",
    "if ($adapter) { ",
    "  $interface = $adapter.NetConnectionID; ",
    "  netsh interface ip set address name=\"$interface\" source=static addr=10.0.10.160 mask=255.255.255.0 gateway=10.0.10.1; ",
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

  communicator         = "winrm"
  winrm_username       = "Administrator"
  winrm_password       = "Packer123!"
  winrm_timeout        = "6h"
  winrm_host     = "10.0.40.160"
}

build {
  sources = ["source.proxmox-iso.win2008r2"]

provisioner "powershell" {
    inline = [
      "Write-Host 'Packer successfully connected via WinRM!'",
      "Get-Service | Where-Object {$_.Status -eq 'Running'}"
    ]
  }
}

