# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/storage_lvmthin

# Proxmox's default LVM-thin pool, not something we created. Import, don't
# apply fresh:
#   tofu import proxmox_storage_lvmthin.local_lvm local-lvm
resource "proxmox_storage_lvmthin" "local_lvm" {
  id           = "local-lvm"
  volume_group = "pve"
  thin_pool    = "data"
  content      = ["images", "rootdir"]
  # shared is computed-only, can't be set
}
