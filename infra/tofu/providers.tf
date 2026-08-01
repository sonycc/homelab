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

# Only used by the commented-out password example below.
/*
variable "proxmox_otp" {
  description = "TOTP for username/password auth. Not used by api_token auth."
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
  # provider wants one combined string; UI shows it as two
  proxmox_api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
}

# registry.terraform.io/providers/bpg/proxmox/0.111.1/docs

# Alternative auth methods, reference only — uncomment one to switch.
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

  ssh {
    username    = "root"
    private_key = file("~/.ssh/homelab_infra")
  }
}
