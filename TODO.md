# TODO

Tylko to, co jeszcze trzeba zrobić — od najcenniejszego. Tło, analizy i pomysły bez decyzji leżą w `docs/`
(linki przy zadaniach); zrobione rzeczy znika stąd, a historię trzyma git.

## grzyby: wdrożyć chart z master

**Co:** `grzyby.yaml` jest jedynym projektem na `targetRevision: master` (z komentarzem `# unpinned:`):
chart na master różni się od charta commita z `image.tag` (`liveCheck.schedule` przesunięty na 10:17).
Decyzja właściciela; po niej `just argo deploy grzyby` przypina chart i obraz, a komentarz znika.

## Zabezpieczenie sekretów i kont (właściciel, poza repo)

**Co:** część rzeczy potrzebnych do odtworzenia środowiska istnieje dziś tylko na laptopie albo w notatce
otwartym tekstem. Repo ma już `just secrets backup|restore` (kopia `.secrets/` w Bitwardenie, folder
Homelab); po stronie właściciela zostaje:

- `bw config server https://vault.bitwarden.eu`, `bw login`, pierwszy `just secrets backup` — i sprawdzian:
  wylogować się z sejfu na laptopie i zalogować z **kartki awaryjnej**, na telefonie znaleźć
  „`STATE_PASSPHRASE`” (bez niego zaszyfrowany stan Terraforma w gicie jest bezużyteczny — najpilniejsze);
- **kody odzyskiwania** w sejfie, po *Secure Note* na konto: GitHub, Cloudflare, Google (kody logowania do
  automatu), hasło roota Proxmoksa; Backblaze/Hetzner, gdy dojdą kopie zapasowe;
- **osobne hasła OpenMediaVault:** panel (admin), `root` (konsola) i użytkownik SMB `maniumek` mają dziś jedno
  wspólne hasło w notatce otwartym tekstem. Trzy wygenerowane w Bitwardenie (24 znaki); zmiana w OMV (panel →
  *User settings* i *Users*, `root` przez `passwd`); **hasło SMB jest też na Proxmoksie** w
  `/etc/nas-credentials` — nowe hasło tam, potem `umount /mnt/nas-maniumek && mount /mnt/nas-maniumek` i
  sprawdzenie, że Jellyfin widzi filmy (agent może to zrobić na prośbę); zaktualizować laptop i telefon;
  usunąć starą notatkę.

**Dlaczego:** utrata laptopa bez kopii zabiera te rzeczy na zawsze. Bitwarden w chmurze, nie samodzielnie
hostowany (Vaultwarden) — menedżer haseł, który pada razem z homelabem, nie pomoże go odtworzyć. Po
sprawdzianie dopisać do README, gdzie szukać sekretów przy odtwarzaniu.

## OpenMediaVault: rezerwacja adresu w routerze

**Co:** `192.168.0.197` jest ustawiony na sztywno w OMV; zarezerwować go w routerze (MAC
`BC:24:11:A7:C0:09`) albo wyjąć z puli DHCP. **Dlaczego:** router mógłby dać ten adres komuś innemu, a od
niego zależy dysk z bazą maszyny k3s. Tło: [`docs/omv-w-kodzie.md`](docs/omv-w-kodzie.md).

## Dostęp do klastra spoza domu

**Co:** naprawić router podsieci Tailscale (węzeł `tailscale`, `100.68.171.53`, rozgłasza `192.168.0.0/24`,
ale nic za nim nie odpowiada) i opisać go kodem: gdzie stoi, `ip_forward` na stałe, `--advertise-routes`.
Sprawdzian: z obcej sieci `just argo apps` i `kubectl get nodes`. **Dlaczego:** poza domem klaster jest
nieosiągalny. **Decyzja otwarta:** czy dodatkowo przenieść dom na nietypową podsieć (tańsza połowa wystarczy,
dopóki obca sieć ma inną adresację). Analiza i lista miejsc z adresami:
[`docs/siec-domowa-tailscale.md`](docs/siec-domowa-tailscale.md).

## NetworkPolicy: kto może się łączyć z czym

**Co:** dziś każdy pod może połączyć się z każdym. Zacząć od bazy: do `postgres` tylko namespace'y projektów,
które mają w niej bazę, i operator CloudNativePG (`cnpg-system`); k3s egzekwuje NetworkPolicy od ręki.
Potem ewentualnie „domyślnie nic” w namespace'ach projektów z wyjątkami (Traefik → web, web → server,
server → baza, server → Gotenberg). **Dlaczego:** baza jest wspólna dla wszystkich projektów.

## Smoke test w każdym chartcie projektu

**Co:** `suwalski-investing-tools` nie ma `templates/smoke-test.yaml` (pozostałe cztery mają). Dopisać go
w repo projektu, a w bramce regułę: chart projektu bez Joba PostSync = błąd (chart jest już pobierany i
renderowany przez `.just/lib/chart-check.sh`). **Dlaczego:** zielona synchronizacja w Argo znaczy „wdrożone i
działa” tylko wtedy, gdy chart ma ten Job.

