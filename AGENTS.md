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
  apps/platform/    Application'y wspólne dla klastra: <element>.yaml (cloudflared, nas-storage, cloudnative-pg, postgres, tailscale, traggo)
  apps/projects/    Application'y projektów — po pliku na projekt i środowisko
  manifests/        manifesty elementów platformy: <element>/ — para z apps/platform/<element>.yaml
                    (m.in. gatus/ — alerty, homepage/ — strona startowa hub.k8s.suwalski.internal)
justfile            tylko lista modułów
.just/
  <moduł>.just      recepty: cluster · platform · edge · check · argo
  lib/              bash, którego recepty używają (też bramka: check.sh, repo-rules.sh) — nie wołać z ręki
.github/workflows/  CI: check.yml odpala `just check` przy każdym pushu
.tflint.hcl         reguły tflint dla wszystkich warstw
.editorconfig       kodowanie, LF, wcięcia (bash 4, jak shfmt) — edytor robi to samo co bramka
.gitattributes      LF w każdym checkoucie; zaszyfrowany stan bez diffu tekstowego
.vscode/            edytor robi to, co bramka: shfmt/shellcheck z jej flagami, schemat Kubernetesa, zagnieżdżanie plików
.yamllint.yaml      reguły yamllint dla argocd/ i .github/
scripts/            tylko to, czego just nie zrobi: source do powłoki i sekrety
  setup.sh          platforma: just + sekrety wspólne dla klastra
  projects/         sekrety projektów: <projekt>/[<środowisko>/]setup.sh
  .internal/        kroki i wspólne funkcje skryptów (lib.sh) — nie wołać z ręki
.secrets/           źródła sekretów, po pliku na zakres — poza gitem
docs/               decyzje i tło, które nie mieszczą się w komentarzu: nas, multiple_env, cheatsheet,
                    siec-domowa-tailscale, omv-w-kodzie, proxmox-jako-kod, gcp-cdev, pomysly
                    (TODO.md trzyma tylko to, co jeszcze do zrobienia — i linkuje tu po tło)
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

**Kopia `.secrets/` żyje w Bitwardenie** (`just secrets backup` / `restore`, po notatce na plik
`*.env`). Źródłem prawdy pozostaje `.secrets/` — skrypty `setup.sh` niczego z Bitwardena nie
czytają. Klucz deploy (`deploy-key`) celowo nie jedzie: zgubiony generuje się na nowo.
Wartości nie trafiają na ekran ani do argumentów poleceń — tylko przez potoki i pliki.

**Nowa zmienna — po kolei:**

1. **Czy to w ogóle sekret?** Adres, nazwa, port, lista domen — nie. Taka wartość idzie jawnie:
   do `values.yaml` charta, ConfigMapy albo `*.tfvars` w gicie. Sekret to coś, co daje dostęp
   (hasło, token, klucz) albo dane osobowe (maile grup Access).
2. **Czyj?** Platformy → `scripts/setup.sh` i `.secrets/platform.env`. Projektu →
   `scripts/projects/<projekt>/[<środowisko>/]setup.sh` i jego plik w `.secrets/`. Nowy plik
   w `.secrets/` ma rozszerzenie `.env` — inaczej backup go pominie.
3. **Wpisany raz, ręcznie, przez `ask`** (z `scripts/.internal/lib.sh`, sekret z `silent`),
   zapisany przez `save_source`. Wartość, którą da się wygenerować, dostaje propozycję
   (`openssl rand …`) jako domyślną. Wszystko dalej — `secrets.auto.tfvars`, Secret w klastrze —
   skrypt wylicza z `.secrets/`; tych kopii nikt nie edytuje.
4. **Zakończ zmianę zdaniem do właściciela:** „uruchom `<setup.sh>`, potem
   `just secrets backup`”. Agent nie loguje się do Bitwardena i nie odpala backupu sam.
5. Sekret, który **łatwiej odtworzyć niż przechować** (klucz deploy, token do wygenerowania
   jednym kliknięciem), może leżeć poza `*.env` — ale wtedy opisz w skrypcie, jak go odtworzyć.

**Nowy projekt — po kolei:** (`<p>` — nazwa projektu, `<p>[-<env>]` — z środowiskiem, gdy jest ich kilka;
wzór: `suwageval`, z bazą i własnym kanałem; z bazą, bez kanału alertów: `suwalski-investing-tools`; bez bazy i kanału: `pomiary`.)

1. **Application** — `argocd/apps/projects/<p>[-<env>].yaml` ze wzoru najbliższego projektu: finalizer,
   `repoURL`, parametry charta, `destination.namespace`; `targetRevision: master` i `image.tag: sha-0000000`
   to tylko miejsca na wartości — wpisuje je `just argo deploy <p>[-<env>]` (pełny SHA i `sha-` + jego początek).
   Bramka sprawdza za ciebie: finalizer, parę SHA↔tag, każdy parametr w `values.yaml` charta i render
   (`chart-check.sh`).
