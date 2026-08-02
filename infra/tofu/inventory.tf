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

locals {
  # Group names use underscores; Ansible warns on hyphens. Host names keep theirs.
  inventory_groups = join("\n\n", [
    for name, vm in local.vm_addresses :
    "[${replace(name, "-", "_")}]\n${name} ansible_host=${vm.lan} internal_ip=${vm.internal} vm_id=${vm.vm_id}"
  ])

  inventory_children = join("\n", [
    for name, vm in local.vm_addresses : replace(name, "-", "_")
  ])
}

resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    groups                       = local.inventory_groups
    children                     = local.inventory_children
    ansible_user                 = var.ansible_user
    ansible_ssh_private_key_file = var.ansible_ssh_private_key_file
  })
}
