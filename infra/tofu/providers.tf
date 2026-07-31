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
  description = "Proxmox user in user@realm form, used by the commented-out password/ssh provider examples below, e.g. root@pam"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Password for proxmox_username, used by the commented-out password/ssh provider examples below"
  type        = string
  sensitive   = true
}

# Commented out along with the password provider alias below, its only
# consumer. A declared variable with no default is required on EVERY run
# regardless of whether anything actually references it — commenting out
# just the provider block that used to use it is not enough on its own.
# Uncomment together with the password alias if that auth method is needed.
/*
variable "proxmox_otp" {
  description = "TOTP one-time password for username/password auth. Only used by the password alias — the provider has deprecated this argument in favour of exchanging a TOTP for an auth ticket out-of-band (see provider docs), but it still works. Not applicable to api_token auth, which bypasses 2FA entirely."
  type        = string
  sensitive   = true

  #default     = null   #this should never be defaulted to something as that would silently drop it instead of requesting it.
}
*/

variable "proxmox_token_id" {
  description = "Token ID in user@realm!tokenid form, exactly as shown by the Proxmox UI's API Tokens page"
  type        = string
}

variable "proxmox_token_secret" {
  description = "The token secret shown once at creation in the Proxmox UI's API Tokens page"
  type        = string
  sensitive   = true
}

locals {
  # The provider only accepts the token as one combined string
  # (user@realm!tokenid=secret); Proxmox's UI shows the two halves
  # separately, so tfvars mirrors that and this joins them back together.
  proxmox_api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
}

# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs
#
# Single unaliased provider — only one auth method is configured at a time,
# so no resource needs `provider = proxmox.<alias>`; the default (this
# block) applies automatically. If a second auth method is ever needed
# side by side, that requires `alias` on both blocks and explicit
# `provider = proxmox.<alias>` on every resource — deliberately not doing
# that now, for one real config.

# Alternative auth methods, kept commented as reference only — NOT
# switchable via alias the way an earlier version of this file did. To
# actually use one, comment out the active block below instead of adding
# this alongside it; two unaliased "proxmox" provider blocks at once is an
# error.

/*
provider "proxmox" {
  endpoint = var.proxmox_endpoint

  username = var.proxmox_username
  password = var.proxmox_password
  otp      = var.proxmox_otp

  # because self-signed TLS certificate is in use
  insecure = true
}

provider "proxmox" {
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
*/

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = local.proxmox_api_token

  # because self-signed TLS certificate is in use
  insecure = true
}