2. **Sekrety projektu** — `scripts/projects/<p>/[<env>/]setup.sh` (`chmod +x`, `set -euo pipefail`; nazwa
   katalogu = nazwa pliku Application bez `-<env>`), po wzorze `suwageval/setup.sh`: `ask` → `save_source`
   → `secret` / `registry_secret` w klastrze. Własny plik `.secrets/<p>[-<env>].env` powstaje sam.
3. **Baza (opcjonalnie, gdy projekt jej potrzebuje)** — trzy miejsca naraz, które muszą się zgadzać
   (reguła 12 w `repo-rules.sh`): rola w `argocd/manifests/postgres/cluster.yaml` (`managed.roles`,
   `passwordSecret.name` = rola z myślnikami), `Database` w `databases.yaml` (`name` = `owner` = rola)
   i `database_access "$NAMESPACE" <rola> [npgsql]` w `setup.sh`. Aplikacja .NET dostaje connection string
   Npgsql (`npgsql`); inny format = nowy przypadek w `database_access` w `scripts/.internal/lib.sh`.
4. **Własny kanał Discorda (opcjonalnie; bez niego alerty idą do `#suw-platf-notif`)** — nazwa kanału
   w `discord_channels` w `terraform/platform/notifications.tf`, adnotacje
   `notifications.argoproj.io/subscribe.<trigger>.<kanał>` w Application (`on-sync-failed`,
   `on-health-degraded`; `on-deployed` idzie do `suw-platf-deployments-notif`) i `ask` +
   `discord_channel <kanał> "$URL"` w `setup.sh`. Reguła 10 pilnuje, żeby lista, adnotacje i wywołania się
   zgadzały (także w drugą stronę: martwy kanał oblewa bramkę).
5. **Gatus (opcjonalnie, alert „nie odpowiada”)** — wpis w `argocd/manifests/gatus/config.yaml`: adres
   przez Service w klastrze (`/api/health`, gdy serwer odpowiada dopiero z bazą). Własny kanał:
   `provider-override` z `${DISCORD_<KANAŁ>}` (wielkie litery, myślniki → `_`); reguła 11 sprawdza, że
   `discord_channel` w jakimś `setup.sh` tę zmienną ustawia.
6. **Homepage (opcjonalnie)** — kafelek w `argocd/manifests/homepage/config.yaml`.
7. **Z internetu (opcjonalnie)** — wpis w `apps` w `terraform/edge/edge.auto.tfvars` (`access = "<grupa>"`
   albo `public = true`) i, dla grupy, `ask` + `write_group` w `setup.sh`; patrz `docs/edge/guide/`.
   Tylko sieć domowa: nic w `terraform/edge` (jak `suwageval`), wystarczy wpis wieloznaczny DNS.
8. **Opisy** — wiersz w drzewie w `argocd/README.md`; ten plik, jeśli projekt zmienia układ.
9. **`just check`** ma przejść. Obraz musi istnieć w rejestrze przed pierwszym wdrożeniem —
   `just argo deploy` to sprawdza.

Kroki ręczne właściciela — agent ich nie wykonuje (zmiany zostają w drzewie roboczym):

- **Kanał Discorda:** założyć kanał i webhook w Discordzie (to nie jest w kodzie); URL wpisze `setup.sh`.
- **Nowy kanał na liście:** `just platform apply` (Argo dostaje nową usługę powiadomień) — dopiero po nim
  alerty trafią na kanał; przed `plan` obejrzeć, że zmienia się tylko konfiguracja powiadomień.
- **Uruchomić `scripts/projects/<p>/[<env>/]setup.sh`** — sekrety, hasło bazy i webhook trafiają do klastra
  (potrzebny kubeconfig); nowy wpis z internetu: `just edge plan` → `apply`.
- **`just secrets backup`** — kopia nowego pliku `.secrets/*.env` w Bitwardenie.
- Commit i push (agent ich nie robi); po wypchnięciu Argo wdraża projekt i sam tworzy namespace.

**Wyłączenie projektu na jakiś czas** (bez usuwania): parametr `enabled: "false"` w jego Application, gdy chart
go zna (`suwageval`), i `allowEmpty: true` w `syncPolicy.automated` (bez niego Argo odmawia automatycznego
synchronizowania do pustego wydania). Chart nie renderuje wtedy nic, Argo prunuje całe wydanie i zwalnia klaster; namespace, jego
Secrety i baza zostają, bo nie należą do charta. W tym samym commicie `enabled: false` przy wpisie projektu w
gatus, żeby nie alarmował. Powrót: `"true"` w obu miejscach.

### Gdzie co leży — zasady, które trzymają układ

- **Terraform:** jedna konfiguracja główna na warstwę (`terraform/<warstwa>/`), z własnym
  stanem i modułem just o tej samej nazwie. Nowa warstwa = katalog + moduł + wiersz w README.
- **Argo:** element platformy to plik `argocd/apps/platform/<element>.yaml` i jedno z dwóch:
  własne manifesty w `argocd/manifests/<element>/` (para: `path`) albo gotowy chart upstream
  w przypiętej wersji (`chart` + `targetRevision: X.Y.Z`) — wtedy bez katalogu manifestów.
  Projekt to jeden plik w `apps/projects/` (chart leży w repo projektu). `just check`
  pilnuje obu wariantów.
