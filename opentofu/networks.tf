terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.0"
    }
  }
}

# --- 1. Variables (Populated by your .tfvars file) ---

variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

# The name of your Proxmox node (e.g., "pve")
variable "pve_node_name" {
  type    = string
  default = "pve"
}

# --- 2. Provider Configuration ---

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true
}

# --- 3. The 4 Isolated Bridges ---

resource "proxmox_virtual_environment_network_linux_bridge" "isolated_nets" {
  for_each = toset(["10", "20", "30", "40"])

  node_name = var.pve_node_name
  name      = "vmbr${each.value}"

  # Empty bridge_ports = Internal-only virtual switch (no physical exit)
  comment   = "Tofu-Isolated-Net-${each.value}"
}

# --- 4. The Apply Step ---
# This is CRITICAL. It tells Proxmox to commit the bridge changes.
# It uses your API token, but the token MUST have 'Administrator' role at path '/'

resource "proxmox_virtual_environment_network_config" "apply_changes" {
  node_name = var.pve_node_name
  apply     = true

  depends_on = [proxmox_virtual_environment_network_linux_bridge.isolated_nets]
}

# --- 5. Example VM ---

resource "proxmox_virtual_environment_vm" "isolated_vm" {
  name      = "kali-isolated"
  node_name = var.pve_node_name

  # Wait for the network to be live before creating the VM
  depends_on = [proxmox_virtual_environment_network_config.apply_changes]

  network_device {
    bridge = "vmbr10"
  }

  # Minimal VM settings (adjust to your needs)
  cpu {
    cores = 2
  }
  memory {
    dedicated = 2048
  }
  agent {
    enabled = true
  }
}