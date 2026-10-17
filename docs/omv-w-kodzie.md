# OpenMediaVault opisany kodem — i odtwarzanie od zera

Zapisane. Zadania są w [`TODO.md`](../TODO.md) („OpenMediaVault: stały adres i opis kodem”, „Kopie
zapasowe poza domem”, „Próba odtworzenia środowiska od zera”). To, co dla klasy storage „nas” już zrobiono,
opisuje [`nas.md`](nas.md).

Dziś OMV (VM 113) i jego ustawienia są klikane albo wołane ręcznie przez `omv-rpc`. Cel: odtworzenie NAS-a
z repo, tak jak maszyny k3s.

## Adres OMV

Stały adres `192.168.0.197` ustawiony w OMV 2.10.2026 (wcześniej OMV brał adres z DHCP; wcześniejsza notatka
mówiła `.198`, więc adres już się kiedyś zmienił). Od tego adresu zależą:

- magazyn Proxmoksa `nas` (`nas_server` w `terraform/cluster/proxmox.auto.tfvars`) — czyli **dysk z bazą**
  maszyny k3s;
- montowanie SMB na hoście Proxmoksa (`/etc/fstab` → `/mnt/nas-maniumek`) — czyli Jellyfin;
- każde ręczne połączenie po SMB z laptopa.

**Przyjęty standard w tym repo:** usługi, od których coś zależy, mają **stały adres**. Maszyna k3s dostaje go
w Terraformie (`vm_ip`, przez cloud-init). Dla OMV są dwie poprawne drogi:

| Droga | Jak | Uwagi |
| --- | --- | --- |
| **Rezerwacja DHCP w routerze** | adres na sztywno dla MAC `BC:24:11:A7:C0:09` (karta VM 113) | nic nie zmienia w OMV; router zostaje jedynym źródłem adresów; ręcznie w routerze |
| **Stały adres w OMV** | Network → ens18 → static `192.168.0.197/24`, brama `.1`, DNS | wybrany adres musi być spoza puli DHCP routera, żeby nie było kolizji |

Wybrano stały adres w OMV; zostaje zarezerwować go w routerze (albo wyjąć z puli DHCP).

Do tego **nazwa zamiast adresu**: wpis w AdGuardzie (np. `nas.suwalski.internal` → `192.168.0.197`). Wtedy SMB
z laptopa i `nas_server` w Terraformie używają nazwy, a zmiana adresu to jedna poprawka w DNS. Uwaga: Proxmox
musi umieć tę nazwę rozwiązać (DNS hosta wskazuje na AdGuarda albo wpis w `/etc/hosts`).

## Właściwe zadanie: OMV w kodzie, bez utraty danych

Dwie różne rzeczy, dwa narzędzia — Terraform opisuje **maszyny**, a konfigurację **wewnątrz** systemu opisuje
narzędzie do konfiguracji (Ansible) albo skrypt.

1. **Maszyna VM 113 w Terraformie** — przez `import` (blok `import` w OpenTofu), nie przez tworzenie od nowa.
   Import niczego nie zmienia na serwerze: dopisuje istniejącą maszynę do stanu. Kolejność bezpieczna dla
   danych:
   - napisać zasób tak, by odpowiadał obecnej konfiguracji (`qm config 113`), w tym `hostpci0` (kontroler SATA
     z dyskami RAID), `startup order=1,up=60`, `onboot`;
   - `tofu plan` ma pokazać **„1 to import, 0 to change, 0 to destroy”** — dopiero wtedy `apply`. Cokolwiek
     w „replace/destroy” = stop;
   - dyski danych (SSD w RAID1) **nie są dyskami Proxmoksa** — są na przekazanym kontrolerze, więc Terraform
     ich nie zna i nie może ich skasować. Ryzyko dotyczy tylko dysku systemowego OMV (20 GB na `local-lvm`) —
     przed importem kopia (`vzdump 113`) i eksport konfiguracji OMV (Backup / `omv-confdbadm`).
2. **Ustawienia OMV** (foldery współdzielone, NFS, SMB, użytkownicy, sieć) — dojrzałego providera Terraform
   dla OMV nie ma. Kandydaci:
   - **Ansible** z modułami/`omv-rpc` — idempotentne, czytelne, standard dla „konfiguracji wewnątrz
     maszyny”; dochodzi nowe narzędzie;
   - **skrypt `omv-rpc` w `.just/lib/`** (jak `nas-disk.sh`) — bez nowych narzędzi, ale idempotentność trzeba
     pilnować samemu;
   - zostawić ręcznie, ale **kopię konfiguracji OMV** trzymać poza serwerem i opis w `nas.md` aktualny.
   Macierz RAID i system plików btrfs zostają ręczne w każdym wariancie — ich odtworzenie „z kodu” to
   formatowanie dysków z danymi.

Do rozstrzygnięcia:

- rezerwacja w routerze czy stały adres w OMV (i czy router ma API, żeby to też było kodem);
- Ansible czy skrypt — zależy, ile jeszcze maszyn poza k3s dojdzie (AdGuard, Jellyfin, tailscale też są dziś
  klikane);
- czy przy okazji przejść z montowania SMB na hoście (Jellyfin) na NFS — stabilniejsze dla Linuxa niż
  `cifs ... soft`.

## Próba odtworzenia środowiska od zera

Wymaga drugiej maszyny albo okna przestoju — dziś nie do zrobienia.

Cel: dowód, że z repo, sekretów (`.secrets/`, hasło stanu) i kopii zapasowych da się postawić wszystko na
czystym sprzęcie — i spisana instrukcja awaryjna. Wychodzą przy tym rzeczy „zrobione kiedyś ręcznie”.

**Dlaczego to nie jest proste:** środowisko stoi na OpenMediaVault na tym samym serwerze — od niego zależy
dysk z bazą ([`nas.md`](nas.md)). OMV i jego konfiguracja nie są opisane kodem (sekcje wyżej), a dobrego
providera Terraform dla OMV nie ma. Do tego dysk `nas` żyje razem z maszyną k3s — postawienie jej od nowa na
tym samym serwerze usuwa dane bazy, więc bez kopii poza domem (etap 6 planu draftów w automat-operat) próba
jest niebezpieczna.

Kolejność, gdy przyjdzie czas: kopie poza domem → OMV opisany kodem → próba na drugiej maszynie (albo
w zaplanowanym oknie: odtworzenie samej maszyny k3s i bazy z kopii).
