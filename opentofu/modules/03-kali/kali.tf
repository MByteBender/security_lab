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

variable "kali_username" {
  type = string
}

variable "kali_password" {
  type = string
  sensitive = true
}

resource "proxmox_virtual_environment_vm" "kali" {
  name      = var.name
  node_name = "pve"
  vm_id     = var.vm_id
  pool_id   = "IT-sec"

  # --- CLONE SETTINGS ---
  clone {
    vm_id = var.clone_vm_id
    full  = true           # Use 'true' for a standalone copy, 'false' for a linked clone
  }

  # --- HARDWARE SPECS ---
  cpu {
    cores = 3
    type  = "host"         # 'host' provides best performance for Linux guests
  }

  memory {
    dedicated = 9032       # RAM in MB
  }

  network_device {
    bridge = "vmbr130"
    mac_address = "AA:13:00:11:00:00"
  }

  network_device {
    bridge = "vmbr140"
    mac_address = "AA:14:00:11:00:00"
  }

  agent {
    enabled = false # Tell Proxmox not to look for the agent
  }

  # NOTE: Packer templates usually already have a disk.
  # Proxmox will automatically resize the disk if you specify a larger size here.
  disk {
    datastore_id = "zfs-itsec"
    interface    = "scsi0"
    size         = 60      # Resize template disk to 40GB
  }

  connection {
    type     = "ssh"
    user     = var.kali_username             # Use the user defined in your Packer/Cloud-Init
    password = var.kali_password   # Or use private_key = file("~/.ssh/id_rsa")
    host     = "10.0.40.110"
  }

provisioner "file" {
    source      = "${path.module}/http/vulnerabilityScan.sh" # Path on your local machine
    destination = "/home/kali/vulnerabilityScan.sh"    # Path on the VM
  }

# handles network
provisioner "remote-exec" {
    on_failure = continue
    inline = [
        <<-EOT
          INTERFACE2=$(ip -o link show | grep -i 'AA:14:00:11:00:00' | awk -F': ' '{print $2}')
          INTERFACE=$(ip -o link show | grep -i 'AA:13:00:11:00:00' | awk -F': ' '{print $2}')
          echo "Found interface: $INTERFACE"
          echo "Found interface: $INTERFACE2"

          echo "${var.kali_password}" | sudo -S sed -i 's/^.*inet dhcp/#&/g' /etc/network/interfaces
          echo "${var.kali_password}" | sudo -S rm /etc/network/interfaces.d/initial-setup

          echo "${var.kali_password}" | sudo -S systemctl stop dhcpcd
          echo "${var.kali_password}" | sudo -S systemctl disable dhcpcd
          echo "${var.kali_password}" | sudo -S systemctl stop NetworkManager
          echo "${var.kali_password}" | sudo -S systemctl disable NetworkManager
          echo "${var.kali_password}" | sudo -S systemctl stop avahi-daemon
          echo "${var.kali_password}" | sudo -S systemctl disable avahi-daemon

          echo "${var.kali_password}" | sudo -S rm /etc/cloud/cloud.cfg.d/*
          echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

          echo "${var.kali_password}" | sudo -S chmod 000 /sbin/dhclient /sbin/udhcpc /usr/sbin/dhcpcd 2>/dev/null

          echo "${var.kali_password}" | sudo -S rm -rf /etc/network/interfaces.d/*
          echo "${var.kali_password}" | sudo -S rm -rf /etc/systemd/network/*
          echo "${var.kali_password}" | sudo -S pkill -9 dhclient udhcpc dhcpcd NetworkManager
          echo "kali" | sudo -S rm -rf /etc/network/interfaces.d/*
          echo "kali" | sudo -S rm -rf /etc/systemd/network/*
          echo "kali" | sudo -S pkill -9 dhclient udhcpc dhcpcd NetworkManager

echo "${var.kali_password}" | sudo -S systemctl mask --now dhcpcd dhcpcd5 NetworkManager systemd-networkd avahi-daemon 2>/dev/null

# 3. WIPE ALL PERSISTENCE (The "Memory" of the system)
# This deletes leases, saved states, and temporary interface files
echo "${var.kali_password}" | sudo -S rm -rf /var/lib/dhcp/* /var/lib/dhcpcd/* /var/lib/NetworkManager/* /var/lib/systemd/network/*
echo "${var.kali_password}" | sudo -S rm -f /etc/network/interfaces.d/*
echo "${var.kali_password}" | sudo -S rm -f /run/network/ifstate

# 4. PURGE NETWORK HOOKS
# These are the hidden scripts that trigger DHCP on "link up" events
echo "${var.kali_password}" | sudo -S rm -rf /etc/network/if-up.d/dhcpcd /etc/network/if-pre-up.d/dhcpcd /lib/dhcpcd/dhcpcd-hooks/*

# 5. KILL THE GHOSTS
# Forcefully kill any process even thinking about networking
echo "${var.kali_password}" | sudo -S pkill -9 -e "dhcpcd|dhclient|udhcpc|NetworkManager|avahi-daemon"

echo "${var.kali_password}" | sudo -S bash -c "cat <<EOF | tee /etc/network/interfaces.d/setup
auto $INTERFACE
iface $INTERFACE inet static
    address 10.0.30.110/24
    post-up ip route add 10.0.10.0/24 via 10.0.30.1 dev $INTERFACE
    post-up ip route add 10.0.20.0/24 via 10.0.30.1 dev $INTERFACE

auto $INTERFACE2
iface $INTERFACE2 inet static
    address 10.0.40.110/24
EOF"

echo '${var.kali_password}' | sudo -S systemctl restart networking && sleep 5
ip a && sleep 2
      EOT
    ]
  }


provisioner "remote-exec" {
    inline = [
      # Make it executable
      "chmod +x /home/kali/vulnerabilityScan.sh",
    ]
  }

}