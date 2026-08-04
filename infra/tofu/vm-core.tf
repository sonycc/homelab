# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/virtual_environment_vm
#
# Current-phase sizing (16GB host RAM)
# see the plan's Target architecture for the resize-and-add-vm-games step once the second 16GB stick lands.
# net0 = vmbr0 (LAN, DHCP, management/SSH);
# net1 = vmbr1 (internal, static, no gateway — that bridge has no uplink to route through).

resource "proxmox_virtual_environment_vm" "vm_core" {
  name      = "vm-core"
  node_name = "proxmox"
  vm_id     = 120

  stop_on_destroy = true

  cpu {
    cores = 4
  }

  memory {
    dedicated = 10240
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.ubuntu_cloudimg.id
    interface    = "scsi0"
    size         = 250
  }

  network_device {
    bridge   = "vmbr0"
    firewall = true
  }

  network_device {
    bridge   = "vmbr1"
    firewall = true
  }

  initialization {
    datastore_id        = "local-lvm"
    vendor_data_file_id = proxmox_virtual_environment_file.qemu_agent_init.id

    ip_config {
      ipv4 {
        address = "10.0.1.20/23"
        gateway = "10.0.0.10"
      }
    }

    ip_config {
      ipv4 {
        address = "10.10.10.20/24"
      }
    }

    user_account {
      username = "sondre"
      keys     = [trimspace(file("~/.ssh/homelab_infra.pub"))]
    }
  }

  agent {
    enabled = true
  }

  operating_system {
    type = "l26"
  }
}
