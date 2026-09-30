# 5. Pliki Terraforma

[← wartości i sekrety](edge-4-sekrety.md) · [spis treści](edge-0.md) · [następny: cloudflared w klastrze →](edge-6-cloudflared.md)

Otwórz `terraform/edge/` obok tego rozdziału. Czytamy w kolejności, w jakiej pliki od
siebie zależą: najpierw „z czym rozmawiamy”, potem „jakie mamy dane”, potem zasoby.

```
terraform/edge/
  versions.tf                   1. jaki provider, w jakiej wersji
  providers.tf                  2. jak się logujemy do Cloudflare
  variables.tf                  3. jakie wartości przyjmujemy
  edge.auto.tfvars              4.   … fakty o koncie (w gicie)
  secrets.auto.tfvars.example   5.   … wzór sekretów (prawdziwy plik robi setup.sh)
  access/                       5b.  … grupy: plik = grupa, maile (poza gitem)
  access.tf                     6. kto może wejść
  tunnel.tf                     7. tunel, jego trasy, token
  dns.tf                        8. nazwy → tunel
  outputs.tf                    9. co wystawiamy na zewnątrz
```

Kolejność 6→7→8 jest celowa: tunel potrzebuje `aud` z aplikacji Access, a DNS potrzebuje
ID tunelu. Terraform sam liczy kolejność tworzenia z odwołań między zasobami — podział na
pliki jest tylko dla ludzi.

## Czemu osobna konfiguracja, a nie część `cluster/` albo `platform/`

Każdy katalog w `terraform/` to osobna **konfiguracja główna**: własny stan, własne
`tofu apply`. `edge/` jest osobno, bo:

- **rozmawia z innym światem** — wyłącznie z API Cloudflare; nie potrzebuje Proxmoksa
  (jak `cluster/`) ani kubeconfiga (jak `platform/`);
- **ma inne sekrety** — token Cloudflare widzi tylko ta warstwa;
- **zmienia się w innym rytmie** — gdy dochodzi aplikacja albo osoba, nie gdy zmienia się maszyna;
- **psuje się osobno** — przebudowa klastra (`destroy` + `apply` w `cluster/`) nie dotyka
  tunelu. ID tunelu zostaje, DNS zostaje, logowanie zostaje. Nowy cloudflared po prostu
  podłącza się z tym samym tokenem.

Ten sam powód — niezależność — tłumaczy, czemu w `edge/` **nie ma** providera `kubernetes`
(rozdział 4).

## 1. `versions.tf`

```hcl
cloudflare = {
  source  = "cloudflare/cloudflare"
  version = "~> 5.25"
}
```

`~> 5.25` znaczy „5.25 lub nowsza, ale nie 6.0”. Wersja 5 to provider napisany od nowa
i generowany z API Cloudflare — nazwy zasobów i kształt pól są inne niż w wersji 4.
**Większość poradników w internecie jest dla wersji 4** (`cloudflare_tunnel`,
`cloudflare_record`, bloki zamiast `= { }`). Jeśli coś kopiujesz, sprawdź wersję.

Dokładna wersja, która została pobrana, jest przypięta w `.terraform.lock.hcl` — ten plik
commitujemy, tak jak w pozostałych warstwach.

## 2. `providers.tf`

```hcl
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

Jedna linijka treści: token z uprawnieniami z rozdziału 4. Provider nie potrzebuje
`account_id` — ten podajemy przy każdym zasobie, bo tak działa API w wersji 5.

## 3. `variables.tf`

Zmienne są pogrupowane według tego, **skąd przychodzi wartość**, i każda ma w opisie
strzałkę `→ plik`, żeby było widać, gdzie ją ustawić.

**Konto** — `account_id`, `zone_name`, `team_name`. Bez `default`: to fakty o *tym*
koncie, więc skopiowanie repo gdzie indziej ma skończyć się błędem „brak wartości”, a nie
cichym działaniem na cudzych danych. `account_id` ma walidację (32 znaki szesnastkowe) —
łapie literówkę i niewypełniony szablon, zanim cokolwiek poleci do API.

**Co wystawiamy** — `apps`:

```hcl
variable "apps" {
  type = map(object({
    access = string
  }))
}
```

To **serce warstwy**. Klucz mapy to subdomena (`automat-operat-dev`), a `access` to nazwa grupy, która
może wejść. Z tej jednej mapy powstają: aplikacja Access, trasa tunelu i rekord DNS —
zobaczysz to w plikach 6–8. Walidacja pilnuje, żeby klucz był samą subdomeną, bez kropek.

`object({ access = string })` zamiast po prostu `map(string)` — bo za chwilę może dojść
np. `public = true` albo inna usługa docelowa, a obiekt da się rozszerzyć bez
przepisywania wszystkich odwołań.

**Sekrety** — tylko `cloudflare_api_token` (`sensitive = true`, nie pokaże się w `plan`).
Grup z mailami tu **nie ma** — nie są zmienną, tylko plikami w `access/` (punkt 5b
i `access.tf`). Powód w rozdziale 4, „Czemu grupy to osobne pliki”.

**Decyzje projektowe** — z `default`:

- `tunnel_name = "homelab"` — jeden tunel na klaster;
- `origin_service = "http://traefik.kube-system.svc.cluster.local:80"` — pełna nazwa
  DNS Service'u Traefika wewnątrz klastra. cloudflared biegnie w klastrze, więc ją
  rozwiązuje. HTTP, nie HTTPS: TLS kończy się w Cloudflare, a od cloudflared do Traefika
  ruch nie wychodzi poza węzeł;
- `session_duration = "720h"` — 30 dni sesji.

## 4. `edge.auto.tfvars`

```hcl
account_id = "UZUPELNIJ_…"
zone_name  = "gugnowski.com"
team_name  = "UZUPELNIJ"

