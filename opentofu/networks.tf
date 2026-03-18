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

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = var.proxmox_api_token
  insecure  = true
}

# --- 2. Create the 4 Isolated Bridges ---
resource "proxmox_virtual_environment_network_linux_bridge" "isolated_nets" {
  for_each = {
      "110" = "10.0.10.1/24"
      "120" = "10.0.20.1/24"
      "130" = "10.0.30.1/24"
      "140" = "10.0.40.1/24"
      "150" = "10.0.50.1/24"
  }

  node_name = var.pve_node_name
  name      = "vmbr${each.key}"
  comment   = "Tofu-Isolated-Net-${each.key}"
  address   = each.value

}

# --- 3. The "Token-Based" Apply (The Workaround) ---
# Since the provider resource is missing, we use curl to hit the API 'Apply' endpoint.
# This uses your Token just like the rest of Tofu.

resource "null_resource" "apply_network_via_api" {
  # This triggers every time a bridge is created or changed
  triggers = {
    bridge_ids = join(",", [for b in proxmox_virtual_environment_network_linux_bridge.isolated_nets : b.id])
  }

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST "${var.proxmox_api_url}/nodes/${var.pve_node_name}/network" \
        -H "Authorization: PVEAPIToken=${var.proxmox_api_token}" \
        -k
    EOT
  }

  depends_on = [proxmox_virtual_environment_network_linux_bridge.isolated_nets]
}