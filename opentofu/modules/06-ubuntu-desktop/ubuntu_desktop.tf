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

variable "ubuntu_desktop_username" {
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
    user     = var.ubuntu_desktop_username             # Use the user defined in your Packer/Cloud-Init
    password = var.ubuntu_password_plain   # Or use private_key = file("~/.ssh/id_rsa")
    host     = "10.0.40.140"
  }

  provisioner "local-exec" {
    command = <<EOT
      if [ ! -f "${path.module}/http/samba_3.4.7~dfsg-1ubuntu3.10_i386.deb" ]; then
       curl -L -o "${path.module}/http/samba_3.4.7~dfsg-1ubuntu3.10_i386.deb" "https://old-releases.ubuntu.com/ubuntu/pool/main/s/samba/samba_3.4.7~dfsg-1ubuntu3.10_i386.deb"
      fi

      if [ ! -f "${path.module}/http/samba-common_3.4.7~dfsg-1ubuntu3.10_all.deb" ]; then
       curl -L -o "${path.module}/http/samba-common_3.4.7~dfsg-1ubuntu3.10_all.deb" "https://old-releases.ubuntu.com/ubuntu/pool/main/s/samba/samba-common_3.4.7~dfsg-1ubuntu3.10_all.deb"
      fi

      if [ ! -f "${path.module}/http/libwbclient0_3.4.7~dfsg-1ubuntu3.10_i386.deb" ]; then
       curl -L -o "${path.module}/http/libwbclient0_3.4.7~dfsg-1ubuntu3.10_i386.deb" "https://old-releases.ubuntu.com/ubuntu/pool/main/s/samba/libwbclient0_3.4.7~dfsg-1ubuntu3.10_i386.deb"
      fi

      if [ ! -f "${path.module}/http/samba-common-bin_3.4.7~dfsg-1ubuntu3.10_i386.deb" ]; then
       curl -L -o "${path.module}/http/samba-common-bin_3.4.7~dfsg-1ubuntu3.10_i386.deb" "https://old-releases.ubuntu.com/ubuntu/pool/main/s/samba/samba-common-bin_3.4.7~dfsg-1ubuntu3.10_i386.deb"
      fi

      if [ ! -f "${path.module}/http/vsftpd_2.2.2-3ubuntu6.3_i386.deb" ]; then
       curl -L -o "${path.module}/http/vsftpd_2.2.2-3ubuntu6.3_i386.deb" "https://old-releases.ubuntu.com/ubuntu/pool/main/v/vsftpd/vsftpd_2.2.2-3ubuntu6.3_i386.deb"
      fi

      if [ ! -f "${path.module}/http/cups_1.4.3-1ubuntu1.14_i386.deb" ]; then
       curl -L -o "${path.module}/http/cups_1.4.3-1ubuntu1.14_i386.deb" "https://old-releases.ubuntu.com/ubuntu/pool/main/c/cups/cups_1.4.3-1ubuntu1.14_i386.deb"
      fi
    EOT
  }

  provisioner "file" {
    source = "${path.module}/http/samba_3.4.7~dfsg-1ubuntu3.10_i386.deb"
    destination = "/home/ubuntu/samba_3.4.7~dfsg-1ubuntu3.i386.deb"
  }

  provisioner "file" {
    source = "${path.module}/http/samba-common_3.4.7~dfsg-1ubuntu3.10_all.deb"
    destination = "/home/ubuntu/samba-common_3.4.7~dfsg-1ubuntu3.10_all.deb"
  }

  provisioner "file" {
    source = "${path.module}/http/libwbclient0_3.4.7~dfsg-1ubuntu3.10_i386.deb"
    destination = "/home/ubuntu/libwbclient0_3.4.7~dfsg-1ubuntu3.10_i386.deb"
  }

  provisioner "file" {
    source = "${path.module}/http/samba-common-bin_3.4.7~dfsg-1ubuntu3.10_i386.deb"
    destination = "/home/ubuntu/samba-common-bin_3.4.7~dfsg-1ubuntu3.10_i386.deb"
  }

  provisioner "file" {
    source = "${path.module}/http/vsftpd_2.2.2-3ubuntu6.3_i386.deb"
    destination = "/home/ubuntu/vsftpd_2.2.2-3ubuntu6.3_i386.deb"
  }

  provisioner "file" {
    source = "${path.module}/http/cups_1.4.3-1ubuntu1.14_i386.deb"
    destination = "/home/ubuntu/cups_1.4.3-1ubuntu1.14_i386.deb"
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
      echo "${var.ubuntu_password_plain}" | sudo -S sed -i 's/managed=true/managed=false/' /etc/NetworkManager/nm-system-settings.conf || true

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
    post-up ip route add 10.0.20.0/24 via 10.0.10.1 dev $INTERFACE
    post-up ip route add 10.0.30.0/24 via 10.0.10.1 dev $INTERFACE

# Adding the second IP
auto $INTERFACE2
iface $INTERFACE2 inet static
    address 10.0.40.140
    netmask 255.255.255.0
    gateway 10.0.40.1
EOF

    echo "${var.ubuntu_password_plain}" | sudo -S service network-manager stop || true
    echo "${var.ubuntu_password_plain}" | sudo -S bash -c "nohup /etc/init.d/networking restart > /dev/null 2>&1 &"

    # Give it a moment to trigger before the provisioner finishes
    sleep 2
    ip a && sleep 2
    EOT
  ]
}