apps = {
  automat-operat-dev = { access = "admin" }
}
```

Końcówka `.auto.tfvars` sprawia, że Terraform wczytuje plik sam — bez `-var-file`
(zasada z `AGENTS.md`). Dwie wartości trzeba uzupełnić przy pierwszym uruchomieniu
(rozdział 7). Walidacja `account_id` nie przepuści napisu `UZUPELNIJ…` — plan zatrzyma się
z czytelnym komunikatem.

## 5. `secrets.auto.tfvars.example`

Wzór, jak wygląda prawdziwy `secrets.auto.tfvars`: jedna linijka z tokenem. Prawdziwy
generuje `scripts/setup.sh` — wzór jest dla czytelnika.

## 5b. `access/` — grupy

Katalog z plikami `<grupa>.json`, każdy z listą maili: `["ty@gmail.com", "ciocia@gmail.com"]`.
Pliki `*.json` są w `.gitignore`; w gicie jest tylko `access/README.md` z tabelą, który
skrypt pisze którą grupę. Czemu tak — rozdział 4.

## 6. `access.tf` — kto może wejść

Trzy zasoby — trzy klocki z rozdziału 2, od najogólniejszego.

**Metoda logowania:**

```hcl
resource "cloudflare_zero_trust_access_identity_provider" "otp" {
  type   = "onetimepin"
  config = {}
}
```

`config = {}` — One-time PIN nie ma ustawień (Google miałby tu `client_id` i `client_secret`).
Jeden zasób na konto.

**Grupy — z plików:**

```hcl
locals {
  access_dir = "${path.module}/access"
  access_groups = {
    for f in fileset(local.access_dir, "*.json") :
    trimsuffix(f, ".json") => jsondecode(file("${local.access_dir}/${f}"))
  }
}
```

`fileset` zwraca nazwy plików pasujących do wzorca (`admin.json`, `automat-operat.json`),
`trimsuffix` robi z nich nazwy grup, a `jsondecode(file(…))` czyta listę maili. Wynik to
zwykła mapa `{ admin = [...], automat-operat = [...] }` — dalej używana tak, jakby była
zmienną. `local` zamiast `var`, bo wartość nie przychodzi z zewnątrz przez `-var` czy
`.tfvars`, tylko jest *wyliczana* z plików.

**Reguły — po jednej na grupę:**

```hcl
resource "cloudflare_zero_trust_access_policy" "group" {
  for_each = local.access_groups
  decision = "allow"
  include  = [for email in each.value : { email = { email = email } }]
}
```

`for_each` po mapie grup tworzy reguły `group["automat-operat"]` i `group["admin"]`.
`include` działa jak **LUB**: wystarczy pasować do jednego wpisu. Wyrażenie `for`
zamienia `["a@x", "b@y"]` na `[{email = {email = "a@x"}}, {email = {email = "b@y"}}]` —
taki kształt narzuca API (podwójne `email` to nie literówka: pierwszy to *rodzaj* warunku,
drugi to jego pole).

Reguły są na poziomie konta i wielokrotnego użytku — dwie aplikacje tej samej grupy wskazują
tę samą regułę, a dopisanie osoby zmienia się w jednym miejscu.

`precondition` w regule odrzuca pusty plik grupy (`[]`): reguła bez nikogo to cicha
blokada aplikacji, lepiej zatrzymać się na `plan`.

**Aplikacje — po jednej na wpis w `apps`:**

```hcl
resource "cloudflare_zero_trust_access_application" "app" {
  for_each = var.apps
  type     = "self_hosted"
  domain   = "${each.key}.${var.zone_name}"

  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.otp.id]
  auto_redirect_to_identity = true
  app_launcher_visible      = false

  policies = [{
    id         = cloudflare_zero_trust_access_policy.group[each.value.access].id
    precedence = 1
  }]
}
```

- `self_hosted` — aplikacja stoi u nas (w przeciwieństwie do aplikacji SaaS, np. Slacka).
- `allowed_idps` + `auto_redirect_to_identity` — tylko kod na maila, od razu formularz,
  bez ekranu wyboru metody.
- `app_launcher_visible = false` — Access ma stronę startową z listą aplikacji; ciocia jej
  nie potrzebuje, wchodzi prosto na swój adres.
- `policies` — `group[each.value.access]` łączy aplikację z regułą jej grupy. To tu
  nazwa grupy z `edge.auto.tfvars` spotyka listę maili z `access/<grupa>.json`.

`precondition` na końcu łapie najczęstszą pomyłkę: aplikacja wskazuje grupę, której
plik jeszcze nie powstał — bo skrypt projektu nie był uruchomiony. Bez niego Terraform
zgłosiłby ogólny błąd „invalid index”; z nim — zdanie po polsku z nazwą brakującego
pliku i skryptem, który go tworzy.

## 7. `tunnel.tf` — tunel, trasy, token

**Tunel:**

```hcl
resource "cloudflare_zero_trust_tunnel_cloudflared" "homelab" {
  name       = var.tunnel_name
  config_src = "cloudflare"
}
```

`config_src = "cloudflare"` to najważniejsza linijka pliku. Znaczy: trasy trzyma Cloudflare,
a cloudflared pobiera je sam. Alternatywa (`"local"`) to plik `config.yml` przy
cloudflared — czyli ConfigMapa w klastrze, którą trzeba by trzymać w zgodzie z DNS-em
w Terraformie. Tak jak jest, **cała wiedza o trasach żyje w jednym miejscu**, a cloudflared
potrzebuje tylko tokena.

Brak `tunnel_secret` — przy tunelu zarządzanym zdalnie Cloudflare generuje sekret sam.

**Trasy:**

```hcl
ingress = concat(
  [for name, app in var.apps : {
    hostname = "${name}.${var.zone_name}"
    service  = var.origin_service
    origin_request = { access = { required = true, team_name = …, aud_tag = [… .aud] } }
  }],
  [{ service = "http_status:404" }],
)
```

- `for name, app in var.apps` — po jednej regule na aplikację, z tej samej mapy.
- `origin_request.access` — druga linia obrony z rozdziału 3 (⑤). `aud_tag` bierze `aud`
  z aplikacji Access; stąd zależność tunel → Access.
- `concat(…, [{ service = "http_status:404" }])` — reguła końcowa. Cloudflare wymaga,
  żeby ostatnia reguła nie miała `hostname` i łapała wszystko inne. Odpowiada 404 od razu
  w cloudflared, bez dotykania klastra.

Czemu nie jedna reguła `*.gugnowski.com`? Byłoby krócej, ale wtedy nie da się wymagać
tokena *konkretnej* aplikacji, a każdy przyszły rekord na tunel trafiałby do Traefika.

**Token:**

```hcl
data "cloudflare_zero_trust_tunnel_cloudflared_token" "homelab" { … }
```

`data`, nie `resource` — token nie jest czymś, co tworzymy, tylko czymś, co *odczytujemy*
z istniejącego tunelu. Trafia do wyjścia `tunnel_token`, a stamtąd przez `setup.sh` do
klastra.

## 8. `dns.tf` — nazwy

```hcl
data "cloudflare_zone" "main" {
  filter = { name = var.zone_name }
}

