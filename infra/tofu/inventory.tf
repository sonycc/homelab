# Renders infra/ansible/inventory.ini from vm_addresses on every apply, so the LAN
# addresses in it cannot drift from the DHCP leases the guest agent reports.

variable "ansible_user" {
  description = "Login on the VMs. Matches the user_account username in vm-*.tf."
  type        = string
  default     = "sondre"
}

variable "ansible_ssh_private_key_file" {
  description = "Private key matching the public key injected in vm-*.tf."
  type        = string
  default     = "~/.ssh/homelab_infra"
}

# Which game hosts exist,
#   tofu has no resource for a machine on someone else's estate,
#   nor for the bastion in front of it.
# The value is an ssh_config alias, which Ansible and game_backup resolve with ssh -G.
variable "games" {
  description = "Game hosts tofu does not provision, as name => ssh_config alias."
  type        = map(string)
  default     = {}
}

locals {
  # Group names use underscores; Ansible warns on hyphens. Host names keep theirs.
  inventory_groups = join("\n\n", [
    for name, vm in local.vm_addresses :
    "[${replace(name, "-", "_")}]\n${name} ansible_host=${vm.lan} internal_ip=${vm.internal} vm_id=${vm.vm_id}"
  ])

  inventory_children = join("\n", [
    for name, vm in local.vm_addresses : replace(name, "-", "_")
  ])

  # Rendered into their own group with their own ansible_user. Terraform can only
  # provision root's key in an LXC — there is no cloud-init to create an admin
  # account — so these connect as root where the VMs connect as sondre.
  vps_groups = join("\n\n", [
    for name, ct in local.ct_addresses :
    "[${replace(name, "-", "_")}]\n${name} ansible_host=${ct.lan} internal_ip=${ct.internal} vm_id=${ct.vm_id}"
  ])

  vps_children = join("\n", [
    for name, ct in local.ct_addresses : replace(name, "-", "_")
  ])

  games_groups = join("\n", [
    for name, alias in var.games :
    "game-${name} ansible_host=${alias}"
  ])
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"

  # one() yields null rather than failing when nothing matches,
  # which would write an empty ansible_host and surface as a Ansible error instead of tofu error.
  lifecycle {
    precondition {
      condition = alltrue([
        for name, vm in local.vm_addresses : vm.lan != null && vm.internal != null
      ])
      error_message = "A VM reported no address in ${local.lan_prefix}0/24 or ${local.internal_prefix}0/24 — check the subnets in outputs.tf against the guest agent's report."
    }
  }

  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    groups                       = local.inventory_groups
    children                     = local.inventory_children
    vps_groups                   = local.vps_groups
    vps_children                 = local.vps_children
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_private_key_file
  })
}

# Its own file so that -i names the blast radius: a run against the homelab cannot reach
# a machine that is not ours. Written even when var.games is empty, since an empty group
# parses and a missing file does not.
resource "local_file" "ansible_inventory_external" {
  filename        = "${path.module}/../ansible/inventory.external.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.external.ini.tftpl", {
    games_groups = local.games_groups
  })
}
