# DNS records: automat-operat-dev.gugnowski.com → tunnel.
#
# The record is a CNAME to <tunnel-id>.cfargotunnel.com, not an A to some IP address — the tunnel
# has no public IP, it exists only inside the Cloudflare network. Hence `proxied = true`:
# without the Cloudflare proxy the browser would get a name that cannot be resolved.

data "cloudflare_zone" "main" {
  filter = {
    name = var.zone_name
  }
}

# One record per application, from the same var.apps map as the Access applications and tunnel routes.
# This is deliberate: you cannot add a record without also adding a rule for who may get in.
resource "cloudflare_dns_record" "app" {
  for_each = var.apps

  zone_id = data.cloudflare_zone.main.zone_id
  name    = "${each.key}.${var.zone_name}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # "automatic" — with proxied, Cloudflare sets the TTL anyway

  comment = "terraform/edge (suwalski-platform) — nie edytuj w panelu"
}
