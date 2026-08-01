# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/network_linux_bridge

# Created by hand before this existed. Import, don't apply fresh:
#   tofu import proxmox_network_linux_bridge.vmbr1 proxmox:vmbr1
resource "proxmox_network_linux_bridge" "vmbr1" {
  node_name = "proxmox"
  name      = "vmbr1"
  address   = "10.10.10.1/24"
}
