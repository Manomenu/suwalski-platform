output "tunnel_id" {
  description = "Tunnel ID — visible in the Zero Trust dashboard and in the DNS records."
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

output "tunnel_token" {
  description = "cloudflared token. scripts/setup.sh reads it and puts it into the cloudflared-token Secret in the cluster."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
  sensitive   = true
}

output "urls" {
  description = "Addresses of the exposed applications."
  value       = [for name, _ in var.apps : "https://${name}.${var.zone_name}"]
}
