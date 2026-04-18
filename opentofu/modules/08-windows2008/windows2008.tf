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
    interface    = "scsi0"
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

  provisioner "remote-exec" {
    inline = [
      "powershell -ExecutionPolicy Bypass -Command \"$targetMac = 'AA:12:00:16:00:00'; $interface = (gwmi Win32_NetworkAdapter | Where-Object { $_.MACAddress -eq $targetMac }).NetConnectionID; if ($interface) { netsh interface ip set address name=\\\"$interface\\\" source=static addr=10.0.20.160 mask=255.255.255.0 gateway=10.0.20.1; route -p add 10.0.10.0 mask 255.255.255.0 10.0.20.1; route -p add 10.0.30.0 mask 255.255.255.0 10.0.20.1 }\""
    ]
  }
}


provider "local" {}

variable "source_path" {
  default = "C:/setup/bWAPP" # Change this to your current folder
}

# 3. Move/Copy bWAPP files to the XAMPP htdocs folder
resource "null_resource" "deploy_bwapp" {
  provisioner "local-exec" {
    command = "powershell.exe -Command \"Copy-Item -Path '${var.source_path}' -Destination 'C:/xampp/htdocs/bWAPP' -Recurse -Force\""
  }
}

# 4. Use PowerShell to fix the settings.php file automatically
resource "null_resource" "configure_settings" {
  depends_on = [null_resource.deploy_bwapp]

  provisioner "local-exec" {
    command = "powershell.exe -Command \"(Get-Content C:/xampp/htdocs/bWAPP/admin/settings.php) -replace '\\$db_password = \\\"bug\\\";', '\\$db_password = \\\"\\\";' | Set-Content C:/xampp/htdocs/bWAPP/admin/settings.php\""
  }
}

# 5. Start the Services
resource "null_resource" "start_xampp" {
  depends_on = [null_resource.configure_settings]

  provisioner "local-exec" {
    command = "powershell.exe -Command \"Start-Process 'C:/xampp/apache/bin/httpd.exe' -WindowStyle Hidden; Start-Process 'C:/xampp/mysql/bin/mysqld.exe' -WindowStyle Hidden\""
  }
}