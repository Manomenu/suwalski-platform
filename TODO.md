# TODO

Rzeczy do przemyślenia, nie do zrobienia od ręki. Każda dostaje własną sesję — tutaj
zapisujemy tylko, o co chodziło i dlaczego, żeby pomysł nie zginął.

---

## Sekrety bez ręcznego zarządzania

**Status:** w dużej mierze zastąpione przez `just secrets backup|restore` (kopia `.secrets/`
w Bitwardenie) — największy problem, czyli „gdzie trzymać sekrety, żeby przetrwały utratę
laptopa”, jest rozwiązany. Wracać tu dopiero, gdy ręczne `setup.sh` zacznie męczyć albo
pojawi się druga osoba.

Dziś sekrety leżą otwartym tekstem w `.secrets/` (poza gitem, po pliku na zakres), a skrypty `setup.sh`
rozprowadza je stamtąd do `terraform/cluster/secrets.auto.tfvars` i do Secretów
w klastrze. Działa, jest idempotentne i wystarcza przy trzech wartościach. **Przy
dziesięciu zacznie męczyć** — a przy odtwarzaniu klastra od zera trzeba je mieć gdzieś
z boku, co znaczy „w kolejnym pliku, o którym trzeba pamiętać".

### Czego szukamy

Żeby sekret mógł **leżeć w gicie** w postaci zaszyfrowanej, a odszyfrowywał go ten, kto ma
klucz. Wtedy odtworzenie środowiska to `git clone` plus jeden klucz, zamiast polowania na
wartości.

### Kandydaci, od najlżejszego

| | Co daje | Koszt |
| --- | --- | --- |
| **SOPS + age** | Szyfruje **pliki** — więc obejmuje i `tfvars`, i manifesty Kubernetesa. Jeden klucz, zero komponentów w klastrze. | Trzeba zabezpieczyć klucz `age` i pamiętać o nim przy nowej maszynie. |
| **Sealed Secrets** | Kontroler w klastrze; szyfrujesz jego kluczem publicznym, wynik idzie do gita. | Obejmuje **tylko** Secrety Kubernetesa — `tfvars` zostają na boku. Dodatkowy pod. |
| **External Secrets** | Pobiera sekrety z zewnętrznego magazynu do klastra. | Wymaga tego magazynu, czyli problem przesuwa się piętro wyżej. |
| **Vault** | Pełny magazyn z politykami, rotacją, audytem. | Ciężki: własny stan, odpieczętowanie po restarcie, kopie zapasowe. Przy jednym użytkowniku to armata na muchę. |

**Skłaniam się do SOPS + age** — jako jedyny obejmuje oba miejsca, w których trzymamy
sekrety, i nie dokłada niczego do klastra. Vault ma sens, gdyby pojawili się inni ludzie
albo potrzeba rotacji.

### Do rozstrzygnięcia przy realizacji

- gdzie trzymać klucz `age`, żeby przetrwał utratę laptopa, ale nie leżał w repo,
- czy `setup.sh` zostaje jako warstwa wygody, czy znika na rzecz `sops -d`,
- czy przy okazji nie przenieść `SEC_USER_AGENT` do zwykłej ConfigMapy — to adres
  e-mail, a nie hasło, więc traktowanie go jak sekretu jest może na wyrost.

## Strona startowa z linkami do usług

**Status:** zapisane, nieprzeanalizowane.

Jedna strona pod `http://suwalski.internal` z odnośnikami do wszystkiego, co stoi
w domu — Argo CD, NAS, AdGuard, Proxmox, i co tam jeszcze dojdzie. Konfigurowana
deklaratywnie, plikiem w repo, nie klikaniem.

### Czemu to nie jest tylko ozdoba

Dziś adresy usług siedzą w zakładkach przeglądarki i w głowie. Przy każdej nowej usłudze
dochodzi kolejny, a przy zmianie adresu żaden się nie aktualizuje. Strona startowa
generowana z konfiguracji to jedno miejsce, które zawsze mówi prawdę.

### Do rozstrzygnięcia

- **Czym.** Kandydaci to narzędzia konfigurowane plikami YAML (Homepage, Homer). Odpadają
  te, w których układ klika się w interfejsie — to dokładnie to, od czego uciekamy.
