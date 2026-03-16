terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.0"
    }
  }
}

# --- 1. Variables ---
variable "proxmox_api_url" { type = string }
variable "proxmox_api_token" {
    type = string
    sensitive = true
}
variable "pve_node_name" {
    type = string
    default = "pve"
}

# --- 2. Provider ---
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

  # No bridge_ports = Internal only
  comment   = "Tofu-Isolated-Net-${each.value}"
}

# --- 4. The Corrected Apply Step ---
# In v0.70, the resource name for applying changes to a node is:
# proxmox_virtual_environment_node_network_config

resource "proxmox_virtual_environment_node_network_config" "apply_changes" {
  node_name = var.pve_node_name

  # This tells Proxmox to actually commit the bridge changes
  check = false # Skip the 'dry-run' check

  # This makes it live
  # Note: This is an empty resource in some versions, but 'check' or 'node_name'
  # triggers the internal provider logic to apply pending changes.

  depends_on = [proxmox_virtual_environment_network_linux_bridge.isolated_nets]
}
