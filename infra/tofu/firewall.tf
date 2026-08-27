# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_cluster_firewall
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_firewall_options
# https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_firewall_rules
#
# Filtering happens at VM level.
#   net0 = LAN
#   net1 = vmbr1.
# Container-to-container inside a VM crosses using docker network.
# Container-to-container in different VMs crosses using net1.

# enabled true   - master switch, one of three; also VM options + firewall=true per NIC
# input ACCEPT   - leaves Proxmox itself reachable; a bad rule can only cost a VM
# output ACCEPT  - Proxmox reaches out freely
# forward ACCEPT - bridged traffic is judged by the VM rules, not here
resource "proxmox_virtual_environment_cluster_firewall" "homelab" {
  enabled = true

  input_policy   = "ACCEPT"
  output_policy  = "ACCEPT"
  forward_policy = "ACCEPT"
}

# Rules before options, deliberately: a VM's firewall enable defaults to 0, so
# these sit inert until the options resource below switches enforcement on.
# Enforcement therefore never exists without its allow list.
resource "proxmox_virtual_environment_firewall_rules" "vm_core" {
  depends_on = [proxmox_virtual_environment_vm.vm_core]

  node_name = proxmox_virtual_environment_vm.vm_core.node_name
  vm_id     = proxmox_virtual_environment_vm.vm_core.vm_id

  # 22   net0 - Ansible's only way in
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH from the LAN"
    proto   = "tcp"
    dport   = "22"
    iface   = "net0"
  }

  # 3001 net0 - Kuma must not depend on the proxy it watches
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Uptime Kuma, reached over the LAN by design"
    proto   = "tcp"
    dport   = "3001"
    iface   = "net0"
  }

  # ping net0 - tells "unreachable" apart from "port closed"
  # macro covers every ICMP type a ping needs, not just echo-request
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Ping, for diagnosing this file"
    macro   = "Ping"
    iface   = "net0"
  }

  # 443  net1 - only thing vm-ci may reach
  # net1 only, so a LAN spoof of .30 does not match
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "gitlab-runner to NPM over internal HTTPS"
    source  = "10.10.10.30"
    proto   = "tcp"
    dport   = "443"
    iface   = "net1"
  }
}

# enabled true   - third switch, and the one that starts enforcement
# input DROP     - created after the rules, so it never enforces an empty list
# output ACCEPT  - VM reaches out freely; stateful, so replies get back
# ndp true       - VM holds IPv6, neighbour discovery has to pass
# no dhcp        - VM is static; needed again if it ever leases
resource "proxmox_virtual_environment_firewall_options" "vm_core" {
  depends_on = [
    proxmox_virtual_environment_cluster_firewall.homelab,
    proxmox_virtual_environment_firewall_rules.vm_core,
  ]

  node_name = proxmox_virtual_environment_vm.vm_core.node_name
  vm_id     = proxmox_virtual_environment_vm.vm_core.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  ndp           = true
}

# no net1   - vm-ci reaches out across it, is never reached on it
resource "proxmox_virtual_environment_firewall_rules" "vm_ci" {
  depends_on = [proxmox_virtual_environment_vm.vm_ci]

  node_name = proxmox_virtual_environment_vm.vm_ci.node_name
  vm_id     = proxmox_virtual_environment_vm.vm_ci.vm_id

  # 22   net0 - Ansible's only way in
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH from the LAN"
    proto   = "tcp"
    dport   = "22"
    iface   = "net0"
  }

  # ping net0 - tells "unreachable" apart from "port closed"
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "Ping, for diagnosing this file"
    macro   = "Ping"
    iface   = "net0"
  }
}

# VPS containers carry their own rules inside modules/vps, so a second one cannot be
# added with a laxer set than the first.

# Same as vm_core. This is the VM that hands root to CI jobs (AUDIT H1).
resource "proxmox_virtual_environment_firewall_options" "vm_ci" {
  depends_on = [
    proxmox_virtual_environment_cluster_firewall.homelab,
    proxmox_virtual_environment_firewall_rules.vm_ci,
  ]

  node_name = proxmox_virtual_environment_vm.vm_ci.node_name
  vm_id     = proxmox_virtual_environment_vm.vm_ci.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  ndp           = true
}
