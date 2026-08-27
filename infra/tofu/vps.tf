# Small VPSes handed to external users. Adding one is an entry in the map below;
# sizing, both addresses, the firewall and the inventory entry come from the module.

# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/download_file
#
# One template, shared by every instance.
#
# http, not https: download.proxmox.com has no certificate for its own name, only
# for its CDN aliases. The checksum provides integrity, so the transport does not
# have to — the same model pveam uses. That checksum came from a copy pveam had
# already verified against Proxmox's GPG-signed index, so this pin inherits it.
#
# It goes stale when Debian bumps the point release and the old file is withdrawn.
# That fails loudly at apply; to refresh:
#   pveam update && pveam available --section system | grep debian-13
#   pveam download local <new-filename>
#   sha256sum /var/lib/vz/template/cache/<new-filename>
#
# Debian rather than Ubuntu, which the VMs run. Ubuntu 26.04's container template
# ships no ifupdown and an empty /etc/netplan, so Proxmox writes network config that
# nothing inside reads: both interfaces come up DOWN with no address and the
# container is unreachable. Proxmox's generator and the Debian templates are the
# same lineage, so this does not arise there. `host_managed` is not a way out — it
# runs DHCP on the host's behalf, and the guest still needs a client to ask.
resource "proxmox_download_file" "debian_ct" {
  content_type = "vztmpl"
  datastore_id = "local"
  node_name    = "proxmox"

  url       = "http://download.proxmox.com/images/system/debian-13-standard_13.6-1_amd64.tar.zst"
  file_name = "debian-13-standard_13.6-1_amd64.tar.zst"

  checksum           = "1a5e43d088b430a1fca0531a2283ae2949ff0b40d383d0836d4a309e192b3244"
  checksum_algorithm = "sha256"

  # A pveam download already put this file in local:vztmpl, where Terraform does not
  # know about it. Without this the first apply fails on a file it would otherwise
  # have created itself.
  overwrite_unmanaged = true
}

# VMIDs are 2xx for VPSes, against 1xx for VMs. Addresses sit in 10.0.1.14x, clear
# of the VMs at .20 and .30, and the same octet is used on both bridges.
#
# Every entry carries all three keys even where the value matches the module default:
# for_each unifies types across the map, so entries with differing keys are a
# plan-time error rather than a fallback.
#
# data_path is not among them. Each container has its own mount namespace, so the
# module default is the same path in every one of them and never collides.
module "vps" {
  source = "./modules/vps"

  # The module enables enforcement for its own container; the cluster-level switch
  # it depends on lives in firewall.tf, outside the module.
  depends_on = [proxmox_virtual_environment_cluster_firewall.homelab]

  for_each = {
    nawth = {
      vm_id     = 240
      octet     = 140
      data_size = "20G"
    }
    bashout = {
      vm_id     = 241
      octet     = 141
      data_size = "20G"
    }
  }

  name      = "vps-${each.key}"
  vm_id     = each.value.vm_id
  octet     = each.value.octet
  data_size = each.value.data_size

  template_file_id = proxmox_download_file.debian_ct.id
  ssh_public_key   = trimspace(file("~/.ssh/homelab_infra.pub"))
}
