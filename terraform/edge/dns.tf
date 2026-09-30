# Rekordy DNS: automat-operat-dev.gugnowski.com → tunel.
#
# Rekord to CNAME na <id-tunelu>.cfargotunnel.com, a nie A na jakiś adres IP — tunel nie
# ma publicznego IP, istnieje tylko wewnątrz sieci Cloudflare. Stąd `proxied = true`:
# bez proxy Cloudflare przeglądarka dostałaby nazwę, której nie da się rozwiązać.

data "cloudflare_zone" "main" {
  filter = {
    name = var.zone_name
  }
}

# Jeden rekord na aplikację, z tej samej mapy var.apps co aplikacje Access i trasy tunelu.
# To celowe: nie da się dopisać rekordu, nie dopisując zarazem reguły, kto może wejść.
resource "cloudflare_dns_record" "app" {
  for_each = var.apps

  zone_id = data.cloudflare_zone.main.zone_id
  name    = "${each.key}.${var.zone_name}"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # „automatic” — przy proxied TTL i tak ustala Cloudflare

  comment = "terraform/edge (suwalski-platform) — nie edytuj w panelu"
}
