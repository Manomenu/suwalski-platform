provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token

  # Proxmox serves its own certificate that nobody signed. On the LAN that is
  # acceptable; on the internet it never would be.
  insecure = var.proxmox_insecure

  # Some operations (uploading the cloud-init file to snippets, importing the disk) the
  # provider performs over SSH, not the API. It takes the key from the agent — the same
  # one `ssh pve` uses.
  ssh {
    agent    = true
    username = "root"
  }
}