- **Wdrożenie projektu to dwie wartości, zmieniane razem:** `targetRevision` (pełny SHA commita
  repo projektu — chart) i `image.tag` (`sha-` + początek tego samego SHA — obraz). Chart na
  `master` wdrażałby każdy commit z chartem, ze starym obrazem; to repo ma decydować, co biegnie.
  Zmienia je `just argo deploy <aplikacja> [sha]`, nie ręka. Wyjątek (`# unpinned: <powód>` w pliku)
  jest decyzją, nie domyślnym stanem.
- **Bash ma trzy miejsca, każde z jednym powodem:** `.just/lib/` — implementacja recept
  (wołana przez just i przez CI); `scripts/` — tylko to, czego just nie zrobi (`source`
  do powłoki, `setup.sh` przed instalacją just); `scripts/.internal/` — kroki i funkcje
  tych skryptów. Nowy kod bashowy trafia do pierwszego pasującego miejsca z tej listy.
- **Ręczne kroki poza kodem** (np. OpenMediaVault) dostają notatkę w `docs/` z tabelą
  „co jest w kodzie, a co nie” — jak `docs/nas.md`.

## Bramka jakości: `just check`

Jedno polecenie sprawdza wszystko, co da się sprawdzić bez ludzi, a CI
(`.github/workflows/check.yml`) odpala **dokładnie je** przy każdym pushu. Przed oddaniem
zmiany: `just check` ma przejść. Formatowanie poprawia `just check fmt`.

| Krok | Narzędzie |
| --- | --- |
| format i poprawność Terraformu w każdej warstwie | `tofu fmt -check`, `tofu validate`, tflint (`.tflint.hcl`) |
| bash | shellcheck, shfmt (`-i 4 -ci`) |
| justfile i moduły | `just --fmt --check` |
| YAML, manifesty, CI | yamllint (`.yamllint.yaml`), kubeconform `-strict` (także CRD Argo), actionlint |
| chart każdego projektu | `.just/lib/chart-check.sh`, po jednym kroku na projekt: pobiera chart w przypiętym `targetRevision` (SHA jest w cache `~/.cache/suwalski-platform/charts/`), sprawdza, że każdy `helm.parameters[].name` jest ścieżką kluczy w `values.yaml` (Helm po cichu ignoruje literówkę), renderuje `helm template` z tymi parametrami (jak Argo: `--set`, `--set-string` przy `forceString`) i puszcza wynik przez kubeconform `-strict`. Projekt na `master` renderuje się z `master`. Prywatne repo (`automat-operat`) tylko, gdy maszyna je czyta (`gh`), inaczej krok jest **SKIP** z powodem — nigdy PASS; **w CI jest zawsze SKIP** (brak dostępu do prywatnego repo), więc ten projekt sprawdza się lokalnie |
| zasady z tego pliku | `.just/lib/repo-rules.sh`: finalizer w projektach, przypięte obrazy (`sha-…`, bez `latest`) i chart projektu przypięty do tego samego commita (`targetRevision` = pełny SHA zaczynający się od `image.tag`), pary apps↔manifests albo chart w przypiętej wersji, brak maili (repo publiczne — w przykładach `@example.com`), moduły podpięte w justfile, `set -euo pipefail` w skryptach, pary `scripts/projects/<projekt>/` ↔ `argocd/apps/projects/<projekt>[-<środowisko>].yaml`, kanały Discorda (`discord_channels` ↔ adnotacje ↔ `discord_channel` w `setup.sh`, bez martwych), zmienne `${DISCORD_…}` Gatusa ↔ `discord_channel`, bazy (`database_access` ↔ rola w `cluster.yaml` ↔ `Database` w `databases.yaml`) |
| sekrety | gitleaks na całej historii i na niezacommitowanych zmianach |

`just check live` sprawdza żywe środowisko: plan każdej warstwy bez zmian (dryf = ktoś
kliknął albo kod nie został zastosowany) i każda aplikacja Argo `Synced`/`Healthy`. Wymaga
sieci domowej i sekretów, więc nie biegnie w CI.

**Nowa zasada z tego pliku, którą da się sprawdzić maszynowo, trafia też do
`repo-rules.sh`.** Wersje narzędzi w CI są przypięte w `check.yml` i mają odpowiadać tym
z dotfiles (`home.nix`) — podbijamy je razem (helm: `home.nix` go nie przypina, w CI jest wersja, którą dał nixpkgs).

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
- **`.terraform.lock.hcl` i `terraform.tfstate` commitujemy — stan wyłącznie zaszyfrowany.**
  Lockfile jest kontrolowany ręcznie. Stan opisuje żywą infrastrukturę i zawiera tokeny, więc
  OpenTofu szyfruje go przed zapisem (`terraform/*/encryption.tf`, hasło `STATE_PASSPHRASE`
  z `.secrets/platform.env`); `just check` odrzuca niezaszyfrowany. Bez hasła stan w gicie jest
  bezużyteczny — jego kopia leży w Bitwardenie (`just secrets backup`).
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
