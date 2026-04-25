terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.0" # Use the latest stable version
    }
  }
}

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token" {
  type    = string
  sensitive = true
}

variable "vm_id" {
  type = string
}

variable "name" {
  type = string
}

variable "clone_vm_id" {
  type = string
}

resource "proxmox_virtual_environment_vm" "windowsServer" {
  name      = var.name
  node_name = "pve"        # The name of your Proxmox node
  vm_id     = var.vm_id
  pool_id      = "IT-sec"

  # --- CLONE SETTINGS ---
  clone {
    vm_id = var.clone_vm_id
    full  = true           # Use 'true' for a standalone copy, 'false' for a linked clone
  }

  # --- HARDWARE SPECS ---
  cpu {
    cores = 2
    type  = "host"         # 'host' provides best performance for Linux guests
  }

  memory {
    dedicated = 4096       # RAM in MB
  }

  network_device {
    bridge = "vmbr140"
    model  = "e1000"
    firewall = false
    mac_address = "AA:14:00:16:00:00"
  }

  network_device {
    model  = "e1000"
    bridge = "vmbr120"
    firewall = false
    mac_address = "AA:12:00:16:00:00"
  }

  agent {
    enabled = false # Tell Proxmox not to look for the agent
  }

  # NOTE: Packer templates usually already have a disk.
  # Proxmox will automatically resize the disk if you specify a larger size here.
  disk {
    datastore_id = "zfs-itsec"
    interface    = "sata0"
    size         = 40      # Resize template disk to 40GB
    file_format  = "raw"
  }

  connection {
    type     = "winrm"
    user     = "Administrator"             # Use the user defined in your Packer/Cloud-Init
    password = "Packer123!"   # Or use private_key = file("~/.ssh/id_rsa")
    host     = "10.0.40.160"
    https    = false                     # Set to true only if you configured SSL in Packer
    port     = 5985                      # Standard WinRM HTTP port
    timeout  = "10m"                     # Windows 2008 boot times can be slow
  }


  provisioner "local-exec" {
    command = <<EOT
      if [ ! -f "${path.module}/http/xampp-installer.zip" ]; then
       curl -L -o "${path.module}/http/xampp-installer.zip" "https://sourceforge.net/projects/xampp/files/XAMPP%20Windows/5.6.40/xampp-win32-5.6.40-0-VC11.zip/download"
      else
        echo "XAMPP installer already exists, skipping download."
      fi
    EOT
  }

  provisioner "file" {
    source = "${path.module}/http/xampp-installer.zip"
    destination = "C:\\temp\\xampp-installer.zip"
  }

  provisioner "file" {
    source      = "${path.module}/http/bWAPPv2.2.zip"
    destination = "C:\\temp\\bWAPPv2.2.zip"
  }

  provisioner "remote-exec" {
    inline = [
      "echo select disk 0 > C:\\temp\\extend.txt",
      "echo select volume 1 >> C:\\temp\\extend.txt",
      "echo extend >> C:\\temp\\extend.txt",
      "diskpart /s C:\\temp\\extend.txt",

      "if not exist C:\\temp mkdir C:\\temp",

      "powershell -ExecutionPolicy Bypass -Command \"$targetMac = 'AA:12:00:16:00:00'; $interface = (gwmi Win32_NetworkAdapter | Where-Object { $_.MACAddress -eq $targetMac }).NetConnectionID; if ($interface) { netsh interface ip set address name=\\\"$interface\\\" source=static addr=10.0.20.160 mask=255.255.255.0 gateway=10.0.20.1; route -p add 10.0.10.0 mask 255.255.255.0 10.0.20.1; route -p add 10.0.30.0 mask 255.255.255.0 10.0.20.1 }\"",
      "powershell -Command \"$shell = New-Object -ComObject Shell.Application; $zip = $shell.NameSpace('C:\\temp\\xampp-installer.zip'); $dest = $shell.NameSpace('C:\\'); $dest.CopyHere($zip.Items())\"",
      "powershell -Command \"$shell = New-Object -ComObject Shell.Application; $zip = $shell.NameSpace('C:\\temp\\bWAPPv2.2.zip'); $dest = $shell.NameSpace('C:\\xampp\\htdocs'); $dest.CopyHere($zip.Items())\"",

      "netsh advfirewall firewall add rule name=\"Allow HTTP\" dir=in action=allow protocol=TCP localport=80",
      "powershell -Command \"(Get-WmiObject Win32_TerminalServiceSetting -Namespace root\\cimv2\\TerminalServices).SetAllowTSConnections(1,1)\"",
      "powershell -Command \"(Get-WmiObject Win32_TSGeneralSetting -Namespace root\\cimv2\\TerminalServices -Filter \\\"TerminalName='RDP-Tcp'\\\").SetUserAuthenticationRequired(0)\"",
      "Set-Service TermService -StartupType Automatic",
      "Start-Service TermService",

      "C:\\xampp\\apache\\bin\\httpd.exe -k install",
      "net start Apache2.4",

      "C:\\xampp\\mysql\\bin\\mysqld.exe --install",
      "net start mysql",

      "powershell -Command \"Start-Sleep -s 5\"",
      "powershell -Command \"$wc = New-Object System.Net.WebClient; $wc.DownloadString('http://localhost//bWAPP//install.php?install=yes')\""
   ]
  }

}