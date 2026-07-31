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
  description = "Proxmox user in user@realm form, used by the password and ssh provider blocks, e.g. root@pam"
  type        = string
  default     = "root@pam"
}

variable "proxmox_password" {
  description = "Password for proxmox_username, used by the password and ssh provider blocks"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token" {
  description = "API token in user@realm!tokenid=secret form, used by the api_token provider block"
  type        = string
  sensitive   = true
}

#registry.terraform.io/providers/bpg/proxmox/0.111.1/docs
provider "proxmox_password" {
  endpoint = var.proxmox_endpoint

  username = var.proxmox_username
  password = var.proxmox_password

  # because self-signed TLS certificate is in use
  insecure = true
}

provider "proxmox_ssh" {
  endpoint = var.proxmox_endpoint

  username = var.proxmox_username
  password = var.proxmox_password

  # because self-signed TLS certificate is in use
  insecure = true

  ssh {
    agent = true
    # username = "root"  # required when using api_token
  }
}


provider "proxmox_api" {
  endpoint = var.proxmox_endpoint
  api_token = var.proxmox_api_token
}
