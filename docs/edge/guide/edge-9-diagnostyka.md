# 9. Diagnostyka

[← codzienna praca](edge-8-codzienna-praca.md) · [spis treści](edge-0.md) · [następny: decyzje →](edge-10-decyzje.md)

Najpierw ustal, **na którym kroku drogi z rozdziału 3** się zatrzymało. Objaw zwykle to
zdradza — i od razu mówi, czy szukać w Cloudflare, czy w klastrze.

| Objaw | Krok | Gdzie szukać |
| --- | --- | --- |
| „Nie można znaleźć serwera” | ① DNS | rekord w `dns.tf`, `dig automat-operat-dev.gugnowski.com` |
| Nie ma formularza kodu, od razu treść / 404 | ③ Access | aplikacja w `access.tf` dla tego hosta |
| Kod nie przychodzi | ③ Access | spam; czy mail jest w `terraform/edge/access/<grupa>.json` |
| Błąd Cloudflare **1033** | ④ tunel | cloudflared w klastrze nie ma połączenia |
| Błąd **502 / Bad gateway** po zalogowaniu | ⑤→⑥ | cloudflared nie dociera do Traefika |
| **403** od cloudflared po zalogowaniu | ⑤ | `team_name` / `aud` w trasie |
| `404 page not found` (czysty tekst) | ⑥ Traefik | brak Ingressu z tym hostem |
| Pętla przekierowań | ⑦ aplikacja | aplikacja wymusza HTTPS |

## Narzędzia

```sh
just edge tunnel                        # pody cloudflared + ostatnie linie logu
just argo apps                          # czy Application cloudflared jest Synced/Healthy
just edge plan                          # czy Cloudflare zgadza się z kodem (drift)
dig +short automat-operat-dev.gugnowski.com      # adresy Cloudflare = rekord jest proxied
```

Panel: Zero Trust → *Networks → Tunnels* (status tunelu i connectory),
*Logs → Access* (kto próbował wejść i z jakim wynikiem).

## Przypadki

### 1033 — tunel bez połączenia

cloudflared nie trzyma tunelu. Po kolei:

- `just edge tunnel` — czy pody w ogóle są?
  - **`CreateContainerConfigError`** → brak Secretu `cloudflared-token`.
    Uruchom `./scripts/setup.sh` (musi być po `just edge apply`).
  - **`CrashLoopBackOff`** → zobacz log. `Unauthorized` / `invalid token` znaczy token
    z innego tunelu — np. tunel był usunięty i stworzony od nowa. `setup.sh` jeszcze raz,
    potem `kubectl -n cloudflared rollout restart deploy/cloudflared`.
  - **brak podów w ogóle** → Argo nie ma Application'a: czy zmiany są wypchnięte?

### 502 po zalogowaniu

Cloudflare i tunel działają, ale cloudflared nie może oddać ruchu dalej. W logu cloudflared
szukaj `dial tcp` / `no such host`: zła wartość `origin_service` albo Traefik nie działa
(`kubectl -n kube-system get svc traefik`).

### 403 od cloudflared (nie od Access)

Druga linia obrony odrzuciła żądanie mimo zalogowania. Prawie zawsze: `team_name`
w `edge.auto.tfvars` nie zgadza się z nazwą zespołu w Zero Trust. Sprawdź adres strony
logowania — `<team_name>.cloudflareaccess.com`.

### Kod nie przychodzi

1. Spam — najczęściej.
2. Mail spoza listy — to zamierzone. Sprawdź *Logs → Access* w panelu.
3. Literówka w mailu — `just edge plan` nic nie zmieni, bo stan zgadza się z (błędnym)
   plikiem. Zajrzyj do `terraform/edge/access/<grupa>.json` i popraw przez skrypt, który
   go pisze.
4. Aplikacja wskazuje inną grupę, niż myślisz — `edge.auto.tfvars`, pole `access`.

### Pętla przekierowań

Aplikacja widzi ruch jako HTTP (od Traefika) i przekierowuje na HTTPS, który znowu dociera
jako HTTP. Aplikacja ma ufać nagłówkowi `X-Forwarded-Proto: https`, który Cloudflare
ustawia — w większości frameworków to opcja „trust proxy”.

### `apply` mówi, że One-time PIN już istnieje

Konto może mieć już metodę One-time PIN (np. włączoną kiedyś w panelu). Zamiast tworzyć
drugą, przejmij istniejącą:

```sh
cd terraform/edge
tofu import 'cloudflare_zero_trust_access_identity_provider.otp' 'accounts/<account_id>/<id-z-panelu>'
```

ID jest w panelu: *Settings → Authentication → One-time PIN*.

### `plan`: „nie ma pliku access/<grupa>.json”

Aplikacja w `edge.auto.tfvars` wskazuje grupę, której plik jeszcze nie powstał. Uruchom
skrypt, który tę grupę zapisuje — tabela jest w `terraform/edge/access/README.md`.

### Plan pokazuje zmiany, których nie robiłeś

Ktoś (Ty) zmienił coś w panelu. `apply` przywróci stan z kodu. Jeśli zmiana z panelu była
słuszna — przenieś ją najpierw do kodu, potem `plan` ma pokazać „No changes”.

[następny: decyzje →](edge-10-decyzje.md)
