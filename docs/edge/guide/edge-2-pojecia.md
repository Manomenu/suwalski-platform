# 2. Pojęcia

[← problem](edge-1-problem.md) · [spis treści](edge-0.md) · [następny: droga żądania →](edge-3-droga-zadania.md)

Cloudflare ma dużo produktów i własny słownik. Tu są tylko te słowa, które pojawiają się
w plikach warstwy — w kolejności, w jakiej na nie trafisz, idąc od domeny do klastra.

## Konto i strefa

**Konto (account)** — Twoje konto Cloudflare. Ma **Account ID**: 32 znaki szesnastkowe,
widoczne w panelu w prawej kolumnie. Tunel, reguły dostępu i metody logowania należą do
*konta* — dlatego prawie każdy zasób w `terraform/edge/` ma `account_id`.

**Strefa (zone)** — jedna domena w Cloudflare, tu `gugnowski.com`. Ma własne **Zone ID**.
Rekordy DNS należą do *strefy*, nie do konta — dlatego `dns.tf` najpierw wyszukuje strefę
po nazwie, żeby poznać jej ID.

## DNS: proxied czy nie

Rekord DNS w Cloudflare ma przełącznik **Proxy status**:

- **DNS only** (szara chmurka) — Cloudflare tylko odpowiada na pytanie „jaki adres ma ta
  nazwa” i podaje prawdziwy adres. Ruch idzie potem prosto tam, z pominięciem Cloudflare.
- **Proxied** (pomarańczowa chmurka) — Cloudflare podaje *swój* adres. Ruch przychodzi do
  Cloudflare, a ono decyduje, co z nim zrobić dalej.

Tunel działa **tylko proxied**. Rekord aplikacji to CNAME na `<id-tunelu>.cfargotunnel.com`
— nazwę, która istnieje wyłącznie wewnątrz Cloudflare. Bez proxy przeglądarka dostałaby
adres, którego nie da się odwiedzić.

> W planie 1.0 (GKE) rekord był „DNS only”, bo ruch miał iść prosto do Google. Tu jest
> odwrotnie i to nie jest pomyłka.

## Tunel i connector

**Tunel (Cloudflare Tunnel)** — obiekt po stronie Cloudflare: „istnieje droga do jakiejś
sieci, o nazwie `homelab` i identyfikatorze UUID”. Sam z siebie nic nie przesyła — to
bardziej *gniazdko* niż kabel.

**cloudflared** — program, który wpina się w to gniazdko od strony domu. Otwiera kilka
połączeń *wychodzących* do najbliższych serwerów Cloudflare i czeka. Gdy Cloudflare ma
żądanie dla tunelu, wysyła je tymi połączeniami, a cloudflared przekazuje je dalej, do
usługi w sieci lokalnej.

**Connector** — jedna uruchomiona kopia cloudflared podpięta pod tunel. Tunel może mieć
kilka connectorów naraz; Cloudflare rozkłada między nie ruch. My mamy dwa (dwie repliki
Deploymentu) — powód w rozdziale 6.

**Token tunelu** — hasło, którym cloudflared udowadnia, że wolno mu podpiąć się pod *ten*
tunel. Kto ma token, może podpiąć własnego cloudflared i przejąć ruch. Stąd całe
zamieszanie z trzymaniem go poza gitem (rozdział 4).

**Trasy tunelu (ingress rules)** — lista „host → dokąd oddać”. Np.
`automat-operat-dev.gugnowski.com → http://traefik.kube-system.svc.cluster.local:80`. Mogą leżeć
w pliku przy cloudflared albo w Cloudflare. U nas leżą w Cloudflare (`config_src =
"cloudflare"`) i opisuje je Terraform — cloudflared pobiera je sam po podłączeniu.

## Zero Trust i Access

**Zero Trust** — nazwa parasolowa na produkty Cloudflare do kontroli dostępu. Zakładasz
je raz dla konta i wybierasz **nazwę zespołu (team name)**, np. `gugnowski`. Z niej bierze
się adres strony logowania: `gugnowski.cloudflareaccess.com`.

**Access** — część Zero Trust, która stoi przed aplikacją jak bramkarz. Składa się
z trzech klocków, i to jest najważniejszy fragment tego rozdziału:

| Klocek | Pytanie | U nas |
| --- | --- | --- |
| **Metoda logowania** (identity provider, IdP) | *Jak* ktoś udowadnia, kim jest? | One-time PIN — kod na maila |
| **Reguła** (policy) | *Kogo* wpuszczamy? | „Grupa: automat-operat” — lista maili |
| **Aplikacja** (application) | *Co* chronimy? | host `automat-operat-dev.gugnowski.com` |

Aplikacja wskazuje regułę (lub kilka) i dozwolone metody logowania. Reguły są
wielokrotnego użytku: jedna grupa może chronić wiele aplikacji.

**One-time PIN** — metoda logowania wbudowana w Cloudflare. Wpisujesz maila, dostajesz
kod, wklejasz. Nie wymaga żadnej zewnętrznej aplikacji (w przeciwieństwie do „Zaloguj
przez Google”, które wymaga własnego OAuth clienta w Google Cloud). Kod przychodzi tylko
na adres, który przepuszcza jakaś reguła — obcy mail nic nie dostaje.

**Sesja** — po zalogowaniu Cloudflare zapisuje w przeglądarce ciasteczko
`CF_Authorization` ważne przez `session_duration` (u nas 30 dni). Do tego czasu kodu nie
trzeba wpisywać.

## Token Access i aud

Po zalogowaniu każde żądanie, które Cloudflare wpuszcza do tunelu, niesie **podpisany
token Access** (JWT) w nagłówku `Cf-Access-Jwt-Assertion`. Mówi on: „ten człowiek to
`ciocia@gmail.com`, zalogowany do aplikacji X, ważne do…”, i jest podpisany kluczem
Cloudflare.

**aud (audience tag)** — identyfikator konkretnej aplikacji Access, wpisany w token.
Dzięki niemu token wydany dla `automat-operat-dev.gugnowski.com` nie przejdzie jako przepustka do
innej aplikacji.

Ten token jest podstawą naszej **drugiej linii obrony**: cloudflared sprawdza go sam
(`origin_request.access.required = true` w `tunnel.tf`) i odrzuca żądania bez ważnego
tokena z właściwym `aud`. Szczegóły w rozdziale 3.

Przy okazji: nagłówek `Cf-Access-Authenticated-User-Email` niesie sam mail zalogowanej
osoby. Aplikacja może z niego czytać, kto jest po drugiej stronie, bez własnego logowania.

## Traefik i Ingress (przypomnienie)

To już znasz z homelabu, ale tu gra nową rolę:

**Traefik** — router HTTP wbudowany w k3s. Patrzy na nagłówek `Host` i według obiektów
**Ingress** decyduje, do którego Service w którym namespace oddać żądanie. Tunel oddaje
cały ruch Traefikowi, a Traefik rozdziela go po aplikacjach — dokładnie tak, jak dziś
rozdziela `*.k8s.suwalski.internal`.

[następny: droga żądania →](edge-3-droga-zadania.md)
