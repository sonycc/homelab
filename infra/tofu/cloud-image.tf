# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/resources/download_file
# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs/guides/cloud-image

resource "proxmox_download_file" "ubuntu_cloudimg" {
  content_type = "import"
  datastore_id = "local"
  node_name    = "proxmox"

  url       = "https://cloud-images.ubuntu.com/releases/resolute/release/ubuntu-26.04-server-cloudimg-amd64.img"
  file_name = "ubuntu-26.04-server-cloudimg-amd64.qcow2"

  checksum           = "117816726abbdefc5ef3e38902e81a76f1c76c3610e709999d0885f9d5d9b477"
  checksum_algorithm = "sha256"
}