resource "cloudflare_dns_record" "app" {
  for_each = var.apps
  name     = "${each.key}.${var.zone_name}"
  type     = "CNAME"
  content  = "${cloudflare_zero_trust_tunnel_cloudflared.homelab.id}.cfargotunnel.com"
  proxied  = true
  ttl      = 1
}
```

- `data "cloudflare_zone"` — wyszukanie strefy po nazwie, żeby nie wpisywać Zone ID ręcznie.
  Stąd uprawnienie *Zone: Read* w tokenie.
- `name` pełny, nie samo `automat-operat-dev` — API zwraca pełną nazwę, a krótka w konfiguracji
  dawałaby wieczną „zmianę” w każdym planie.
- CNAME na `<id>.cfargotunnel.com` + `proxied = true` — rozdział 2, „DNS: proxied czy nie”.
- `ttl = 1` — w API Cloudflare to „automatycznie”; przy proxied i tak decyduje Cloudflare.
- `comment` — w panelu przy rekordzie widać, że należy do Terraforma i nie należy go ruszać.

### Najważniejsza właściwość trzech plików naraz

`access.tf`, `tunnel.tf` i `dns.tf` iterują po **tej samej** mapie `var.apps`. Dopisanie
aplikacji tworzy trzy rzeczy naraz, usunięcie usuwa trzy rzeczy naraz. **Nie da się mieć
rekordu DNS bez aplikacji Access** — ani przez nieuwagę, ani przez częściowe usunięcie.
To jest główny powód, dla którego ta warstwa jest opisana kodem, a nie wyklikana: w panelu
te trzy rzeczy są na trzech różnych ekranach i łatwo zapomnieć o jednej.

## 9. `outputs.tf`

- `tunnel_id` — do porównania z panelem i rekordami DNS.
- `tunnel_token` — `sensitive`; `tofu output` go nie pokaże, `tofu output -raw tunnel_token`
  pokaże (tak czyta go `setup.sh`).
- `urls` — lista adresów; wypisuje ją `just edge apply` w sekcji „Dalej”.

[następny: cloudflared w klastrze →](edge-6-cloudflared.md)
