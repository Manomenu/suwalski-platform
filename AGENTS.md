# suwalski-platform

Środowisko, na które deployuję. Proxmox udaje dostawcę chmury; wszystko, co w nim stoi,
jest opisane kodem. To repo **decyduje, co biegnie** — obrazy publikuje
`suwalski-investing-tools`.

## Układ

```
terraform/          jedna konfiguracja główna (root module)
  templates/        szablony cloud-init
docs/               decyzje, które nie mieszczą się w komentarzu
```

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

- **Nie klikaj w interfejsie Proxmoksa.** Zmiana zrobiona ręcznie zniknie przy najbliższym
  `apply`, a do tego czasu kod będzie kłamał o stanie środowiska.
- **Wersje są przypięte** — k3s, provider, obraz systemu. Środowisko odtwarzalne bije
  środowisko zawsze najnowsze.
- **`.terraform.lock.hcl` commitujemy**, `*.tfstate` nie. Lockfile jest kontrolowany
  ręcznie; stan jest generowany i opisuje żywą infrastrukturę.
- **Przed `apply` zawsze `plan`.** Cokolwiek w kolumnie „destroy", czego się nie
  spodziewałeś, jest powodem, żeby się zatrzymać.
