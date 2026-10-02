terraform {
  required_version = ">= 1.9"

  required_providers {
    # bpg/proxmox is the maintained Proxmox provider. The older telmate/proxmox
    # is often recommended in tutorials, but it has not kept up with the API for years.
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.60"
    }
  }
}
