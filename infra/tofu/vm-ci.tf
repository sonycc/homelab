# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/virtual_environment_vm
#
# Current-phase sizing (16GB host RAM).
# dind + gitlab-runner — idle except during a pipeline run.
# net0 = vmbr0 (LAN, DHCP);
# net1 = vmbr1 (internal, static, no gateway).

resource "proxmox_virtual_environment_vm" "vm_ci" {
  name      = "vm-ci"
  node_name = "proxmox"
  vm_id     = 130

  stop_on_destroy = true

  cpu {
    cores = 2
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_download_file.ubuntu_cloudimg.id
    interface    = "scsi0"
    size         = 150
  }

  network_device {
    bridge = "vmbr0"
  }

  network_device {
    bridge = "vmbr1"
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.qemu_agent_init.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    ip_config {
      ipv4 {
        address = "10.10.10.30/24"
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
