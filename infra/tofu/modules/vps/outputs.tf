# Consumed by ../../outputs.tf to build the Ansible inventory.

output "name" {
  value = var.name
}

output "lan" {
  value = local.lan_ip
}

output "internal" {
  value = local.internal_ip
}

output "vm_id" {
  value = proxmox_virtual_environment_container.this.vm_id
}
