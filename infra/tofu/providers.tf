terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}

variable "proxmox_endpoint" {
  description = "Proxmox API endpoint, e.g. https://10.0.0.2:8006/"
  type        = string
  default     = "https://10.0.0.2:8006/"
}

variable "proxmox_username" {
  description = "Proxmox user in user@realm form, used by the password and ssh provider aliases, e.g. root@pam"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Password for proxmox_username, used by the password and ssh provider aliases"
  type        = string
  sensitive   = true
}

variable "proxmox_otp" {
  description = "TOTP one-time password for username/password auth. Only used by the password alias — the provider has deprecated this argument in favour of exchanging a TOTP for an auth ticket out-of-band (see provider docs), but it still works. Not applicable to api_token auth, which bypasses 2FA entirely."
  type        = string
  sensitive   = true
  
  #default     = null   #this should never be defaulted to something as that would silently drop it instead of requesting it.
}

variable "proxmox_api_token" {
  description = "API token in user@realm!tokenid=secret form, used by the api_token alias"
  type        = string
  sensitive   = true
}

# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs
#
# Three aliases of the same "proxmox" provider, one per auth method, rather
# than three separate providers — a local name must match the key declared
# in required_providers above, so provider "proxmox_password" etc. would
# fail on init (Terraform would look for providers literally named that).
# Pick one to actually use in resources via `provider = proxmox.<alias>`;
# the others are kept here for reference/comparison.

provider "proxmox" {
  alias    = "password"
  endpoint = var.proxmox_endpoint

  username = var.proxmox_username
  password = var.proxmox_password
  otp      = var.proxmox_otp

  # because self-signed TLS certificate is in use
  insecure = true
}

provider "proxmox" {
  alias    = "ssh"
  endpoint = var.proxmox_endpoint

  username = var.proxmox_username
  password = var.proxmox_password

  # because self-signed TLS certificate is in use
  insecure = true

  # Only needed for the handful of operations the API can't do directly:
  # uploading snippets/files, importing disks via source_file.path, and
  # container idmap config. Most resources never touch this. SSH auth is
  # independent of the API auth above — it defaults to the same username
  # but can be pointed at a different one if needed.
  ssh {
    agent = true
  }
}

provider "proxmox" {
  alias     = "api"
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token

  # because self-signed TLS certificate is in use
  insecure = true
}
