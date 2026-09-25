# 10. Decyzje w pigułce

[← diagnostyka](edge-9-diagnostyka.md) · [spis treści](edge-0.md)

Wszystkie „czemu tak, a nie inaczej” z przewodnika w jednym miejscu. Gdy za pół roku
będziesz chciał coś zmienić — sprawdź tu, czy powód nadal obowiązuje.

## Architektura

| Decyzja | Odrzucona alternatywa | Powód | Rozdział |
| --- | --- | --- | --- |
| Cloudflare Tunnel | przekierowanie portu w routerze | działa za CGNAT, domowe IP ukryte, żaden port otwarty | 1 |
| Cloudflare Tunnel | VPS + WireGuard | 0 $ zamiast ~5 $, brak serwera do utrzymania | 1 |
| Cloudflare Access | oauth2-proxy w klastrze | obcy odpada w Cloudflare, zanim dotknie sieci domowej | 1, 3 |
| Homelab + Cloudflare | GKE + IAP | 0 $ zamiast ~90 $/mies. | 1 |
| One-time PIN | logowanie Google | nie wymaga OAuth clienta ani projektu w Google Cloud | 2 |

## Warstwa i pliki

| Decyzja | Alternatywa | Powód | Rozdział |
| --- | --- | --- | --- |
| `edge/` jako osobna konfiguracja | część `cluster/` lub `platform/` | inny świat (API Cloudflare), inne sekrety, psuje się osobno | 5 |
| brak providera `kubernetes` w `edge/` | Terraform wkłada Secret do klastra | `edge` nie zależy od klastra; mostem jest `setup.sh` | 4 |
| jedna mapa `apps` dla Access, DNS i tras | osobne listy | nie da się mieć rekordu bez aplikacji Access | 5 |
| trasa per aplikacja | jedna `*.gugnowski.com` | każda wymaga tokena *swojej* aplikacji | 3, 5 |
| `origin_request.access.required` | tylko Access w Cloudflare | druga linia obrony przed rekordem bez Access | 3 |
| `config_src = "cloudflare"` | `config.yml` przy cloudflared | trasy w jednym miejscu (Terraform), cloudflared zna tylko token | 5, 6 |
| reguły per grupa, wielokrotnego użytku | reguła per aplikacja | dopisanie osoby w jednym miejscu | 5 |
| maile poza gitem (`access/*.json`) | w `edge.auto.tfvars` | repo jest publiczne | 4 |
| maile nie `sensitive` | ukrycie w `plan` | chcesz widzieć w `plan`, kogo dopisujesz | 4 |
| grupa = plik w `access/` | jedna zmienna w `secrets.auto.tfvars` | każdy projekt dokłada swoją grupę, nikt nie nadpisuje cudzej | 4, 5 |
| sekrety per projekt i środowisko | jeden globalny `setup.sh` | platforma nie wie nic o projektach; nowy projekt = nowy skrypt | 4 |
| sesja 30 dni | domyślne 24 h | ciocia wpisuje kod raz w miesiącu, nie codziennie | 5 |

## Klaster

| Decyzja | Alternatywa | Powód | Rozdział |
| --- | --- | --- | --- |
| cloudflared przez Argo | `helm_release` w `terraform/platform/` | samonaprawa, aktualizacja commitem, niezależne warstwy | 6 |
| własny manifest | oficjalny chart Helma | ~60 linijek, pełna kontrola, token tylko z Secretu | 6 |
| manifest w `argocd/manifests/` | w `argocd/apps/` | root stosuje `apps/` w namespace `argocd` | 6 |
| jeden cloudflared na klaster | per projekt | Traefik i tak rozdziela po hostach; jeden token mniej | 6 |
| 2 repliki | 1 | aktualizacja bez przerwy w dostępie | 6 |
| token przez `env` | argument `--token` | argumentów procesu nie widać w `ps` ani `describe` | 6 |
| Traefik jako cel tunelu | tunel prosto do Service'u aplikacji | routing po hostach zostaje w Ingressach projektów, jak w LAN-ie | 2, 3 |

## Znane ograniczenia (świadomie zaakceptowane)

- **Cloudflare widzi ruch** — TLS kończy się u nich.
- **Dostępność = dom** — prąd, internet, Proxmox.
- **Ominięcie z LAN-u** — Traefik na `192.168.0.119` przyjmie żądanie z właściwym `Host`
  bez logowania. Rozwiązanie, gdyby było potrzebne: aplikacja weryfikuje JWT z
  `Cf-Access-Jwt-Assertion`.
- **Sekrety poza gitem, ręcznie** — do czasu SOPS (`TODO.md`).
