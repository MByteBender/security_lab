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

variable "proxmox_api_token_id" {
  type = string
}

variable "proxmox_api_token_secret" {
  type    = string
  sensitive = true
}

variable "proxmox_api_token" {
  type    = string
  sensitive = true
}

provider "proxmox" {
  endpoint = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure = true # Set to false if you have a valid SSL cert
}



# --- 1. Variables for your specific setup ---
variable "pve_host_ip" {
  default = "192.168.1.100" # CHANGE THIS to your Proxmox IP
}

variable "pve_user" {
  default = "root" # Networking requires root/sudo access
}

# --- 2. The 4 Isolated Bridges ---
# We use a null_resource to bypass the "Invalid Resource Type" errors
resource "null_resource" "create_isolated_bridges" {
  for_each = toset(["10", "20", "30", "40", "255"])

  provisioner "remote-exec" {
    inline = [
      # 1. Create the bridge if it doesn't exist (vmbr10, vmbr20, etc.)
      # We don't assign 'bridge_ports', which ensures they are isolated "islands".
      "pvesh create /nodes/pve/network --interface vmbr1${each.value} --type bridge --comments 'Tofu-Isolated-Net-${each.value}' --address 10.0.${each.value}.0 --netmask 255.255.255.0 || true",

      # 2. Apply the networking changes to make them active immediately
      "pvesh set /nodes/pve/network"
    ]

    connection {
      type     = "ssh"
      user     = var.pve_user
      host     = var.pve_host_ip
      # You must have SSH keys set up or use a password here
      private_key = file("~/.ssh/id_rsa")
    }
  }
}