- **Gdzie.** To jest **aplikacja**, nie infrastruktura, więc jej miejsce jest w klastrze
  i pod Argo CD, a nie w Terraformie. Byłby to dobry drugi test pętli GitOps po Fazie 5.
- **Czy da się bez ręcznej listy.** Część tych narzędzi potrafi **wyczytać usługi
  z Ingressów** w klastrze i pokazać je automatycznie. Wtedy nowa usługa pojawia się na
  stronie sama, tak jak dziś sama dostaje nazwę dzięki wpisowi wieloznacznemu. Rzeczy
  spoza klastra (NAS, Proxmox, AdGuard) i tak trzeba by wypisać ręcznie — ale raz.

### Haczyk z DNS

`suwalski.internal` to **goła domena**, więc wpis wieloznaczny `*.k8s.suwalski.internal`
jej nie obejmuje. Potrzebny osobny wpis A w AdGuardzie — i to drugi raz, kiedy trzeba tam
zajrzeć. Alternatywa: umieścić stronę pod `home.k8s.suwalski.internal` i nie dotykać DNS-u
wcale, kosztem dłuższego adresu.

## Cały Proxmox jako kod, nie tylko jedna maszyna

**Status:** zapisane, nieprzeanalizowane. Nic nie było badane pod tym kątem.

Dziś Terraform zarządza **jedną** maszyną — węzłem k3s (ID 119). Wszystko inne, co stoi na
`aoostar` (ID 112–118: NAS, routing, VPN, DNS, monitoring, dashboard, media), powstało
przez klikanie i nie jest nigdzie opisane. Pomysł: przenieść resztę pod ten sam reżim, tak
żeby cały hypervisor dało się odtworzyć z repo.

### Główna motywacja: sieć

Nie chodzi o porządek dla porządku — chodzi o to, żeby **sieć klastra przestała być tą
samą siecią, co domowa**. Obecnie węzeł siedzi na `vmbr0` w `192.168.0.0/24`, obok
wszystkiego innego: laptopa, telewizora, telefonów. Czyli klaster i prywatne urządzenia
widzą się nawzajem bez żadnej granicy.

Do przemyślenia przy okazji:

- osobny mostek albo VLAN dla maszyn zarządzanych kodem,
- czy da się to opisać Terraformem (provider ma zasoby na mostki i VLAN-y — do sprawdzenia,
  bo część z nich w wersji 0.113 jest oznaczona jako przestarzała),
- co się wtedy dzieje z dostępem z laptopa: przez router, przez Tailscale, a może jedno
  i drugie zależnie od tego, do czego.

### Deklaratywny DNS i odejście od AdGuarda

**Osobne zadanie, do zrobienia w tym repo** — `terraform/dns/`.

Dziś wpisy DNS klika się w interfejsie AdGuarda (LXC 115). Cel: opisać strefę kodem, tak
jak resztę infrastruktury, i zmigrować z AdGuarda albo zostawić go wyłącznie do blokowania
reklam.

Ustalenia, które już zapadły przy Fazie 4:

- **DNS zostaje poza klastrem.** Jeśli mieszka w klastrze, a klaster leży, nie rozwiążesz
  nazw, żeby go zdiagnozować. Cały dom zależy od tego DNS-u. LXC obok klastra to właściwe
  miejsce.
- **Należy do Terraforma, nie do Argo CD.** DNS to infrastruktura, nie aplikacja. Argo ma
  pilnować tego, co biegnie w klastrze, i tyle.
- **„Dwa DNS-y" już istnieją i to nie problem.** AdGuard obsługuje sieć domową, CoreDNS
  strefę `*.svc.cluster.local` w klastrze. Współistnieją, bo odpowiadają za rozłączne
  zbiory nazw. Groźne byłyby dwa źródła prawdy dla *tych samych* nazw.
- **Wpis wieloznaczny załatwia 90% problemu bez migracji.** `*.k8s.suwalski.internal` na
  adres węzła sprawia, że nowa usługa nie wymaga dotykania DNS-u — resztę rozstrzyga
  Ingress. Faza 4 z tego korzysta; migracja jest ulepszeniem, nie warunkiem.
