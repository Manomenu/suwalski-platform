terraform {
  required_version = ">= 1.9"

  required_providers {
    # Wersja 5 to przepisany od zera provider, generowany z API Cloudflare. Nazwy zasobów
    # i kształt pól różnią się od wersji 4, więc poradniki sprzed 2025 roku zwykle nie
    # pasują — patrz docs/edge/guide/.
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.25"
    }
  }
}
