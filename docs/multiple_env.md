# Więcej niż jedno środowisko

> **Status: nie implementujemy.** Dziś jest jedno środowisko — Proxmox w domu. Ten
> dokument istnieje, żeby w dniu, w którym pojawi się drugie, nie zaczynać od kopiowania
> katalogu. Przeczytaj go **przed** pierwszym `cp -r`.

## Kiedy to w ogóle nastaje

Drugie środowisko to nie „druga maszyna". To **osobny zestaw zasobów, który ma się
psuć osobno**. Na przykład:

- klaster testowy, na którym sprawdzasz zmiany, zanim trafią na ten działający;
- druga lokalizacja — maszyna u dostawcy VPS obok domowej;
- rozdział na „to, co może paść" i „to, czego nie chcę stracić".

Jeśli to, co dokładasz, ma padać *razem* z obecnym środowiskiem i być zarządzane tym
samym `apply` — to nie jest drugie środowisko, tylko kolejny zasób. Dopisz go i tyle.

## Kryterium, które rozstrzyga: stan

Najważniejsze pytanie brzmi nie „jak podzielić pliki", tylko **czy te środowiska mają
dzielić plik stanu**.

Wspólny stan oznacza, że jeden `apply` widzi wszystko naraz. Pomyłka w wartości potrafi
wtedy dotknąć produkcji przy okazji zmiany w teście. Osobny stan zamyka zasięg szkód —
i to jest powód, dla którego w praktyce wygrywa.

## Trzy podejścia

### 1. Katalog na środowisko — to wybieramy

```
terraform/
  modules/
    k3s-node/          main.tf · variables.tf · outputs.tf
  envs/
    homelab/           backend · proxmox.auto.tfvars · wywołanie modułu
    vps/               to samo, inne wartości
```

Każdy katalog w `envs/` jest **osobną konfiguracją główną**: własny stan, własne
wartości, własne `tofu apply`. Wspólny kształt siedzi w module.

Za: osobny stan bez kombinowania, wartości widoczne wprost w plikach, nie da się przez
pomyłkę zaaplikować do złego środowiska — bo jesteś w innym katalogu.

Przeciw: trochę powtórzeń między katalogami (wywołanie modułu wygląda podobnie).
W praktyce to kilkanaście linii i jest to powtórzenie, które **chcesz** widzieć.

**To jest moment, w którym wydzielamy moduł** — i jedyny powód, dla którego byśmy go dziś
wydzielali. Zasada z `AGENTS.md`: moduł piszesz wtedy, gdy inaczej zrobiłbyś kopiuj-wklej.

### 2. Workspace'y

Jedna konfiguracja, `tofu workspace new test`, a wartości wybierane wyrażeniem po nazwie
bieżącego workspace'u.

Za: zero powtórzeń, jedno polecenie do przełączenia.

Przeciw, i dlatego odpadają: wszystkie środowiska dzielą **jeden backend**, a wybór
środowiska jest niewidocznym stanem twojej powłoki — `tofu apply` w złym workspace
wygląda identycznie jak w dobrym. Wartości lądują w mapach
(`local.memory[terraform.workspace]`), które szybko robią się nieczytelne. Sam HashiCorp
odradza workspace'y do rozdzielania produkcji od reszty.

Workspace'y są sensowne do czegoś innego: krótkożyjących kopii tego samego środowiska,
na przykład jednej na gałąź.

### 3. Terragrunt

Nakładka na Terraform, która usuwa powtórzenia między katalogami i dokłada generowanie
backendu.

Za: przy kilkunastu środowiskach realnie oszczędza pisanie.

Przeciw: kolejne narzędzie do zainstalowania, własna składnia i własne błędy. Przy dwóch
środowiskach koszt nauki przewyższa zysk.

## Co się wtedy dzieje z `.auto.tfvars`

Dziś oba pliki wartości mają końcówkę `.auto.tfvars`, więc Terraform wczytuje je sam.
Przy wielu środowiskach ta wygoda przestaje być neutralna — i odpowiedź zależy od tego,
które podejście wybierzesz.

**Reguła brzmi: liczy się, czym jest środowisko — katalogiem czy plikiem.**

| Środowisko to… | Co robić | Dlaczego |
| --- | --- | --- |
| **katalog** (podejście 1) | `.auto.tfvars` **zostaje** | Każdy katalog jest osobną konfiguracją główną, więc widzi tylko własne pliki. Nie ma czego mylić — jesteś albo w `envs/homelab/`, albo w `envs/vps/`. |
| **plik** (jedna konfiguracja, `homelab.tfvars` obok `vps.tfvars`) | `-var-file` **obowiązkowo**, `.auto.` **zakazane** | Auto-wczytywanie wciągnęłoby **wszystkie** pliki naraz, alfabetycznie, i ostatni nadpisałby wcześniejsze. Dostałbyś ciche wymieszanie środowisk zamiast błędu. |

To drugie jest realną pułapką, nie teorią. Wystarczy, że ktoś nazwie plik
`prod.auto.tfvars` w katalogu, gdzie leży już `test.auto.tfvars`, i `tofu apply`
z pozoru zadziała — tyle że na wartościach sklejonych z obu, bez słowa ostrzeżenia.

**Skoro wybieramy podejście katalogowe, `.auto.tfvars` zostaje.** Przy migracji oba pliki
po prostu wędrują do `envs/homelab/` i dalej wczytują się same. Jeśli kiedykolwiek
zdecydujesz się na wariant z jednym katalogiem i wieloma plikami, pierwszą rzeczą do
zrobienia jest **usunięcie `.auto.` z nazw** — inaczej zabezpieczenie znika po cichu.

Dla porządku: istnieje trzecia droga na sekrety, przydatna, gdy `apply` ma kiedyś jechać
z CI — zmienne środowiskowe `TF_VAR_nazwa`. Wtedy token w ogóle nie ma postaci pliku,
więc nie ma czego zapomnieć ani przypadkiem zacommitować.

## Jak wyglądałaby migracja

Gdyby przyszło co do czego, kolejność jest taka:

1. `terraform/main.tf`, `variables.tf`, `outputs.tf` i `templates/` przenoszą się do
   `terraform/modules/k3s-node/` **bez zmian w treści**;
2. z modułu znika `providers.tf` — provider zostaje w konfiguracji głównej i jest
   dziedziczony;
3. powstaje `terraform/envs/homelab/` z trzema plikami: `versions.tf`, `providers.tf`
   i `main.tf` wywołującym moduł;
4. `proxmox.auto.tfvars` i `secrets.auto.tfvars` wędrują do tego katalogu — wczytują się
   dalej same, bo każdy katalog jest osobną konfiguracją główną;
5. istniejący stan trzeba **przenieść, nie odtworzyć**: `tofu state mv` przepisuje adresy
   zasobów na nowe, z przedrostkiem modułu. Bez tego Terraform uzna, że maszyny nie ma,
   i postawi drugą obok pierwszej.

Krok 5 jest tym, o którym się zapomina. Zrób kopię pliku stanu, zanim zaczniesz.
