# Podział wartości — ten sam co w cluster/:
#
#   default tutaj        — decyzje projektowe: dokąd tunel oddaje ruch, jak długo trwa sesja
#   edge.auto.tfvars     — fakty o koncie Cloudflare i lista aplikacji (w gicie)
#   secrets.auto.tfvars  — token API (poza gitem, generuje go scripts/setup.sh)
#   access/*.json        — MAILE osób w grupach (poza gitem, patrz access.tf)
#
# Maile nie są tajne w sensie hasła, ale są prywatne: repo jest publiczne, a adres cioci
# nie ma prawa w nim wylądować. Dlatego w gicie jest tylko NAZWA grupy, którą aplikacja
# wpuszcza, a kto do niej należy — w access/, poza gitem.

# ── Konto Cloudflare: zależy od środowiska ────────────────────────────────────

variable "account_id" {
  description = "ID konta Cloudflare (panel, prawa kolumna). Nie jest sekretem. → edge.auto.tfvars"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{32}$", var.account_id))
    error_message = "account_id to 32 znaki szesnastkowe — skopiuj go z panelu Cloudflare."
  }
}

variable "zone_name" {
  description = "Domena w Cloudflare, pod którą wiszą aplikacje. → edge.auto.tfvars"
  type        = string
}

variable "team_name" {
  description = "Nazwa zespołu Zero Trust, wybrana przy zakładaniu (z adresu <team>.cloudflareaccess.com). cloudflared sprawdza nią tokeny Access. → edge.auto.tfvars"
  type        = string
}

# ── Co wystawiamy ─────────────────────────────────────────────────────────────

variable "apps" {
  description = "Aplikacje wystawione na świat: klucz = subdomena, access = nazwa grupy (plik access/<grupa>.json). → edge.auto.tfvars"
  type = map(object({
    access = string
  }))

  validation {
    condition     = alltrue([for k in keys(var.apps) : can(regex("^[a-z0-9-]+$", k))])
    error_message = "Klucz aplikacji to sama subdomena, np. \"witkowska-dev\" — bez kropek i domeny."
  }
}

# ── Sekrety ───────────────────────────────────────────────────────────────────

variable "cloudflare_api_token" {
  description = "Token API Cloudflare z uprawnieniami tej warstwy. → secrets.auto.tfvars"
  type        = string
  sensitive   = true
}

# ── Decyzje projektowe: te same wszędzie ──────────────────────────────────────

variable "tunnel_name" {
  description = "Nazwa tunelu w panelu Zero Trust. Jeden tunel na klaster."
  type        = string
  default     = "homelab"
}

variable "origin_service" {
  description = "Dokąd cloudflared oddaje ruch. Traefik z k3s — on rozdziela go po hostach według Ingressów, tak jak w sieci domowej."
  type        = string
  default     = "http://traefik.kube-system.svc.cluster.local:80"
}

variable "session_duration" {
  description = "Jak długo po wpisaniu kodu nie trzeba logować się ponownie. 720h = 30 dni: ciocia wpisuje kod mniej więcej raz w miesiącu."
  type        = string
  default     = "720h"
}
