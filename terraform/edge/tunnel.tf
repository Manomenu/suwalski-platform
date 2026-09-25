# Tunel: stałe, wychodzące połączenie z klastra do Cloudflare. Ruch z internetu wchodzi
# nim „pod prąd”, więc w routerze nie otwieramy żadnego portu, a domowe IP może się
# zmieniać, jak chce.
#
# Tutaj tunel tylko POWSTAJE po stronie Cloudflare. Łączy się z nim cloudflared, który
# biegnie w klastrze (kubernetes/cloudflared/, instaluje go Argo) i przedstawia się
# tokenem z wyjścia `tunnel_token`.

resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  account_id = var.account_id
  name       = var.tunnel_name

  # Konfiguracja tras trzymana w Cloudflare, nie w pliku przy cloudflared. Dzięki temu
  # opisuje ją ten Terraform, a cloudflared potrzebuje jedynie tokena — bez ConfigMapy
  # z trasami, którą trzeba by trzymać w zgodzie z DNS-em.
  config_src = "cloudflare"
}

# Trasy: który host idzie dokąd. Czytane od góry, wygrywa pierwsza pasująca reguła.
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id

  config = {
    ingress = concat(
      # Po jednej regule na aplikację, zamiast jednej wieloznacznej *.gugnowski.com —
      # żeby każda mogła wymagać tokena WŁASNEJ aplikacji Access (niżej).
      [for name, app in var.apps : {
        hostname = "${name}.${var.zone_name}"
        service  = var.origin_service

        origin_request = {
          # Druga linia obrony. Access przepuszcza tylko zalogowanych, ale gdyby kiedyś
          # powstał rekord DNS bez aplikacji Access, ruch doszedłby do klastra bez
          # logowania. Z tym ustawieniem cloudflared sam sprawdza podpisany token Access
          # i odrzuca żądanie, które go nie ma.
          access = {
            required  = true
            team_name = var.team_name
            aud_tag   = [cloudflare_zero_trust_access_application.app[name].aud]
          }
        }
      }],
      # Reguła końcowa, wymagana przez Cloudflare: wszystko, co nie pasuje wyżej, dostaje 404
      # od cloudflared i nie dotyka klastra.
      [{ service = "http_status:404" }],
    )
  }
}

# Token, którym cloudflared przedstawia się temu tunelowi. Kto go ma, może podpiąć się pod
# tunel i przejąć ruch — dlatego wyjście jest `sensitive`, a do klastra trafia jako Secret
# przez scripts/setup.sh, nie przez gita.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.homelab.id
}
