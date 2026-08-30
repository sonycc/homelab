# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/download_file
# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/guides/cloud-image

resource "proxmox_download_file" "ubuntu_cloudimg" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "proxmox"

  url       = "https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-amd64.img"
  file_name = "ubuntu-26.04-server-cloudimg-amd64.qcow2"

  checksum           = "9dc7c5363c0146a08ba0c9aa834d82c2c6dfbb1c471ad9a2f0aba1189e21be05"
  checksum_algorithm = "sha256"

  # Ubuntu republishes this URL on every point release and we do not need to update when it does.
  overwrite = false
}
