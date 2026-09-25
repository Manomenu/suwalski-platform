# 4. Wartości i sekrety

[← droga żądania](edge-3-droga-zadania.md) · [spis treści](edge-0.md) · [następny: pliki Terraforma →](edge-5-terraform.md)

Zanim przeczytasz pliki, warto wiedzieć, skąd biorą się wartości, które w nich widać.
Warstwa ma **trzy rodzaje danych** i każdy trafia gdzie indziej — z konkretnego powodu.

## Trzy rodzaje danych

| Rodzaj | Przykład | Gdzie | W gicie? | Czemu |
| --- | --- | --- | --- | --- |
| Decyzja projektowa | dokąd tunel oddaje ruch, długość sesji | `default` w `variables.tf` | tak | taka sama na każdej instalacji |
| Fakt o koncie | Account ID, domena, team name, lista aplikacji | `edge.auto.tfvars` | **tak** | opisuje *to* środowisko; nie jest tajny |
| Sekret | token API Cloudflare | `secrets.auto.tfvars` | nie | daje władzę nad kontem |
| Dane osobowe | maile Twój i cioci | `access/<grupa>.json` | nie | **repo jest publiczne** |
| Wynik | token tunelu | stan Terraforma → Secret w klastrze | nie | powstaje dopiero przy `apply` |

To ten sam podział co w `cluster/` (patrz `AGENTS.md`, „Warstwy wartości”), z jednym
nowym rodzajem: **dane osobowe**.

### Czemu maile są „sekretem”, skoro nie są hasłem

Mail cioci nie daje nikomu władzy nad niczym. Ale `suwalski-platform` jest publiczne
(Argo czyta je bez logowania), a publikowanie cudzego adresu w publicznym repo to
naruszenie prywatności. Dlatego:

- w gicie (`edge.auto.tfvars`) jest tylko **nazwa grupy**, którą aplikacja wpuszcza:
  `witkowska-dev = { access = "admin" }`;
- kto należy do grupy — lista maili — jest w pliku `terraform/edge/access/<grupa>.json`,
  poza gitem.

Maile **nie** są ukrywane w wyniku `plan` (nie są `sensitive`). To świadome: nie są
tajne przed Tobą, tylko przed światem, a ukryte nie pozwoliłyby zobaczyć, kogo dopisujesz.

### Czemu grupy to osobne pliki, a nie jedna zmienna

Grupy należą do różnych **właścicieli**: `admin` (Ty) to sprawa platformy, a `witkowska`
(Ty i ciocia) to sprawa projektu witkowska. Każdą ustawia inny skrypt (niżej). Gdyby
wszystkie grupy siedziały w jednej zmiennej w jednym pliku, każdy skrypt musiałby ten plik
przepisywać — i skrypt projektu kasowałby grupę platformy albo odwrotnie.

Dlatego **plik = grupa**: `access/admin.json`, `access/witkowska.json`. Każdy skrypt
dokłada tylko swój plik, a `access.tf` składa grupy ze wszystkiego, co w katalogu leży.
To ten sam wzór co kubeconfigi w `~/.kube/configs/` — addytywnie, bez znaczenia kolejności.

### Czemu Account ID jest w gicie

Cloudflare sam pisze, że Account ID nie jest sekretem: bez tokena nic się z nim nie
zrobi. A trzymanie go w gicie znaczy, że skopiowanie repo na inne konto kończy się
czytelnym błędem walidacji, a nie cichą próbą działania na cudzym.

## Skąd biorą się pliki z sekretami

Nikt ich nie pisze ręcznie. Sekrety są podzielone według tego, **do kogo należą** —
platformy czy konkretnego projektu i środowiska — i każdy zakres ma własne źródło
w `.secrets/` (poza gitem) oraz własny skrypt:

```
scripts/setup.sh                                  PLATFORMA
    pyta o: PROXMOX_API_TOKEN, SSH_PUBLIC_KEY, CLOUDFLARE_API_TOKEN, ACCESS_ADMIN
    ├─> .secrets/platform.env                     źródło, 600
    ├─> terraform/cluster/secrets.auto.tfvars     Proxmox, SSH
    ├─> terraform/edge/secrets.auto.tfvars        token Cloudflare
    ├─> terraform/edge/access/admin.json          grupa „admin”: Ty
    └─> Secret cloudflared-token w klastrze       token tunelu, z wyjścia terraform/edge

scripts/projects/witkowska/prod/setup.sh          PROJEKT witkowska, środowisko prod
    pyta o: ACCESS_WITKOWSKA
    ├─> .secrets/witkowska-prod.env
    └─> terraform/edge/access/witkowska.json      grupa „witkowska”: Ty i ciocia

scripts/projects/witkowska/dev/setup.sh           PROJEKT witkowska, środowisko dev
    dziś nic — dev wpuszcza grupę „admin” z platformy; tu dojdą hasła aplikacji

scripts/projects/suwalski-investing-tools/setup.sh
    pyta o: SEC_USER_AGENT  ──>  Secret suwalski-sec
```

Listy maili podajesz po przecinku (`ty@gmail.com, ciocia@gmail.com`), skrypt zamienia je
na listę JSON. Wspólne kawałki skryptów (pytanie, maskowanie, zapis grupy, Secret) są
w `scripts/.internal/lib.sh`, więc skrypt projektu to kilkanaście linijek.

