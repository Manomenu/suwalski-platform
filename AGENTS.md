# suwalski-platform

Środowisko, na które deployuję. Proxmox udaje dostawcę chmury; wszystko, co w nim stoi,
jest opisane kodem. To repo **decyduje, co biegnie** — obrazy publikują
repozytoria projektów (`suwalski-investing-tools`, `automat-operat`).

## Układ

```
terraform/
  cluster/          maszyna na Proxmoksie + k3s          (osobna konfiguracja główna)
    templates/      szablony cloud-init
  platform/         Argo CD + aplikacja korzeniowa        (osobna konfiguracja główna)
  edge/             Cloudflare: tunel, DNS, Access        (osobna konfiguracja główna)
argocd/
  apps/platform/    Application'y wspólne dla klastra (cloudflared)
  apps/projects/    Application'y projektów — po pliku na projekt i środowisko
  manifests/        manifesty elementów platformy bez własnego repo
justfile            tylko lista modułów
.just/
  <moduł>.just      recepty: cluster · platform · edge · argo · k9s
  lib/              bash, którego recepty używają — nie wołać z ręki
scripts/            tylko to, czego just nie zrobi: source do powłoki i sekrety
  setup.sh          platforma: just + sekrety wspólne dla klastra
  projects/         sekrety projektów: <projekt>/[<środowisko>/]setup.sh
  .internal/        kroki i wspólne funkcje skryptów (lib.sh) — nie wołać z ręki
.secrets/           źródła sekretów, po pliku na zakres — poza gitem
docs/               decyzje, które nie mieszczą się w komentarzu
  edge/guide/       przewodnik po warstwie edge — czytać od edge-0.md
```

### just i scripts/

Codzienne polecenia to `just <moduł> <polecenie>`. Nowe polecenie dopisujesz jako receptę
w `.just/<moduł>.just` z `[doc]` (i `[group]`, gdy moduł ma ich kilka); dłuższy bash
trafia do `.just/lib/`, a recepta go woła. Nowa warstwa Terraforma = nowy moduł
+ `mod` z `[doc]`/`[group('layers')]` w głównym `justfile`.

Do `scripts/` trafia wyłącznie to, czego recepta just zrobić nie może: zmiana bieżącej
powłoki (musi być `source`) i `setup.sh` — jedyny punkt wejścia na świeżej maszynie.
Jego kroki (instalacja just itd.) leżą w `scripts/.internal/` i nie są osobnymi
poleceniami: nowy krok przygotowania dopisujesz tam i wołasz z `setup.sh`.

**Sekrety dzielą się według właściciela.** `scripts/setup.sh` zna wyłącznie platformę
(Proxmox, Cloudflare, grupa `admin`, token tunelu). Wszystko, co należy do projektu —
kto może wejść na jego adres, hasła aplikacji — ma skrypt w
`scripts/projects/<projekt>/[<środowisko>/]setup.sh` i własny plik w `.secrets/`. Każdy
skrypt czyta i pisze tylko swoje; wspólne funkcje są w `scripts/.internal/lib.sh`.

## Warstwy wartości

Trzy miejsca, każde z inną odpowiedzialnością. Dopisując zmienną, zdecyduj, gdzie należy.

| Gdzie | Co tam trafia | W gicie? |
| --- | --- | --- |
| `default` w `variables.tf` | Decyzje projektowe — takie same w każdym środowisku: wersja k3s, rozmiar maszyny, obraz systemu. | tak |
| `proxmox.auto.tfvars` | Fakty o tej instalacji: adresy, nazwa węzła, storage, mostek, IP. | **tak** |
| `secrets.auto.tfvars` | Token API i klucze publiczne. | nie |

Zmienna zależna od środowiska **nie dostaje `default`**. Wtedy skopiowanie repo na inny
Proxmox kończy się czytelnym błędem zamiast cichej próby postawienia maszyny na
nieistniejącym węźle.

Końcówka `.auto.tfvars` powoduje automatyczne wczytanie — bez `-var-file` przy każdym
poleceniu. Zapomniana flaga to najczęstszy sposób, w jaki ludzie stawiają coś
z domyślnymi wartościami zamiast z własnymi.

## Kiedy wydzielać moduł

**Domyślnie nie wydzielamy.** Dzisiejsza konfiguracja to trzy zasoby użyte raz — moduł
dołożyłby warstwę pośrednictwa i zero wartości. HashiCorp wprost pisze, że główna
konfiguracja bez podmodułów jest w porządku przy małych wdrożeniach.

Moduł zarabia na siebie, gdy zachodzi **choć jedno**:

