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

output "access_team_domain" {
  description = "Cloudflare Access team domain: issuer of the login tokens and the address of their signing keys."
  value       = "${var.team_name}.cloudflareaccess.com"
}

output "access_aud" {
  description = "Audience tag of each Access application. An app's backend checks that a login token was issued for it, not for another app of the same team."
  value       = { for name, app in cloudflare_zero_trust_access_application.app : name => app.aud }
}
