provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token

  # Proxmox wystawia własny certyfikat, którego nic nie podpisało. W LAN-ie to
  # akceptowalne; w internecie nigdy by nie było.
  insecure = var.proxmox_insecure

  # Część operacji (wgranie pliku cloud-init do snippetów, import dysku) provider
  # wykonuje przez SSH, nie przez API. Klucz bierze z agenta — tego samego, którym
  # działa `ssh pve`.
  ssh {
    agent    = true
    username = "root"
  }
}