- **Nazewnictwo: zostajemy przy `.internal`.** ICANN zarezerwowało tę końcówkę do użytku
  prywatnego. `.local` jest zajęte przez mDNS i potrafi psuć rozwiązywanie nazw.

Do rozstrzygnięcia przy realizacji: czy AdGuard ma API nadające się do Terraforma, czy
prościej zamienić go na serwer sterowany plikiem konfiguracyjnym.

### Certyfikaty dla nazw wewnętrznych

Przy końcówce `.internal` **nie da się** dostać certyfikatu z Let's Encrypt — wystawiają
tylko dla domen realnie posiadanych. Dopóki chodzimy po HTTP w sieci domowej, nie ma
problemu. Gdyby kiedyś przeszkadzało ostrzeżenie przeglądarki, są dwie drogi: własne CA
dodane do zaufanych na urządzeniach, albo prawdziwa domena z uwierzytelnianiem DNS-01.

### Wątek poboczny, na razie czysta spekulacja

Dziś ścieżki DNS do usług ustawiane są **ręcznie w AdGuardzie** (LXC 115) i stamtąd kierują
na nginxa. To działa, ale jest konfiguracją, która istnieje tylko w interfejsie jednego
kontenera — czyli dokładnie tym, od czego uciekamy.

Pytania otwarte, żadne niezweryfikowane:

- czy dałoby się porzucić ręczne wpisy na rzecz czegoś generowanego z kodu,
- czy przy sensownym ingressie w klastrze **AdGuard w ogóle byłby jeszcze potrzebny** w tej
  roli — może zostałby tylko do blokowania reklam, a nie do kierowania ruchu,
- czy rolę „gdzie jest dana usługa" powinien przejąć ingress plus jeden wpis wieloznaczny
  w DNS, zamiast wpisu na każdą usługę osobno.

To są luźne przypuszczenia spisane na gorąco, a nie plan. Zanim cokolwiek, trzeba obejrzeć,
jak ten DNS i nginx są dziś naprawdę skonfigurowane.

### Czego ta zmiana nie może zepsuć

Na tym hypervisorze stoją rzeczy używane na co dzień. Przejęcie ich przez Terraform oznacza
**import istniejącego stanu**, a nie postawienie od nowa obok — pomyłka tutaj kasuje NAS.
To jest główny powód, dla którego to zadanie wymaga własnej sesji i spokoju.

---

## Jakość repo na poziomie automat-operat

**Status:** zrobione 2.10.2026 — `just check` (11 kroków) i CI `.github/workflows/check.yml`;
zasady w AGENTS.md („Gdzie co leży”, „Bramka jakości”). Przegląd struktury: układ jest
spójny, poprawione były tylko nieaktualne opisy (README, `argocd/README.md`) i zdublowane
`just <warstwa> validate`, które przy okazji przepisywały pliki.

Zostało na później: `kubeconfig` w katalogu głównym repo (poza gitem, działa — rusza się
dopiero przy kontekstach wielu klastrów); opis OMV kodem — osobny punkt niżej.

---

## OpenMediaVault opisany kodem — i stały adres NAS-a

**Status:** zapisane. Adres: **stały `192.168.0.197` ustawiony w OMV 2.10.2026**; zostało
zarezerwować go w routerze (albo wyjąć z puli DHCP), żeby router nie dał go komuś innemu.

Dziś OMV (VM 113) i jego ustawienia są klikane albo wołane ręcznie przez `omv-rpc`; to, co
zrobiliśmy dla klasy „nas”, opisuje `docs/nas.md`. Cel: odtworzenie NAS-a z repo, tak jak
maszyny k3s.

### Adres OMV (rozwiązane w OMV, router do dokończenia)

OMV bierze adres z routera (`method: dhcp`, dziś `192.168.0.197`; wcześniejsza notatka
mówiła `.198`, więc adres już się kiedyś zmienił). Od tego adresu zależą:

- magazyn Proxmoksa `nas` (`nas_server` w `terraform/cluster/proxmox.auto.tfvars`) — czyli
  **dysk z bazą** maszyny k3s;
