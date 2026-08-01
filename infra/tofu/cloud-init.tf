# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/virtual_environment_file
#
# The stock Ubuntu cloud image doesn't ship qemu-guest-agent running
# instead every VM installs and enables the agent itself on first boot
#
# Requires "snippets" content type on the storage — see storage.tf's
# proxmox_storage_directory.local, added there for exactly this.

resource "proxmox_virtual_environment_file" "qemu_agent_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "proxmox"

  source_raw {
    file_name = "qemu-agent.cloud-config.yaml"
    data      = <<-EOF
      #cloud-config
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable --now qemu-guest-agent
      EOF
  }
}
