# 7. Pierwsze uruchomienie

[← cloudflared w klastrze](edge-6-cloudflared.md) · [spis treści](edge-0.md) · [następny: codzienna praca →](edge-8-codzienna-praca.md)

Od zera do działającego logowania. Po każdym kroku jest **„powinieneś zobaczyć”** —
jeśli widzisz coś innego, zatrzymaj się i zajrzyj do [diagnostyki](edge-9-diagnostyka.md),
zamiast iść dalej.

Warunek wstępny: klaster homelab działa (`just argo apps` pokazuje aplikacje).

## Krok 1 — Zero Trust (panel, raz)

Jedyna rzecz klikana ręcznie: założenie organizacji Zero Trust nie ma sensownego
odpowiednika w Terraformie.

1. [one.dash.cloudflare.com](https://one.dash.cloudflare.com) → wybierz konto.
2. Wybierz **nazwę zespołu** (team name), np. `gugnowski`. To będzie adres
   `gugnowski.cloudflareaccess.com`.
3. Plan **Free**. Cloudflare może poprosić o kartę — nic z niej nie pobiera.

**Powinieneś zobaczyć:** panel Zero Trust z menu *Access*, *Networks*.

## Krok 2 — fakty o koncie do `edge.auto.tfvars`

W `terraform/edge/edge.auto.tfvars` uzupełnij:

- `account_id` — [dash.cloudflare.com](https://dash.cloudflare.com), strona domeny
  `gugnowski.com`, prawa kolumna, *Account ID*;
- `team_name` — to, co wybrałeś w kroku 1 (sama nazwa, bez `.cloudflareaccess.com`).

Te wartości idą do gita — nie są sekretami (rozdział 4).

## Krok 3 — token API (panel, raz)

*My Profile → API Tokens → Create Token → Create Custom Token*, z uprawnieniami z tabeli
w [rozdziale 4](edge-4-sekrety.md#token-api-cloudflare). Skopiuj token — pokazuje się raz.

**Powinieneś zobaczyć:** po utworzeniu Cloudflare proponuje `curl … /tokens/verify` —
możesz go uruchomić, ma zwrócić `"status": "active"`.

## Krok 4 — sekrety

```sh
./scripts/setup.sh
```

To skrypt **platformy**. Pyta o dotychczasowe wartości (Enter = bez zmian) i dwie nowe:

- `CLOUDFLARE_API_TOKEN` — token z kroku 3 (nie wyświetla się przy wpisywaniu);
- `ACCESS_ADMIN` — Twój mail (grupa `admin`, która wpuszcza na `witkowska-dev`).

Przy pierwszym uruchomieniu rozłoży też stary `.secrets.env` na `.secrets/platform.env`
i `.secrets/suwalski-investing-tools.env` — tego nie musisz robić ręcznie.

**Powinieneś zobaczyć:**
```
== terraform/edge ==
  zapisane: terraform/edge/secrets.auto.tfvars
  zapisane: terraform/edge/access/admin.json  (grupa „admin”)
…
  pominięte: token tunelu (tunelu jeszcze nie ma — najpierw: just edge apply)
```
To „pominięte” jest oczekiwane — tunel powstanie w kroku 6.

Grupa `witkowska` (Ty i ciocia) jest potrzebna dopiero produkcji. Możesz ją ustawić już
teraz — `plan` wtedy stworzy od razu obie reguły — albo później, razem z produkcją:

```sh
./scripts/projects/witkowska/prod/setup.sh     # ACCESS_WITKOWSKA: Twój i cioci, po przecinku
```

## Krok 5 — init i plan

```sh
(cd terraform/edge && tofu init)
just edge plan
```

**Powinieneś zobaczyć** `Plan: 6 to add, 0 to change, 0 to destroy` (albo 7, jeśli ustawiłeś już grupę `witkowska`):

| Zasób | Ile | Po co |
| --- | --- | --- |
| `cloudflare_zero_trust_access_identity_provider.otp` | 1 | kod na maila |
| `cloudflare_zero_trust_access_policy.group["admin"]` (+ `["witkowska"]`) | 1 (2) | reguły grup |
| `cloudflare_zero_trust_access_application.app["witkowska-dev"]` | 1 | ochrona hosta |
| `cloudflare_zero_trust_tunnel_cloudflared.homelab` | 1 | tunel |
| `cloudflare_zero_trust_tunnel_cloudflared_config.homelab` | 1 | trasy |
| `cloudflare_dns_record.app["witkowska-dev"]` | 1 | rekord |

Przeczytaj plan. Sprawdź zwłaszcza, że w `include` reguł są właściwe maile, a w rekordzie
`proxied = true`. Zasada z `AGENTS.md`: coś w kolumnie „destroy”, czego się nie
spodziewasz, to powód, żeby się zatrzymać — tu przy pierwszym razie nie ma prawa być nic.

## Krok 6 — apply

```sh
just edge apply
```

**Powinieneś zobaczyć:** `Apply complete! Resources: 6 added` (albo 7) i sekcję „Dalej” z adresem
`https://witkowska-dev.gugnowski.com`. W panelu Zero Trust → *Networks → Tunnels* pojawia się
tunel `homelab` ze statusem **Inactive** — jeszcze nikt się z nim nie łączy.

## Krok 7 — token do klastra

```sh
./scripts/setup.sh
```

Drugi raz — teraz tunel istnieje. **Powinieneś zobaczyć:**
```
  Secret cloudflared-token w przestrzeni cloudflared: aktualny
```

## Krok 8 — cloudflared przez Argo

Zacommituj i wypchnij zmiany (`argocd/apps/platform/cloudflared.yaml`,
`argocd/manifests/cloudflared/`). Argo zauważy je w ciągu ~3 minut — albo od razu po
`just argo refresh`.

```sh
just argo apps
just edge tunnel
```

**Powinieneś zobaczyć:** Application `cloudflared` jako `Synced / Healthy`, dwa pody
`Running`, a w logu linie `Registered tunnel connection`. W panelu tunel zmienia status
na **Healthy**.

## Krok 9 — test całej drogi

W oknie incognito otwórz `https://witkowska-dev.gugnowski.com`.

1. **Formularz kodu Cloudflare** — to krok ③ z rozdziału 3. Wpisz swój mail.
2. **Kod w skrzynce** (sprawdź spam) → wklej.
3. **`404 page not found`** — to Traefik (krok ⑥). **To jest sukces**: cała droga działa,
   brakuje tylko aplikacji z Ingressem na ten host.

Druga próba, z **mailem cioci**: formularz przyjmie adres, ale **kod nie przyjdzie**.
Tak ma być — dev wpuszcza tylko grupę `admin`, a ciocia jest w grupie `witkowska`.
To od razu sprawdza, że grupy są rozdzielone.

Próbne logowanie cioci zrobisz, gdy dojdzie produkcja (`witkowska = { access =
"witkowska" }`, rozdział 8). Wtedy przez telefon: jej pierwszy mail z kodem może
wylądować w spamie — niech oznaczy go jako „nie spam”.

## Co dalej

404 zamieni się w aplikację, gdy w projekcie (np. `argocd/apps/projects/witkowska-dev.yaml`)
pojawi się Ingress z hostem `witkowska-dev.gugnowski.com` — [rozdział 8](edge-8-codzienna-praca.md).

[następny: codzienna praca →](edge-8-codzienna-praca.md)