- montowanie SMB na hoście Proxmoksa (`/etc/fstab` → `/mnt/nas-maniumek`) — czyli Jellyfin;
- każde ręczne połączenie po SMB z laptopa.

Gdy router da OMV inny adres (np. po dłuższym wyłączeniu), wszystko to przestaje działać.

**Przyjęty standard w tym repo:** usługi, od których coś zależy, mają **stały adres**.
Maszyna k3s dostaje go w Terraformie (`vm_ip`, przez cloud-init — z komentarzem, dlaczego
nie DHCP). Dla OMV są dwie poprawne drogi:

| Droga | Jak | Uwagi |
| --- | --- | --- |
| **Rezerwacja DHCP w routerze** | adres na sztywno dla MAC `BC:24:11:A7:C0:09` (karta VM 113) | nic nie zmienia w OMV; router zostaje jedynym źródłem adresów; ręcznie w routerze |
| **Stały adres w OMV** | Network → ens18 → static `192.168.0.197/24`, brama `.1`, DNS | adres opisany przy NAS-ie; trzeba wybrać adres spoza puli DHCP routera, żeby nie było kolizji |

Do tego **nazwa zamiast adresu**: wpis w AdGuardzie (np. `nas.suwalski.internal` →
`192.168.0.197`). Wtedy SMB z laptopa (`\\nas.suwalski.internal\maniumek`) i `nas_server`
w Terraformie używają nazwy, a zmiana adresu to jedna poprawka w DNS. Uwaga: Proxmox musi
umieć tę nazwę rozwiązać (DNS hosta wskazuje na AdGuarda albo wpis w `/etc/hosts`).

### Właściwe zadanie: OMV w kodzie, bez utraty danych

Dwie różne rzeczy, dwa narzędzia — to typowy podział: Terraform opisuje **maszyny**, a
konfigurację **wewnątrz** systemu opisuje narzędzie do konfiguracji (Ansible) albo skrypt.

1. **Maszyna VM 113 w Terraformie** — przez `import` (blok `import` w OpenTofu), nie przez
   tworzenie od nowa. Import niczego nie zmienia na serwerze: dopisuje istniejącą maszynę
   do stanu. Kolejność bezpieczna dla danych:
   - napisać zasób tak, by odpowiadał obecnej konfiguracji (`qm config 113`), w tym
     `hostpci0` (kontroler SATA z dyskami RAID), `startup order=1,up=60`, `onboot`;
   - `tofu plan` ma pokazać **„1 to import, 0 to change, 0 to destroy”** — dopiero wtedy
     `apply`. Cokolwiek w „replace/destroy” = stop;
   - dyski danych (SSD w RAID1) **nie są dyskami Proxmoksa** — są na przekazanym
     kontrolerze, więc Terraform ich nie zna i nie może ich skasować. Ryzyko dotyczy tylko
     dysku systemowego OMV (20 GB na `local-lvm`) — przed importem kopia (`vzdump 113`)
     i eksport konfiguracji OMV (Backup / `omv-confdbadm`).
2. **Ustawienia OMV** (foldery współdzielone, NFS, SMB, użytkownicy, sieć) — dojrzałego
   providera Terraform dla OMV nie ma. Kandydaci:
   - **Ansible** z modułami/`omv-rpc` — idempotentne, czytelne, standard dla „konfiguracji
     wewnątrz maszyny”; dochodzi nowe narzędzie;
   - **skrypt `omv-rpc` w `.just/lib/`** (jak `nas-disk.sh`) — bez nowych narzędzi, ale
     idempotentność trzeba pilnować samemu;
   - zostawić ręcznie, ale **kopię konfiguracji OMV** trzymać poza serwerem i opis
     w `docs/nas.md` aktualny.
   Macierz RAID i system plików btrfs zostają ręczne w każdym wariancie — ich odtworzenie
   „z kodu” to formatowanie dysków z danymi.

### Do rozstrzygnięcia

- rezerwacja w routerze czy stały adres w OMV (i czy router ma API, żeby to też było kodem);
- Ansible czy skrypt — zależy, ile jeszcze maszyn poza k3s dojdzie (AdGuard, Jellyfin,
  tailscale też są dziś klikane);
