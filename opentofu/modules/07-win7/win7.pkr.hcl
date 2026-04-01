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

  boot_iso {
    type         = "sata"
    index        = 0
    iso_file     = "local:iso/win7_64_bit.iso"
    unmount      = true
  }

  boot_command = [
    "<wait1m>",
    "<enter><wait15s>",
    "<enter><wait150s>",
    "<enter><wait5s><enter><wait5s><enter>",
    "<wait1m>",


    "<leftSuper><wait2s>powershell<wait2s><enter><wait2s>",
    "Start-Process powershell -Verb RunAs",
    "<wait1s><enter><wait1s><left><wait1s><enter><wait10>",

# ... after the RunAs Admin window opens ...

    # Set Static IP (Hardcode the name to be safe)
    "netsh interface ip set address name=\"Local Area Connection\" source=static addr=10.0.40.150 mask=255.255.255.0 gateway=10.0.40.5<enter><wait5s>",

    "powershell -NonInteractive -Command \"$net = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]'{DCB00C01-570F-4A9B-8D69-199FDBA5723B}')); $net.GetNetworkConnections() | ForEach-Object {$_.GetNetwork().SetCategory(1)}\""

    # FORCE the network to Work/Private via Registry (The Global Assignment)
    "reg add \"HKLM\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\CurrentVersion\\NetworkList\\DefaultAssignments\" /v Unknown /t REG_DWORD /d 1 /f<enter><wait2s>",
    "reg add \"HKLM\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System\" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f<enter><wait2s>",

    # RESTART THE ADAPTER (This forces the Registry change to take effect)
    "netsh interface set interface name=\"Local Area Connection\" admin=disabled<enter><wait2s>",
    "netsh interface set interface name=\"Local Area Connection\" admin=enabled<enter><wait10s>",

    # MANUALLY CONFIGURE WinRM (Avoids the 'Quickconfig' Public error)
    "powershell -Command \"Set-Service winrm -StartupType 'Automatic'\"<enter><wait1s>",
    "powershell -Command \"Start-Service winrm\"<enter><wait1s>",
    "winrm set winrm/config/service/auth '@{Basic=\"true\"}'<enter><wait1s>",
    "winrm set winrm/config/service '@{AllowUnencrypted=\"true\"}'<enter><wait1s>",
    "winrm set winrm/config/client '@{TrustedHosts=\"*\"}'",
    "winrm create winrm/config/listener?Address=*+Transport=HTTP<enter><wait2s>",

    # Firewall - Allow on ANY profile
    "netsh advfirewall firewall add rule name=\"WinRM 5985\" protocol=TCP dir=in localport=5985 action=allow profile=any<enter><wait2s>",
  ]

  additional_iso_files {
    device                 = "sata1"
    unmount                = true
    cd_files               = ["./http/Autounattend.xml"]
    iso_storage_pool       = "local"
  }


  # enter

  communicator         = "winrm"
  winrm_username       = "packer"
  winrm_password       = "packer"
  winrm_timeout        = "6h"
  winrm_host     = "10.0.40.150"
  winrm_insecure = true
  winrm_use_ssl = false

}

build {
  sources = ["source.proxmox-iso.win7"]

}


