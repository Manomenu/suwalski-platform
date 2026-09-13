terraform {
  required_version = ">= 1.9"

  required_providers {
    # bpg/proxmox jest utrzymywanym providerem do Proxmoksa. Starszy telmate/proxmox
    # bywa polecany w tutorialach, ale od lat nie nadąża za API.
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.60"
    }
  }
}