## Token API Cloudflare

Terraform rozmawia z Cloudflare tokenem API. **Nigdy globalnym kluczem konta** — ten daje
władzę nad wszystkim, łącznie z usunięciem domeny.

### Jak czytać uprawnienie tokena

Każde uprawnienie tokena Cloudflare to **trzy pola wybierane z list**, w jednym wierszu
formularza:

```
[ Zakres ▾ ]   [ Rodzaj zasobu ▾ ]    [ Poziom ▾ ]
  Zone           DNS                    Edit
```

1. **Zakres** — *na czym* token działa. Dwie wartości, które nas dotyczą:
   - **Account** — rzeczy należące do całego konta, niezależne od domeny: tunele, Access,
     metody logowania;
   - **Zone** — rzeczy należące do jednej **strefy**, czyli jednej domeny (rozdział 2,
     „Konto i strefa”): rekordy DNS, ustawienia domeny.
2. **Rodzaj zasobu** — *które* rzeczy w tym zakresie, np. `DNS` (rekordy), `Zone`
   (podstawowe informacje o samej domenie), `Cloudflare Tunnel`.
3. **Poziom** — `Read` (tylko odczyt) albo `Edit` (odczyt i zmiany).

Czyli wiersz **Zone · DNS · Edit** czyta się: „w obrębie domeny wolno czytać i zmieniać
rekordy DNS”. A **Zone · Zone · Read** — „wolno odczytać podstawowe dane domeny”
(nam potrzebne do znalezienia jej ID po nazwie). Słowo „Zone” pojawia się tam dwa razy,
bo raz jest zakresem, a raz rodzajem zasobu.

Pod listą uprawnień są jeszcze dwa pola, które zawężają zakres do konkretnych rzeczy:

- **Account Resources** → *Include → Twoje konto* — token działa tylko na tym koncie;
- **Zone Resources** → *Include → Specific zone → gugnowski.com* — uprawnienia „Zone”
  działają tylko dla tej jednej domeny, nie dla innych, które kiedyś dodasz.

### Uprawnienia dla tej warstwy

Token tworzysz w panelu: *My Profile → API Tokens → Create Token → Create Custom Token*,
z dokładnie tymi wierszami:

| Zakres | Rodzaj zasobu | Poziom | Po co |
| --- | --- | --- | --- |
| Account | Cloudflare Tunnel | Edit | tunel, jego trasy, odczyt tokena |
| Account | Access: Apps and Policies | Edit | aplikacje i reguły Access |
| Account | Access: Organizations, Identity Providers, and Groups | Edit | metoda logowania One-time PIN |
| Zone — `gugnowski.com` | DNS | Edit | rekordy aplikacji |
| Zone — `gugnowski.com` | Zone | Read | wyszukanie strefy po nazwie (`dns.tf`) |

Do tego *Account Resources* i *Zone Resources* jak w poprzedniej sekcji. Efekt: token nie
może dotknąć innych domen ani innych produktów Cloudflare niż te pięć rzeczy.

## Token tunelu — najciekawszy przypadek

Ten sekret **nie istnieje, zanim Terraform nie zadziała**: powstaje razem z tunelem. Więc
nie może być w `.secrets/` — nie ma go skąd wpisać. Droga wygląda tak:

```
just edge apply
   └─> Cloudflare tworzy tunel, Terraform czyta jego token (data source w tunnel.tf)
       └─> wyjście `tunnel_token` (sensitive) w stanie terraform/edge
           └─> ./scripts/setup.sh czyta je: tofu output -raw tunnel_token
               └─> Secret cloudflared-token w namespace cloudflared
                   └─> Deployment cloudflared: env TUNNEL_TOKEN z tego Secretu
```

Stąd zasada: **po pierwszym `just edge apply` uruchom `./scripts/setup.sh` jeszcze raz.**
Za pierwszym razem skrypt napisze „pominięte: token tunelu (tunelu jeszcze nie ma)”.

### Czemu nie prościej — Terraform od razu wkłada Secret do klastra?

Mógłby: wystarczyłby provider `kubernetes` w `edge/`. Ale wtedy `edge` potrzebuje
kubeconfiga i działającego klastra — traci swoją największą zaletę: niezależność.
Dziś możesz postawić tunel i logowanie, zanim klaster istnieje, a przebudowa klastra
nie dotyka Cloudflare. Mostem między warstwami jest `setup.sh`, który już pełni tę rolę
dla `suwalski-sec` — nowa rzecz nie wprowadza nowego mechanizmu.

### Czemu nie w gicie, zaszyfrowany?

Docelowo tak — `TODO.md` opisuje SOPS + age dla wszystkich sekretów repo. Do tego czasu
token idzie tą samą drogą co pozostałe sekrety.

## Stan Terraforma też jest wrażliwy

Stan `terraform/edge/terraform.tfstate` leży lokalnie (jak w `cluster/` i `platform/`)
i **zawiera token tunelu otwartym tekstem** — tak działa każdy stan Terraforma z danymi
`sensitive`: ukrywa je na ekranie, nie w pliku. `.gitignore` go wyklucza. Nie wysyłaj go
nikomu i nie wrzucaj „na chwilę” do gista.

[następny: pliki Terraforma →](edge-5-terraform.md)
