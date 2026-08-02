# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/virtual_environment_vm#ipv4_addresses
#
# vmbr1 addresses are static; vmbr0 is a DHCP lease reported by the guest agent and
# so only exists once the VM has booted.

locals {
  lan_prefix      = "10.0.0."
  internal_prefix = "10.10.10."

  vms = {
    "vm-core" = {
      vm_id = proxmox_virtual_environment_vm.vm_core.vm_id
      ipv4  = flatten(proxmox_virtual_environment_vm.vm_core.ipv4_addresses)
    }
    "vm-ci" = {
      vm_id = proxmox_virtual_environment_vm.vm_ci.vm_id
      ipv4  = flatten(proxmox_virtual_environment_vm.vm_ci.ipv4_addresses)
    }
  }

  # Matched positively against the two known subnets.
  vm_addresses = {
    for name, vm in local.vms : name => {
      lan = one([
        for ip in vm.ipv4 : ip
        if startswith(ip, local.lan_prefix)
      ])

      internal = one([
        for ip in vm.ipv4 : ip
        if startswith(ip, local.internal_prefix)
      ])

      vm_id = vm.vm_id
    }
  }
}

# lan is Ansible's connection target; vmbr1 has no uplink, so the control node cannot reach internal at all.
output "vm_addresses" {
  description = "Per-VM LAN address, vmbr1 address and VM ID."
  value       = local.vm_addresses
}

output "vm_core_lan_ip" {
  description = "vm-core DHCP address on vmbr0."
  value       = local.vm_addresses["vm-core"].lan
}

output "vm_ci_lan_ip" {
  description = "vm-ci DHCP address on vmbr0."
  value       = local.vm_addresses["vm-ci"].lan
}
