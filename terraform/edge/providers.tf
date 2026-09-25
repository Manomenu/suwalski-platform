# Ta konfiguracja jest osobna od cluster/ i platform/, bo rozmawia wyłącznie z API
# Cloudflare: nie potrzebuje Proxmoksa ani kubeconfiga i da się ją zastosować, zanim
# klaster w ogóle istnieje. Przebudowa klastra jej nie dotyka — tunel, DNS i logowanie
# zostają, a cloudflared po prostu podłącza się na nowo.

provider "cloudflare" {
  # Token z uprawnieniami tylko do tego, czego ta warstwa dotyka — lista w
  # docs/edge/guide/edge-4-sekrety.md. Nigdy globalny klucz API konta.
  api_token = var.cloudflare_api_token
}