- czy przy okazji przejść z montowania SMB na hoście (Jellyfin) na NFS — stabilniejsze dla
  Linuxa niż `cifs ... soft`.

---

## Martwy kod i „kontrakty” w platformie

**Status:** zapisane. Odpowiednik tego, co `automat-operat` ma od 3.10.2026 (knip, kontrakty
importów). Tu nie ma modułów, które importują się nawzajem, więc kontrakty importów w tamtej
postaci nie mają do czego się stosować — ich rolę pełnią już reguły w `.just/lib/repo-rules.sh`
(pary `apps/platform` ↔ `manifests`, moduły podpięte w justfile, finalizery). Zostają
odpowiedniki „martwego kodu” i kilka reguł o tym, kto czego dotyka.

### Martwy kod — do dopisania w `repo-rules.sh`

- **Funkcje w `scripts/.internal/lib.sh`, których nikt nie woła** (np. po usunięciu
  `migrate_old_env` nikt by nie zauważył, gdyby wywołania zostały, a funkcja nie — albo odwrotnie).
- **Skrypty w `.just/lib/`, do których nie odwołuje się żadna recepta ani workflow.**
- **Wyjścia Terraformu, których nic nie czyta** (żaden skrypt, recepta, dokument) — tak
  przetrwało wyjście `haslo`. Nieużywane zmienne łapie już tflint.
- **Klucze w plikach `.secrets/*.env`, których żaden `setup.sh` nie czyta** — sprawdzalne tylko
  lokalnie (pliki poza gitem), więc jako ostrzeżenie w `just check live`, nie w CI.

### Kto czego dotyka

- `scripts/projects/<projekt>/…` pisze tylko do `.secrets/<projekt>[-<środowisko>].env`
  i do grup Access swojego projektu — nigdy do plików innego projektu ani platformy.
- Recepty w `.just/*.just` wołają tylko `.just/lib/` (nie `scripts/.internal/`, które należą
  do `setup.sh`).
- Warstwy Terraformu nie czytają nawzajem swojego stanu (`terraform_remote_state`); wartości
  między warstwami przenoszą skrypty z wyjść (jak AUD do ConfigMapy) — dziś tak jest, reguła by
  tego pilnowała.

---

## Mocniejsza bramka: parametry projektów i manifesty

**Status:** zapisane.

### Parametry projektów względem ich chartów

Pliki w `argocd/apps/projects/` podają chartom projektów wartości (`server.databaseSecret`,
`server.accessConfigMap`, `ingress.host`, `image.pullSecret`…), ale nikt nie sprawdza, czy chart
je zna — Helm po cichu ignoruje nieznany klucz, więc literówka wychodzi dopiero na klastrze
(np. serwer bez bazy). `just check` mógłby:

- pobrać chart projektu w tej wersji, którą wskazuje Application (`targetRevision`),
- wyrenderować go z parametrami z pliku aplikacji (`helm template … --set …`),
- sprawdzić, że każdy parametr istnieje w `values.yaml` charta, a wynik przepuścić przez kubeconform.

W CI potrzebny jest dostęp tylko do odczytu do prywatnego `automat-operat` (osobny deploy key
jako sekret Actions) — albo krok tylko lokalny (`just check live`).

### Lint bezpieczeństwa i niezawodności manifestów

Odpowiednik „strict” dla YAML-i (kube-linter albo podobny), na manifestach z `argocd/manifests/`
i wyrenderowanych chartach projektów: limity pamięci, `runAsNonRoot`, brak trybu
uprzywilejowanego, sondy zdrowia, przypięte obrazy. Część wyjątków będzie uzasadniona (np.
provisioner `nas` potrzebuje dostępu do ścieżek hosta) — zapisywane przy manifeście, nie globalnie.

---

## Szczelność reguł — lekcje z automat-operat i solid-app-tpl (4.10.2026)

**Status:** w większości zrobione 4.10.2026. Zasada z `automat-operat` i szablonu `solid-app-tpl`
— „nowy element jest objęty regułami od pierwszego pliku” — tutaj:

