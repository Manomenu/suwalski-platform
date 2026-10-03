# TODO

Rzeczy do przemyślenia, nie do zrobienia od ręki. Każda dostaje własną sesję — tutaj
zapisujemy tylko, o co chodziło i dlaczego, żeby pomysł nie zginął.

---

## Sekrety bez ręcznego zarządzania

**Status:** zapisane. Obecne rozwiązanie jest **świadomie przejściowe**.

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
