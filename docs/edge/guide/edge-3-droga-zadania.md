# 3. Droga jednego żądania

[← pojęcia](edge-2-pojecia.md) · [spis treści](edge-0.md) · [następny: wartości i sekrety →](edge-4-sekrety.md)

Ten rozdział łączy pojęcia z plikami. Idziemy za jednym żądaniem cioci, krok po kroku,
i przy każdym kroku zapisujemy: **kto** podejmuje decyzję i **który plik** ją opisuje.
Gdy potem będziesz czytać pliki (rozdziały 5–6), każdy zasób będzie miał swoje miejsce
na tej drodze.

Opisujemy produkcję — `automat-operat.gugnowski.com`, grupa `automat-operat` (Ty i ciocia). Dziś
wystawiony jest tylko dev, `automat-operat-dev.gugnowski.com` dla własnej grupy `automat-operat-dev`
(Ty i osoby testujące).
Droga jest identyczna; różni się nazwą hosta i listą osób.

```
 ciocia wpisuje https://automat-operat.gugnowski.com
   │
 ① DNS         automat-operat.gugnowski.com → adres Cloudflare              dns.tf
   │
 ② Cloudflare  certyfikat HTTPS, zakończenie TLS                     (automatycznie)
   │
 ③ Access      czy jest ważne ciasteczko CF_Authorization?          access.tf
   │   nie → strona logowania → mail → kod → ciasteczko → wróć do ③
   │   tak ↓  dokleja token Access (JWT) do żądania
   │
 ④ tunel       które trasy? automat-operat.gugnowski.com → Traefik           tunnel.tf
   │           (połączenie otworzone wcześniej przez cloudflared)
   │
 ⑤ cloudflared czy token Access jest ważny i dla tej aplikacji?      tunnel.tf (access.required)
   │           tak → http://traefik.kube-system.svc.cluster.local:80  argocd/manifests/cloudflared/
   │
 ⑥ Traefik     Host: automat-operat.gugnowski.com → który Ingress?          Ingress w projekcie
   │
 ⑦ Service → Pod aplikacji cioci                                     argocd/apps/projects/…
```

## ① DNS

Telefon cioci pyta DNS o `automat-operat.gugnowski.com`. Rekord (`dns.tf`) to CNAME na
`<id-tunelu>.cfargotunnel.com` z `proxied = true`. Cloudflare nie zdradza tej nazwy —
odpowiada adresem własnego serwera, najbliższego cioci.

**Gdy rekordu nie ma:** przeglądarka pokazuje „nie można znaleźć serwera”.

## ② TLS

Przeglądarka łączy się z Cloudflare po HTTPS. Certyfikat dla `gugnowski.com` i subdomen
Cloudflare wystawia i odnawia sam, dla każdej strefy z proxied rekordami. Nie ma tu
żadnego pliku — i to jest zaleta: nie ma cert-managera, którego trzeba pilnować.

## ③ Access — bramkarz

Cloudflare widzi, że host `automat-operat.gugnowski.com` należy do aplikacji Access (`access.tf`,
zasób `cloudflare_zero_trust_access_application.app["automat-operat"]`). Sprawdza ciasteczko:

- **Nie ma albo wygasło** → przekierowanie na `gugnowski.cloudflareaccess.com`. Dzięki
  `auto_redirect_to_identity = true` od razu na formularz kodu (jest tylko jedna metoda
  logowania, więc ekran wyboru byłby zbędny). Ciocia wpisuje maila. Cloudflare sprawdza,
  czy jakaś reguła aplikacji wpuszcza ten mail (`Grupa: automat-operat`) — jeśli tak, wysyła
  kod. Po wklejeniu kodu zapisuje ciasteczko na 30 dni i wraca do ③.
- **Jest ważne** → żądanie idzie dalej z doklejonym tokenem Access (JWT) w nagłówku
  `Cf-Access-Jwt-Assertion` i mailem w `Cf-Access-Authenticated-User-Email`.

To jest **pierwsza linia obrony** i najważniejsza: obcy odpada tutaj, w Cloudflare, i nie
generuje ani jednego pakietu w Twojej sieci.

## ④ Tunel

