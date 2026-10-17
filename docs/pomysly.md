# Pomysły bez decyzji

Rzeczy, które nie są jeszcze zadaniami: nikt nie zdecydował, że je robimy. Gdy któraś dojrzeje, trafia do
[`TODO.md`](../TODO.md). Zapisane, żeby pomysł nie zginął — z powodem, dla którego jeszcze czeka.

## Sekrety w gicie zamiast ręcznego `setup.sh`

Największy problem — „gdzie trzymać sekrety, żeby przetrwały utratę laptopa” — rozwiązuje `just secrets
backup|restore` (kopia `.secrets/` w Bitwardenie). Wracać tu dopiero, gdy ręczne `setup.sh` zacznie męczyć
albo pojawi się druga osoba.

Dziś sekrety leżą otwartym tekstem w `.secrets/` (poza gitem, po pliku na zakres), a skrypty `setup.sh`
rozprowadzają je do `terraform/cluster/secrets.auto.tfvars` i do Secretów w klastrze. Działa, jest
idempotentne i wystarcza przy kilku wartościach; przy dziesięciu zacznie męczyć.

Szukany stan: sekret **leży w gicie** w postaci zaszyfrowanej, a odszyfrowuje go ten, kto ma klucz. Wtedy
odtworzenie środowiska to `git clone` plus jeden klucz.

| | Co daje | Koszt |
| --- | --- | --- |
| **SOPS + age** | Szyfruje **pliki** — więc obejmuje i `tfvars`, i manifesty Kubernetesa. Jeden klucz, zero komponentów w klastrze. | Trzeba zabezpieczyć klucz `age` i pamiętać o nim przy nowej maszynie. |
| **Sealed Secrets** | Kontroler w klastrze; szyfrujesz jego kluczem publicznym, wynik idzie do gita. | Obejmuje **tylko** Secrety Kubernetesa — `tfvars` zostają na boku. Dodatkowy pod. |
| **External Secrets** | Pobiera sekrety z zewnętrznego magazynu do klastra. | Wymaga tego magazynu, czyli problem przesuwa się piętro wyżej. |
| **Vault** | Pełny magazyn z politykami, rotacją, audytem. | Ciężki: własny stan, odpieczętowanie po restarcie, kopie zapasowe. Przy jednym użytkowniku to armata na muchę. |

Skłaniamy się do SOPS + age — jako jedyny obejmuje oba miejsca i nie dokłada niczego do klastra. Vault ma
sens, gdyby pojawili się inni ludzie albo potrzeba rotacji. Do rozstrzygnięcia przy realizacji: gdzie
trzymać klucz `age`, żeby przetrwał utratę laptopa, ale nie leżał w repo; czy `setup.sh` zostaje jako warstwa
wygody; czy `SEC_USER_AGENT` (adres e-mail, nie hasło) nie powinien być zwykłą ConfigMapą.

## Strona startowa: lista aplikacji z Ingressów

Homepage (`argocd/manifests/homepage/`) działa; lista aplikacji jest wpisana ręcznie w `config.yaml`
(krok „Nowy projekt — po kolei” w AGENTS.md ma na to osobny punkt). Pomysł: automatyczne wyczytywanie
aplikacji z Ingressów (adnotacje `gethomepage.dev/*` w chartach projektów), żeby nowa usługa pojawiała się
sama. Rzeczy spoza klastra (NAS, Proxmox, AdGuard) i tak zostają ręczne. Czeka, bo przy kilku projektach
ręczny wpis kosztuje mniej niż adnotacje w każdym chartcie.

## AdGuard: czy jeszcze potrzebny do kierowania ruchu

Spekulacja spisana na gorąco, bez weryfikacji. Dziś ścieżki DNS do usług ustawiane są ręcznie w AdGuardzie
(LXC 115) i stamtąd kierują na nginxa — konfiguracja, która istnieje tylko w interfejsie jednego kontenera.
Pytania: czy dałoby się porzucić ręczne wpisy na rzecz czegoś generowanego z kodu; czy przy sensownym
ingressie w klastrze AdGuard w ogóle byłby jeszcze potrzebny w tej roli (może tylko do blokowania reklam);
czy rolę „gdzie jest dana usługa” powinien przejąć ingress plus jeden wpis wieloznaczny. Zanim cokolwiek,
trzeba obejrzeć, jak ten DNS i nginx są dziś naprawdę skonfigurowane. Szersze tło:
[`proxmox-jako-kod.md`](proxmox-jako-kod.md).
