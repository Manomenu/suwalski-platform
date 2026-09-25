# 1. Problem i wybór rozwiązania

[← spis treści](edge-0.md) · [następny: pojęcia →](edge-2-pojecia.md)

## Problem

Aplikacja biegnie w k3s na `192.168.0.119` — w sieci domowej. Chcemy, żeby ciocia
otworzyła ją ze swojego telefonu, z dowolnego miejsca, pod ładnym adresem, z kłódką HTTPS,
i żeby **nikt poza nami dwojgiem** nie mógł jej otworzyć.

To są właściwie cztery osobne problemy:

1. **Dojście** — ruch z internetu musi trafić do maszyny w domu.
2. **Nazwa** — `witkowska-dev.gugnowski.com` musi prowadzić tam, a nie gdzie indziej.
3. **Szyfrowanie** — certyfikat HTTPS ważny dla tej nazwy.
4. **Tożsamość** — ktoś musi sprawdzić, kim jest odwiedzający, *zanim* ruch dotknie klastra.

Każde rozwiązanie niżej rozwiązuje te cztery punkty, tylko w innych miejscach i za inną cenę.

## Opcje

### A. Przekierowanie portu w routerze

Router przepuszcza porty 80/443 na `192.168.0.119`, rekord DNS wskazuje na domowe IP,
Traefik z cert-managerem wystawia certyfikat, a przed aplikacją stoi oauth2-proxy.

- **Dojście:** wymaga publicznego IP. Wielu operatorów daje dziś adres za CGNAT — wtedy
  nie da się tego zrobić wcale. Jeśli IP jest zmienne, potrzebny jest jeszcze dynamiczny DNS.
- **Bezpieczeństwo:** domowe IP jest publicznie znane, a port 443 w domu jest otwarty dla
  całego internetu. Każdy skaner świata puka do Traefika. Logowanie dzieje się już
  *w klastrze* — czyli atakujący jest w środku, zanim zostanie sprawdzony.
- **Koszt:** 0 zł, ale sporo ruchomych części (cert-manager, oauth2-proxy, DDNS).

### B. VPS + WireGuard

Tani serwer w chmurze ma publiczne IP, przyjmuje ruch i przez tunel WireGuard oddaje go
do domu.

- Rozwiązuje CGNAT i ukrywa domowe IP.
- Ale: płacisz za VPS (~5 $/mies.), utrzymujesz go (aktualizacje, firewall), a logowanie
  i certyfikaty nadal są na Twojej głowie. To budowanie własnej, gorszej wersji opcji E.

### C. Tailscale Funnel

Wystawia usługę z Tailnetu do internetu.

- Proste, ale adres jest w domenie Tailscale (`*.ts.net`), nie `gugnowski.com`, a logowania
  przed aplikacją Funnel nie robi — jest publiczny.
- Świetne do dostępu *dla siebie* (Tailscale bez Funnel), nie do wystawienia cioci.

### D. GKE + IAP (plan 1.0)

Klaster w Google Cloud, Load Balancer ze statycznym IP, IAP z logowaniem Google.

- Wszystko zarządzane przez Google, bardzo „po chmurowemu”.
- ~90 $/mies. i drugi klaster obok działającego homelabu. Odrzucone kosztowo.

### E. Cloudflare Tunnel + Access — wybrane

W klastrze biegnie **cloudflared**. Sam, od środka, otwiera stałe połączenia *wychodzące*
do Cloudflare. Ruch z internetu wchodzi do Cloudflare, tam przechodzi przez **Access**
(logowanie), i dopiero wtedy jest wpychany do domu tym gotowym połączeniem.

- **Dojście:** połączenie jest wychodzące, jak przeglądanie stron. Działa za CGNAT,
  przy zmiennym IP, bez żadnej zmiany w routerze. Domowe IP nigdzie się nie pojawia.
- **Nazwa:** domena już jest w Cloudflare — dochodzi jeden rekord na aplikację.
- **Szyfrowanie:** certyfikat dla `*.gugnowski.com` wystawia i odnawia Cloudflare.
- **Tożsamość:** sprawdzana **w Cloudflare**, zanim ruch wejdzie do tunelu. Obcy
  nigdy nie dotyka Twojej sieci.
- **Koszt:** 0 $. Tunel jest darmowy, Zero Trust w planie Free obsługuje do 50 osób.

## Co za to płacimy

Nic nie jest za darmo w sensie architektonicznym:

- **Cloudflare widzi ruch.** HTTPS kończy się u nich (tam jest certyfikat), a do domu
  ruch idzie ich zaszyfrowanym tunelem. Dla rodzinnej aplikacji — akceptowalne. Dla danych
  medycznych czy bankowych — do przemyślenia.
- **Zależność od jednej firmy.** Gdy Cloudflare ma awarię, aplikacja jest niedostępna.
  Zdarza się rzadko, ale się zdarza.
- **Dostępność = Twój dom.** Nie ma prądu, internetu albo Proxmox się restartuje — ciocia
  widzi stronę błędu Cloudflare. Tego żadna warstwa edge nie naprawi.
- **Regulamin.** Cloudflare nie życzy sobie przez darmowy plan serwowania głównie dużych
  plików wideo. Zwykła aplikacja webowa jest dokładnie tym, do czego to służy.

## Co z tego wynika dla kodu

Skoro wszystkie cztery problemy rozwiązuje Cloudflare, to warstwa `edge` jest w gruncie
rzeczy **konfiguracją Cloudflare opisaną kodem** — plus mały łącznik w klastrze. Nie ma
w niej cert-managera, oauth2-proxy, DDNS-u ani reguł firewalla. To jest jej główna zaleta:
mało kodu, który można zepsuć.

[następny: pojęcia →](edge-2-pojecia.md)