## Lint bezpieczeństwa i niezawodności manifestów

**Co:** odpowiednik „strict” dla YAML-i (kube-linter albo podobny) na `argocd/manifests/` i wyrenderowanych
chartach projektów: limity pamięci, `runAsNonRoot`, brak trybu uprzywilejowanego, sondy zdrowia, przypięte
obrazy. **Decyzja otwarta:** wyjątki (np. provisioner `nas` potrzebuje ścieżek hosta, tailscale jest
`privileged`) zapisywać przy manifeście, nie globalnie.

## Martwy kod i „kto czego dotyka” w `repo-rules.sh`

**Co:** dziś nic nie jest martwe (sprawdzone 17.10.2026: każda funkcja `lib.sh`, skrypt `.just/lib/` i wyjście
Terraforma jest używane), ale nic też tego nie pilnuje. Reguły do dopisania:

- funkcje w `scripts/.internal/lib.sh`, których nikt nie woła; skrypty w `.just/lib/` bez odwołania z recepty
  lub workflow; wyjścia Terraforma, których nic nie czyta;
- klucze w `.secrets/*.env`, których żaden `setup.sh` nie czyta — tylko lokalnie (pliki poza gitem), jako
  ostrzeżenie w `just check live`;
- `scripts/projects/<projekt>/…` pisze tylko do swojego `.secrets/<projekt>[-<środowisko>].env` i swoich grup
  Access; recepty `.just/*.just` wołają tylko `.just/lib/`; warstwy Terraforma nie czytają nawzajem swojego
  stanu (`terraform_remote_state`).

**Dlaczego:** odpowiednik knip i kontraktów importów z `automat-operat`; tu nie ma modułów importujących się
nawzajem, więc zostają te reguły. Niski priorytet.

## Kopie zapasowe poza domem

**Co:** kopia bazy (dysk `nas`) poza domem; dziś dane żyją tylko na serwerze. **Dlaczego:** warunek bezpiecznej
próby odtworzenia od zera i ochrona przed utratą serwera. W planie draftów `automat-operat` jako etap 6.
**Decyzja otwarta:** gdzie (Backblaze/Hetzner były wymieniane przy kodach odzyskiwania). Tło:
[`docs/omv-w-kodzie.md`](docs/omv-w-kodzie.md).

## OpenMediaVault opisany kodem

**Co:** import VM 113 do Terraforma (`1 to import, 0 to change, 0 to destroy` albo stop) i kopia konfiguracji
OMV poza serwerem; ustawienia wewnątrz OMV — Ansible, skrypt `omv-rpc` albo ręcznie z kopią. **Dlaczego:** NAS
jest jedynym elementem hypervisora, od którego zależy klaster, a nie ma go w kodzie. **Decyzje otwarte:**
Ansible czy skrypt; NFS zamiast SMB na hoście dla Jellyfina. Plan krok po kroku:
[`docs/omv-w-kodzie.md`](docs/omv-w-kodzie.md).

## Próba odtworzenia środowiska od zera

**Co:** dowód, że z repo, sekretów i kopii da się postawić wszystko na czystym sprzęcie, plus spisana instrukcja
awaryjna. **Dlaczego:** wychodzą przy tym rzeczy „zrobione kiedyś ręcznie”. Zablokowane: wymaga drugiej maszyny
albo okna przestoju, a najpierw kopii poza domem i OMV w kodzie (dwa punkty wyżej).

## Reszta Proxmoksa jako kod: sieć, VLAN, DNS

**Co:** osobny mostek/VLAN dla maszyn zarządzanych kodem (dziś klaster siedzi w `192.168.0.0/24` obok telewizora
i telefonów), DNS opisany kodem w `terraform/dns/`, ewentualnie odejście od AdGuarda. **Dlaczego:** granica
między klastrem a domowymi urządzeniami. **Decyzje otwarte:** czy provider ma zasoby na mostki i VLAN-y;
czy AdGuard ma API nadające się do Terraforma. Ustalenia i ostrzeżenia (import, nie postawienie od nowa):
[`docs/proxmox-jako-kod.md`](docs/proxmox-jako-kod.md).

## Środowisko cdev w GCP

**Co:** po próbnym wdrożeniu automat-operat na k3s w GCP — decyzja, czy zostajemy w GCP i które elementy
zastąpić usługami GCP (IAP, Cloud SQL z IAM, Artifact Registry, Secret Manager, GKE Autopilot, Workload Identity).
**Decyzja otwarta:** czy Argo CD zostaje w domu. Tabela kandydatów z kosztami: [`docs/gcp-cdev.md`](docs/gcp-cdev.md).

## Pomysły bez decyzji

Sekrety w gicie (SOPS + age), lista aplikacji na stronie startowej z Ingressów, przyszłość AdGuarda:
[`docs/pomysly.md`](docs/pomysly.md).
