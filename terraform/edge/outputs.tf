output "tunnel_id" {
  description = "ID tunelu — widać go w panelu Zero Trust i w rekordach DNS."
  value       = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}

output "tunnel_token" {
  description = "Token cloudflared. Czyta go scripts/setup.sh i wkłada do Secretu cloudflared-token w klastrze."
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.homelab.token
  sensitive   = true
}

output "urls" {
  description = "Adresy wystawionych aplikacji."
  value       = [for name, _ in var.apps : "https://${name}.${var.zone_name}"]
}
