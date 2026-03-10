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
  vm_id                = "140"
  vm_name              = "win2008R2-packer-template"
  pool                 = "IT-sec"
  template_description = "Windows 7 Professional with VirtIO"
  
  # VM Hardware
  memory        = 4096
  cores          = 2
  scsi_controller      = "virtio-scsi-single"
  os                   = "win7"
  communicator         = "winrm"
  winrm_username       = "Administrator"
  winrm_password       = "Packer123!"
  winrm_timeout        = "6h"

  boot = "order=sata0;ide2"

  # Network
  network_adapters {
    model  = "e1000"
    bridge = "vmbr0"
  }

  iso_file = "local:iso/windows2008R2.iso"

  # Disks
  disks {
    disk_size         = "40G"
    storage_pool      = "zfs-itsec"
    type              = "sata" # Matches virtio-scsi-pci
  }

additional_iso_files {
    cd_files = ["./http/Autounattend.xml"]
    iso_storage_pool = "local"
    # This usually maps to 'sata1' or 'ide1' in Proxmox
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

    "<altOn><wait500ms><f4><altOff>",
    #"<ctrlOn><wait1s><esc><wait1s><ctrlOff>"
    #"<leftWin><wait1m>",
    #"powershell<enter><wait1m>",
    #"netsh interface ip set address name=\"Local Area Connection\" static 172.16.50.140 255.255.255.0<enter>"
  ]
  unmount_iso          = true
winrm_host     = "192.168.1.140"
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