- ~~Kompletność par projekt ↔ aplikacja~~ — reguła 8 w `repo-rules.sh`: Application bez
  `scripts/projects/…` i katalog projektu bez żadnej Application oblewają bramkę.
- ~~`.gitignore`: pliki kluczy także poza `.secrets/`~~ — `*.pem`, `*.key`, `*.p12`, `id_rsa*`,
  `id_ed25519*`.
- Przy okazji: `.editorconfig` (LF, UTF-8, wcięcia jak shfmt) i `.gitattributes` (LF w każdym
  checkoucie, zaszyfrowany stan bez diffu tekstowego, lockfile'y jako wygenerowane).
- **Zostaje: smoke test w chartach projektów.** Platforma traktuje zieloną synchronizację w Argo
  jako „wdrożone i działa”, a to prawda tylko wtedy, gdy chart ma Job PostSync
  (`templates/smoke-test.yaml`). Wymaga pobrania charta projektu — razem z punktem „Parametry
  projektów względem ich chartów” wyżej (ten sam pobrany chart); brak Joba = błąd.
- shellcheck — nic do zrobienia (obejmuje wszystkie śledzone `*.sh` i `.githooks/*`); walidacja
  `compose.yaml` nie dotyczy — platforma nie ma stosu compose.

---

## Limit zapytań dla publicznych aplikacji (grzyby)

**Status:** zapisane 4.10.2026. `grzyby.gugnowski.com` jest publiczne (`public = true` w
`terraform/edge/edge.auto.tfvars`) i broni się tylko kluczem w `/mcp`. Klucz zatrzymuje obcych,
ale nie zalew zapytań z błędnym kluczem (każde trafia do klastra i dostaje 401). Darmowy plan
Cloudflare ma jedną regułę rate limiting — w `terraform/edge` jako
`cloudflare_ruleset` (phase `http_ratelimit`) dla hostów z `public = true`, np. 60 zapytań/min
z jednego IP na `/mcp`. Robić, gdy adres zacznie krążyć poza właścicielem.

---

## NetworkPolicy: kto może się łączyć z czym

**Status:** zapisane.

Dziś każdy pod w klastrze może połączyć się z każdym. Dla bazy to za dużo: do `postgres`
powinny mieć dostęp tylko namespace'y projektów, które mają w niej bazę, i operator
CloudNativePG (`cnpg-system`). k3s egzekwuje NetworkPolicy od ręki. Zacząć od bazy; potem
ewentualnie „domyślnie nic” w namespace'ach projektów z wyjątkami (Traefik → web, web → server,
server → baza, server → Gotenberg).

---

## Próba odtworzenia środowiska od zera

**Status:** zapisane; wymaga drugiej maszyny albo okna przestoju — dziś nie do zrobienia.

Cel: dowód, że z repo, sekretów (`.secrets/`, hasło stanu) i kopii zapasowych da się postawić
wszystko na czystym sprzęcie — i spisana instrukcja awaryjna. Wychodzą przy tym rzeczy „zrobione
kiedyś ręcznie”.

**Dlaczego to nie jest proste:** środowisko stoi na OpenMediaVault na tym samym serwerze — od
niego zależy dysk z bazą (`docs/nas.md`). OMV i jego konfiguracja nie są opisane kodem (osobny
punkt „OpenMediaVault opisany kodem”), a dobrego providera Terraform dla OMV nie ma: maszynę da
się zaimportować do Terraformu, ale ustawienia w środku (udziały, NFS, SMB) wymagałyby Ansible
albo skryptu `omv-rpc`. Do tego dysk `nas` żyje razem z maszyną k3s — postawienie jej od nowa
na tym samym serwerze usuwa dane bazy, więc bez kopii poza domem (etap 6 planu draftów) próba
jest niebezpieczna.

Kolejność, gdy przyjdzie czas: kopie poza domem → OMV opisany kodem → próba na drugiej maszynie
(albo w zaplanowanym oknie: odtworzenie samej maszyny k3s i bazy z kopii).

---

## Menedżer haseł: Bitwarden

**Status:** do zrobienia przez właściciela, poza repo — ale repo od tego zależy.

