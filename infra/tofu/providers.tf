terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}


#registry.terraform.io/providers/bpg/proxmox/0.111.1/docs
provider "proxmox_password" {
  endpoint = "https://10.0.0.2:8006/"

  # TODO: use terraform variable or remove the line, and use PROXMOX_VE_USERNAME environment variable
  username = "root@pam"
  # TODO: use terraform variable or remove the line, and use PROXMOX_VE_PASSWORD environment variable
  password = "the-password-set-during-installation-of-proxmox-ve"

  # because self-signed TLS certificate is in use
  insecure = true
}

provider "proxmox_ssh" {
  endpoint = "https://10.0.0.2:8006/"
  username = "root@pam"
  password = "the-password-set-during-installation-of-proxmox-ve"
  insecure = true

  ssh {
    agent = true
    # username = "root"  # required when using api_token
  }
}


provider "proxmox_api" {
  endpoint  = "https://10.0.0.2:8006/"
  api_token = "terraform@pve!provider=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}