provisioner "remote-exec" {
  inline = [
    <<-EOT
     echo "ubuntu" | sudo sysctl -w kernel.randomize_va_space=0

     echo "ubuntu" | sudo -S service apparmor stop
     echo "ubuntu" | sudo -S update-rc.d -f apparmor remove

     echo "ubuntu" | sudo -S iptables -F
     echo "ubuntu" | sudo -S iptables -X
     echo "ubuntu" | sudo -S iptables -t nat -F
     echo "ubuntu" | sudo -S iptables -t nat -X
     echo "ubuntu" | sudo -S iptables -P INPUT ACCEPT
     echo "ubuntu" | sudo -S iptables -P FORWARD ACCEPT
     echo "ubuntu" | sudo -S iptables -P OUTPUT ACCEPT

     echo "ubuntu" | sudo -S dpkg -i libwbclient0_3.4.7~dfsg-1ubuntu3.10_i386.deb
     echo "ubuntu" | sudo -S dpkg -i samba-common_3.4.7~dfsg-1ubuntu3.10_all.deb
     echo "ubuntu" | sudo -S dpkg -i samba-common-bin_3.4.7~dfsg-1ubuntu3.10_i386.deb
     echo "ubuntu" | sudo -S dpkg -i samba_3.4.7~dfsg-1ubuntu3.i386.deb
     echo "ubuntu" | sudo -S dpkg -i vsftpd_2.2.2-3ubuntu6.3_i386.deb
     echo "ubuntu" | sudo -S dpkg -i --force-depends cups_1.4.3-1ubuntu1.14_i386.deb

     echo "ubuntu" | sudo -S bash -c 'cat << CUSTOM_CONF > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   netbios name = VULN-UBUNTU
   security = share
   null passwords = yes
   guest account = nobody
   log level = 1

[Highly_Sensitive_Files]
   path = /
   browseable = yes
   read only = no
   guest ok = yes
CUSTOM_CONF'

echo "ubuntu" | sudo -S service smbd restart

echo "ubuntu" | sudo -S cupsctl --remote-admin --remote-any --share-printers

# Alternatively, manually force the config
sudo bash -c 'cat << VULN_CUPS > /etc/cups/cupsd.conf
Listen *:631
Listen /var/run/cups/cups.sock
Browsing On
BrowseOrder allow,deny
BrowseAllow all
<Location />
  Order allow,deny
  Allow all
</Location>
<Location /admin>
  Order allow,deny
  Allow all
</Location>
VULN_CUPS'

echo "ubuntu" | sudo -S service cups restart

echo "ubuntu" | sudo -S bash -c 'cat << VULN_FTP > /etc/vsftpd.conf
listen=YES
anonymous_enable=YES
no_anon_password=YES
write_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/private/vsftpd.pem
VULN_FTP'

sudo mkdir -p /var/run/vsftpd/empty
echo "ubuntu" | sudo -S vsftpd -etc-vsftpd.conf

echo "ubuntu" | sudo -S bash -c 'while true; do echo "SSH-2.0-OpenSSH_4.3" | nc -l -p 2222; done' &
echo "ubuntu" | sudo -S bash -c 'while true; do nc -l -p 6667 -e /bin/sh; done' &
    EOT
  ]
}

}