Część rzeczy potrzebnych do odtworzenia środowiska istnieje dziś tylko na tym laptopie albo
w notatkach otwartym tekstem. Bez kopii w menedżerze haseł utrata laptopa zabiera je na zawsze:

- **`STATE_PASSPHRASE`** z `.secrets/platform.env` — bez niego zaszyfrowany stan Terraformu
  w gicie jest bezużyteczny. **Najpilniejsze.**
- reszta `.secrets/*.env`: token API Proxmoksa, token Cloudflare, token GHCR projektów, listy
  maili grup Access;
- hasła OpenMediaVault (panel, root, SMB) — dziś w notatce otwartym tekstem i jedno hasło do
  wszystkiego; przy okazji: zmienić na osobne, mocne;
- kody odzyskiwania kont: GitHub, Cloudflare, Google (logowanie do automatu), Backblaze/Hetzner
  (gdy dojdą kopie zapasowe).

**Uwaga:** Bitwarden w chmurze, nie samodzielnie hostowany (Vaultwarden) na tym serwerze —
menedżer haseł, który pada razem z homelabem, nie pomoże go odtworzyć.

**Zrobione w repo:** `just secrets backup` wrzuca każdy `.secrets/*.env` do Bitwardena (folder
Homelab, notatka `suwalski-platform/.secrets/<plik>`), `just secrets restore` sprowadza je na
nowej maszynie. Zostaje po stronie właściciela: `bw config server https://vault.bitwarden.eu`,
`bw login`, pierwszy `just secrets backup` i sprawdzian niżej.

---

## Nowe, osobne hasła OpenMediaVault

**Status:** do zrobienia przez właściciela (po założeniu Bitwardena — punkt wyżej).

Dziś panel OMV, konto `root` i użytkownik SMB `maniumek` mają **jedno wspólne hasło**, zapisane
otwartym tekstem w notatce (i wklejone kiedyś do rozmowy z agentem). Zmiana na trzy osobne,
wygenerowane w Bitwardenie (generator → „Password”, 24 znaki):

1. W sejfie trzy wpisy: *OMV panel (admin)*, *OMV root (konsola)*, *OMV SMB (maniumek)*;
   pole URL: `http://192.168.0.197`.
2. Zmiana w OMV: panel → *User settings* (admin) i *Users* (maniumek — to hasło SMB);
   `root` przez konsolę (`passwd`).
3. **Hasło SMB jest też na Proxmoksie:** `/etc/nas-credentials` (montowanie
   `/mnt/nas-maniumek` dla Jellyfina). Po zmianie: nowe hasło w tym pliku, potem
   `umount /mnt/nas-maniumek && mount /mnt/nas-maniumek` i sprawdzenie, że Jellyfin widzi filmy.
   Agent może to zrobić — wystarczy powiedzieć.
4. Inne miejsca, które łączą się po SMB jako `maniumek` (laptop, telefon) — zaktualizować.
5. Usunąć starą notatkę z hasłami otwartym tekstem.

---

## Kody odzyskiwania kont i sprawdzian sejfu

**Status:** do zrobienia przez właściciela (po założeniu Bitwardena i przeniesieniu sekretów).

### Kody odzyskiwania

Każde konto z 2FA ma kody na wypadek utraty telefonu. W Bitwardenie jako *Secure Note*, po jednej
na konto:

- **GitHub** (repo, obrazy, CI): Settings → Password and authentication → Recovery codes.
- **Cloudflare** (domena, tunel, logowanie do automatu): My Profile → Authentication → Backup codes.
- **Google** (konto, przez które idą kody logowania): myaccount.google.com →
  Security → Backup codes.
- **Proxmox:** hasło roota hosta (web UI) — jeśli nie ma go jeszcze nigdzie poza głową.

### Sprawdzian

1. Wylogować się z sejfu na laptopie i zalogować z **kartki awaryjnej** (hasło główne + kod
   z aplikacji 2FA). Działa = kartka jest dobra.
2. Na telefonie znaleźć „hasło stanu Terraform” — to ono jest najważniejsze.
3. Dać znać agentowi: odhaczy punkt „Menedżer haseł: Bitwarden” i dopisze do README, gdzie
   szukać sekretów przy odtwarzaniu środowiska.