Cloudflare wie, że rekord wskazuje na tunel `homelab`, i sprawdza jego trasy
(`tunnel.tf`, zasób `cloudflare_zero_trust_tunnel_cloudflared_config`). Pierwsza pasująca
reguła: `automat-operat.gugnowski.com → http://traefik.kube-system.svc.cluster.local:80`.

Żądanie leci do domu połączeniem, które cloudflared otworzył *wcześniej, od środka*.
Router widzi tylko ruch w ramach połączenia wychodzącego — nie ma czego przekierowywać.

**Gdy nie działa żaden connector:** Cloudflare pokazuje błąd 1033 („tunel nie ma
połączenia”). To znaczy: problem po stronie klastra, nie Cloudflare.

## ⑤ cloudflared — druga linia obrony

Tu jest decyzja, którą warto zrozumieć. Trasa ma ustawione:

```hcl
origin_request = {
  access = {
    required  = true
    team_name = var.team_name
    aud_tag   = [cloudflare_zero_trust_access_application.app[name].aud]
  }
}
```

cloudflared sprawdza token z ③: czy jest podpisany przez Cloudflare Twojego zespołu i czy
ma `aud` aplikacji `automat-operat`. Jeśli nie — odrzuca żądanie i nie przekazuje go dalej.

**Po co, skoro Access już sprawdził?** Bo Access chroni tylko hosty, dla których istnieje
aplikacja Access. Gdyby kiedyś w panelu ktoś (albo przyszły Ty) dodał rekord DNS na tunel
*bez* aplikacji Access, ruch przeszedłby ③ bez logowania. Z tym ustawieniem i tak odbije się
w ⑤. To tania asekuracja przed pomyłką — dokładnie takiego rodzaju, jaki zdarza się
po miesiącach, gdy nikt już nie pamięta szczegółów.

Dlatego też trasy są **osobne dla każdej aplikacji**, a nie jedna `*.gugnowski.com`:
każda wymaga tokena *swojej* aplikacji.

## ⑥ Traefik

cloudflared oddaje żądanie Traefikowi zwykłym HTTP (wewnątrz klastra, więc bez TLS).
Nagłówek `Host` jest nadal `automat-operat.gugnowski.com`, więc Traefik szuka Ingressu z tym hostem.

Ingress **nie jest częścią edge**. Należy do projektu aplikacji (np. namespace
`automat-operat-dev`), obok jej Deploymentu i Service'u. Edge wpuszcza ruch do klastra;
projekt decyduje, co z nim zrobić.

**Gdy Ingressu jeszcze nie ma:** po zalogowaniu widzisz `404 page not found` od Traefika.
To dobry znak przy pierwszym uruchomieniu — znaczy, że cała droga ①–⑥ działa, a brakuje
tylko aplikacji.

## ⑦ Pod

Service kieruje ruch do poda aplikacji. Aplikacja widzi zwykłe żądanie HTTP z nagłówkiem
`Cf-Access-Authenticated-User-Email` — może z niego wziąć, kto jest zalogowany.

## Mapa: krok → plik

| Krok | Decyduje | Plik |
| --- | --- | --- |
| ① nazwa → Cloudflare | DNS Cloudflare | `terraform/edge/dns.tf` |
| ③ kto wchodzi | Access | `terraform/edge/access.tf` |
| ④ host → usługa w domu | tunel | `terraform/edge/tunnel.tf` (config) |
| ⑤ sprawdzenie tokena | cloudflared | `terraform/edge/tunnel.tf` (access.required) |
| ④⑤ połączenie z domu | cloudflared | `argocd/manifests/cloudflared/deployment.yaml` |
| ⑥ host → aplikacja | Traefik | Ingress w projekcie aplikacji |

## Luka, o której warto wiedzieć

Traefik słucha też w sieci domowej pod `192.168.0.119` (tak działa dziś
`*.k8s.suwalski.internal`). Ktoś **w Twoim LAN-ie** może wysłać tam żądanie z nagłówkiem
`Host: automat-operat.gugnowski.com` i ominąć ③ oraz ⑤. Dla domowej sieci to akceptowalne.
Gdyby kiedyś nie było: aplikacja sama sprawdza podpis tokena z `Cf-Access-Jwt-Assertion`
— wtedy bez przejścia przez Cloudflare nie ma jak go podrobić.

[następny: wartości i sekrety →](edge-4-sekrety.md)