- ten sam kształt powstaje **więcej niż raz** — drugi węzeł, drugie środowisko, drugi
  klaster, i różnice sprowadzają się do wartości;
- kawałek chcesz **wersjonować osobno** od reszty (własne repo, tagi, `source = "git::...?ref=v1.2.0"`);
- kawałek chcesz **testować w oderwaniu** od całości.

Praktyczna wersja tej reguły: *moduł piszesz w momencie, w którym inaczej zrobiłbyś
kopiuj-wklej.* Nie wcześniej.

Czego unikać:

- **modułu-opakowania** — takiego, który przyjmuje pięć zmiennych i przekazuje je do
  jednego zasobu. To sam koszt czytania, bez zysku;
- **bloków `provider` wewnątrz modułu**. Provider konfiguruje się w konfiguracji głównej,
  a moduł go dziedziczy. Provider w module uniemożliwia potem sensowne użycie go dwa razy
  i blokuje `tofu destroy` przy usuwaniu.

Gdy już wydzielasz: moduł ma taki sam układ plików co główna konfiguracja
(`main.tf`, `variables.tf`, `outputs.tf`) i leży w `terraform/modules/<nazwa>/`.

## Kiedy dzielić pliki

Terraform czyta wszystkie `.tf` w katalogu jako jeden, więc podział jest wyłącznie dla
ludzi. Zostajemy przy konwencji, której szukają recenzenci i narzędzia:

- `main.tf` — zasoby. Dzielimy dopiero, gdy rośnie: wtedy po dziedzinach
  (`network.tf`, `compute.tf`), nie po alfabecie;
- `variables.tf` — jeden plik. Dzieli się przy kilkudziesięciu zmiennych
  (`variables-network.tf`), nie przy dwudziestu z komentarzami sekcyjnymi;
- `outputs.tf`, `versions.tf`, `providers.tf` — po jednym.

## Więcej niż jedno środowisko

**Dziś mamy jedno i nic nie implementujemy.** Gdy pojawi się drugie — inny Proxmox,
maszyna u dostawcy, osobny klaster testowy — regułę postępowania i porównanie trzech
podejść opisuje [`docs/multiple_env.md`](docs/multiple_env.md). Zajrzyj tam **zanim**
zaczniesz cokolwiek kopiować, bo wybór podejścia decyduje o tym, czy wydzielamy moduł.

## Zasady

- **Commity robi wyłącznie właściciel repo.** Agent nie robi `commit`, `--amend`, `reset`,
  `rebase` ani `push` — zostawia zmiany w drzewie roboczym do przejrzenia, nawet gdy są
  skończone i sprawdzone.
- **Nie klikaj w interfejsie Proxmoksa.** Zmiana zrobiona ręcznie zniknie przy najbliższym
  `apply`, a do tego czasu kod będzie kłamał o stanie środowiska.
- **Wersje są przypięte** — k3s, provider, obraz systemu. Środowisko odtwarzalne bije
  środowisko zawsze najnowsze.
- **`.terraform.lock.hcl` commitujemy**, `*.tfstate` nie. Lockfile jest kontrolowany
  ręcznie; stan jest generowany i opisuje żywą infrastrukturę.
- **Każda Application projektu (`argocd/apps/projects/`) ma finalizer**
  `resources-finalizer.argocd.argoproj.io` w `metadata.finalizers`. Root app prunuje
  Application, której pliku już nie ma w gicie — ale bez finalizera Argo usuwa sam obiekt
  Application, a deploymenty, Ingressy i Secrety projektu zostają w klastrze, osierocone
  i dalej działające (tak zostało `witkowska-dev` po zmianie nazwy). Z finalizerem
  usunięcie lub przemianowanie pliku sprząta całe wdrożenie. Wyjątek: zasoby z adnotacją
  `argocd.argoproj.io/sync-options: Delete=false` (np. PVC z danymi) przeżywają celowo.
- **Kod po angielsku, dokumentacja po polsku.** Identyfikatory, komentarze i komunikaty
  w skryptach, receptach just i konfiguracji (`.tf`, `.tfvars`, `.yaml`) piszemy po
  angielsku; dokumentacja w Markdownie — po polsku. Nie tłumaczymy wartości, które trafiają
  do infrastruktury (nazwy reguł Access, opisy zasobów, szablon cloud-init): ich zmiana to
  zmiana zasobu.
- **Przed `apply` zawsze `plan`.** Cokolwiek w kolumnie „destroy", czego się nie
  spodziewałeś, jest powodem, żeby się zatrzymać.
