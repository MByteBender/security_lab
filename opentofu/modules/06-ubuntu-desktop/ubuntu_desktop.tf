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

variable "ubuntu_password_plain" {
    type = string
}

resource "proxmox_virtual_environment_vm" "ubuntuDesktop" {
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
    mac_address = "AA:14:00:14:00:00"
  }

  network_device {
    bridge = "vmbr110"
    mac_address = "AA:11:00:14:00:00"
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
    type     = "ssh"
    user     = "ubuntu"             # Use the user defined in your Packer/Cloud-Init
    password = var.ubuntu_password_plain   # Or use private_key = file("~/.ssh/id_rsa")
    host     = "10.0.40.140"
  }

provisioner "remote-exec" {
  on_failure = continue
  inline = [
    <<-EOT
      # 1. Identify the interface (likely eth1 based on your log)
      INTERFACE=$(ip -o link show | grep -i "AA:11:00:14:00:00" | awk -F': ' '{print $2}')
      INTERFACE2=$(ip -o link show | grep -i "AA:14:00:14:00:00" | awk -F': ' '{print $2}')

      # 2. Tell NetworkManager to IGNORE this interface
      # In Ubuntu 10.04, NetworkManager ignores anything in /etc/network/interfaces
      # IF 'managed=false' is set in its config.
      echo "ubuntu" | sudo -S sed -i 's/managed=true/managed=false/' /etc/NetworkManager/nm-system-settings.conf || true

      # 3. Write the PERSISTENT config to the interfaces file
      # We use 'alias' style (eth1:0) for the second IP because 10.04 handles multiple IPs best this way
      cat <<EOF | sudo tee /etc/network/interfaces
auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet static
    address 10.0.10.140
    netmask 255.255.255.0
    gateway 10.0.10.1
    # Static routes added when interface comes up
    up ip route add 10.0.10.0/24 dev $INTERFACE
    up ip route add 10.0.20.0/24 via 10.0.10.1
    up ip route add 10.0.30.0/24 via 10.0.10.1

# Adding the second IP
#auto $INTERFACE2
#iface $INTERFACE2 inet static
#    address 10.0.40.140
#    netmask 255.255.255.0
#    gateway 10.0.40.1
EOF

      # 4. Restart the legacy networking service
    echo "ubuntu" | sudo -S /etc/init.d/networking restart && sleep 10
    EOT
  ]
}

}