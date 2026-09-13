# suwalski-platform

Środowisko, na które deployuję. Proxmox udaje tu dostawcę chmury, a wszystko, co w nim
stoi, jest opisane kodem — żadnego klikania w interfejsie.

| Katalog | Co tu jest |
| --- | --- |
| `terraform/` | Maszyna wirtualna i k3s na niej. Warstwa, której Kubernetes nie potrafi zbudować sam. |
| `docs/` | Decyzje, które nie mieszczą się w komentarzu — m.in. co zrobić, gdy dojdzie drugie środowisko. |

Konwencje repo (warstwy wartości, kiedy wydzielać moduł, kiedy dzielić pliki) są
w [`AGENTS.md`](AGENTS.md).

Aplikacje mieszkają osobno, w [`suwalski-investing-tools`](https://github.com/Manomenu/suwalski-investing-tools).
To repo **decyduje, co biegnie**; tamto **publikuje obrazy**. Rozpiska faz jest w
`docs/guide/00-roadmapa.md` tamtego repo.

## Wymagania

| Narzędzie | Do czego |
| --- | --- |
| `tofu` | stawianie i zmienianie infrastruktury |
| `kubectl` | rozmowa z klastrem, skrypty |
| `k9s` | codzienne zaglądanie do klastra |

Repo celowo **nie instaluje niczego samo** — opisuje środowisko, którym zarządzasz, a nie
twoją stację roboczą. Jak je zdobędziesz, zależy od ciebie; u mnie przez home-manager
(`~/.dotfiles/fedora/nix/home.nix`), bo `flake.lock` przypina wersje, zamiast pozwalać
aktualizacji systemu przesuwać je bez pytania.

OpenTofu to ten sam język co Terraform — pliki `.tf` są identyczne, różni się nazwa
polecenia (`tofu` zamiast `terraform`) i licencja. Wszystko, czego się tu nauczysz,
przenosi się 1:1.

Potrzebny też dostęp do Proxmoksa przez SSH jako `root` (alias `pve` w `~/.ssh/config`)
z kluczem załadowanym do agenta — provider używa SSH do wgrywania plików, nie tylko API.

## Pierwsze uruchomienie

```sh
cd terraform
cp secrets.auto.tfvars.example secrets.auto.tfvars   # uzupełnij token i klucz SSH
tofu init                                            # pobiera providera, tworzy lockfile
tofu plan                                            # pokazuje, co zamierza zrobić
tofu apply                                           # robi to
```

Wartości są w trzech warstwach: decyzje projektowe jako `default` w `variables.tf`, fakty
o tej instalacji w `proxmox.auto.tfvars` (w gicie), sekrety w `secrets.auto.tfvars` (poza
gitem). Oba pliki `.auto.tfvars` wczytują się same — nie trzeba podawać `-var-file`.

`plan` niczego nie zmienia i można go puszczać do woli. Dopiero `apply` dotyka Proxmoksa,
i najpierw pyta o potwierdzenie.

## Sprawdzenie, że działa

```sh
eval "$(tofu output -raw fetch_kubeconfig)"
kubectl get nodes           # k3s-1  Ready  control-plane,master
```

Pierwszy start trwa kilka minut: maszyna pobiera aktualizacje i instaluje k3s. Postęp
widać w konsoli maszyny w interfejsie Proxmoksa albo przez `ssh maniumek@192.168.0.119`.

## Co jest gdzie w Proxmoksie

| Rzecz | Gdzie |
| --- | --- |
| Obraz Debiana | storage `local`, sekcja ISO |
| Plik cloud-init | storage `local`, snippety (`/var/lib/vz/snippets`) |
| Dysk maszyny | storage `local-lvm` |
| Maszyna | ID 119, węzeł `aoostar`, adres 192.168.0.119 |

## Zasady

- **Nie klikaj w interfejsie Proxmoksa.** Zmiana zrobiona ręcznie zniknie przy najbliższym
  `apply`, a do tego czasu kod będzie kłamał o stanie środowiska.
- **Wersje są przypięte** — k3s i provider. Ta sama reguła co przy obrazach kontenerów:
  środowisko odtwarzalne bije środowisko zawsze najnowsze.
- **`secrets.auto.tfvars` nigdy nie trafia do gita.** Token API to hasło do całego
  Proxmoksa. `proxmox.auto.tfvars` przeciwnie — ma tam być, bo opisuje środowisko.
- **Stan (`*.tfstate`) też nie.** Opisuje żywą infrastrukturę i bywa w nim więcej, niż
  widać w plikach `.tf`.
