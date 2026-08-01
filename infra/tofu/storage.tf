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

# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/storage_directory

# Existing "local" dir storage, not something we created. Import, don't
# apply fresh:
#   tofu import proxmox_storage_directory.local local
# Original content (from /etc/pve/storage.cfg): iso,vztmpl,backup,import.
# `snippets` added deliberately here — needed for cloud-init.tf's
# user_data snippet, and normally requires a manual UI toggle
# (Datacenter → Storage → local → Edit → Content) otherwise.
resource "proxmox_storage_directory" "local" {
  id      = "local"
  path    = "/var/lib/vz"
  content = ["iso", "vztmpl", "backup", "import", "snippets"]
}
