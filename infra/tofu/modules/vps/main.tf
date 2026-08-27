# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/virtual_environment_container
#
# LXC rather than a VM: these run sshd and nothing else. Unprivileged, because the
# accounts on them belong to people who are not us.
#
# eth0 = vmbr0 (LAN, static)   — Ansible, and apt; vmbr1 has no uplink.
# eth1 = vmbr1 (internal)      — how cloudflared on vm-core reaches sshd here.

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

locals {
  lan_ip      = "10.0.1.${var.octet}"
  internal_ip = "10.10.10.${var.octet}"
}

resource "proxmox_virtual_environment_container" "this" {
  node_name = "proxmox"
  vm_id     = var.vm_id

  # The whole point. Root inside maps to an unprivileged uid on the host.
  unprivileged = true

  # No features block on purpose: nesting, keyctl and fuse are each a hole in the
  # boundary this exists to provide, and sshd and rsync need none of them.

  start_on_boot = true

  cpu {
    cores = var.cores
    units = var.cpu_units
  }

  # `dedicated` is the provider's field name; for a container it is a ceiling, not
  # an allocation. Swap so a breach degrades before it kills.
  memory {
    dedicated = var.memory
    swap      = var.memory
  }

  # User data goes on the volume below, so this only has to hold the OS. LVM-thin
  # reserves nothing until written, so the headroom is free until used.
  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  # A separate volume rather than a directory on the rootfs, for three reasons:
  #   - it IS the quota. Filling it cannot touch gitlab_data, postgres or the
  #     backup sets, which all share this pool.
  #   - `pct snapshot` and any future move to another disk operate on it alone.
  #   - the OS cannot grow into the data allowance, or the reverse.
  mount_point {
    volume = "local-lvm"
    size   = var.data_size
    path   = var.data_path
  }

  network_interface {
    name     = "eth0"
    bridge   = "vmbr0"
    firewall = true
  }

  network_interface {
    name     = "eth1"
    bridge   = "vmbr1"
    firewall = true
  }

  initialization {
    hostname = var.name

    ip_config {
      ipv4 {
        address = "${local.lan_ip}/23"
        gateway = "10.0.0.10"
      }
    }

    ip_config {
      ipv4 {
        address = "${local.internal_ip}/24"
      }
    }

    # An LXC has no cloud-init, so root is the only account Terraform can provision
    # and Ansible's only way in. That is why vps.yml leaves PermitRootLogin at
    # prohibit-password where common.yml sets no.
    user_account {
      keys = [var.ssh_public_key]
    }
  }

  # Debian, unlike the VMs, which run Ubuntu.
  # Estate consistency loses to working networking here. (see the template resource in ../../vps.tf for why.)
  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }
}

# Rules before options, deliberately: a container's firewall enable defaults to 0,
# so these sit inert until the options resource below switches enforcement on.
# Enforcement therefore never exists without its allow list. Same as ../../firewall.tf.
resource "proxmox_virtual_environment_firewall_rules" "this" {
  depends_on = [proxmox_virtual_environment_container.this]

  node_name    = "proxmox"
  container_id = proxmox_virtual_environment_container.this.vm_id

  # 22   net0 - Ansible's only way in
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH from the LAN"
    proto   = "tcp"
    dport   = "22"
    iface   = "net0"
  }

  # 22   net1 - cloudflared, which is how the external user arrives. Its traffic
  # leaves vm-core NAT'd behind that VM's vmbr1 address, so the source is the VM and
  # not the docker subnet. net1 only, so a LAN spoof of .20 misses.
  rule {
    type    = "in"
    action  = "ACCEPT"
    comment = "SSH via the Cloudflare tunnel"
    source  = "10.10.10.20"
    proto   = "tcp"
    dport   = "22"
    iface   = "net1"
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

# Outbound stays ACCEPT so apt works, and that is fine: reaching postgres or GitLab
# is denied by *their* input policy, not by this one. vm-core accepts 10.10.10.30
# only, so these containers are already shut out of everything on it.
resource "proxmox_virtual_environment_firewall_options" "this" {
  depends_on = [proxmox_virtual_environment_firewall_rules.this]

  node_name    = "proxmox"
  container_id = proxmox_virtual_environment_container.this.vm_id

  enabled       = true
  input_policy  = "DROP"
  output_policy = "ACCEPT"
  ndp           = true
}
