# Fakty o koncie Cloudflare i lista wystawionych aplikacji. Bez sekretów i bez maili,
# więc w gicie — tak jak proxmox.auto.tfvars.
#
# Maile osób siedzą w secrets.auto.tfvars (poza gitem). Tu jest tylko NAZWA grupy, którą
# dana aplikacja wpuszcza.

account_id = "55af3255ed85296ce7f73835ca30755e"
zone_name  = "gugnowski.com"
team_name  = "gugnowski" # <team>.cloudflareaccess.com

apps = {
  # automat-operat-dev.gugnowski.com — wersja dev (namespace automat-operat-dev). Wpuszcza
  # własną grupę „automat-operat-dev” (Ty i osoby testujące), nie grupę produkcji.
  # Produkcja dojdzie jako `automat-operat = { access = "automat-operat" }`.
  automat-operat-dev = { access = "automat-operat-dev" }
}
