# This configuration is separate from cluster/ and platform/ because it talks only to the
# Cloudflare API: it needs neither Proxmox nor a kubeconfig and can be applied before the
# cluster even exists. Rebuilding the cluster does not touch it — the tunnel, DNS and login
# stay, and cloudflared simply reconnects.

provider "cloudflare" {
  # A token with permissions only for what this layer touches — the list is in
  # docs/edge/guide/edge-4-sekrety.md. Never the account's global API key.
  api_token = var.cloudflare_api_token
}
