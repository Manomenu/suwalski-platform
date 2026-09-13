# Ściąga

Wszystko, co się w tym repo wpisuje, w jednym miejscu. Sprawdzone na tej instalacji —
węzeł `aoostar`, maszyna 119 pod `192.168.0.119`.

---

## Skrypty repo

Nie trzeba pamiętać ścieżek ani flag — od tego są.

| Polecenie | Co robi |
| --- | --- |
| `./scripts/cluster/tofu-validate.sh` | `fmt` + `validate`. Lokalnie, bez dotykania Proxmoksa. Przed każdym commitem. |
| `./scripts/cluster/tofu-plan.sh` | Pokazuje, co by się zmieniło. Niczego nie zmienia. |
| `./scripts/cluster/tofu-apply.sh` | Robi to. `--yes-man` pomija pytanie o zgodę. |
| `source ./scripts/cluster/kubectl-setup.sh` | Pobiera kubeconfig z węzła i od razu sprawdza, że działa. |
| `source ./scripts/cluster/kubectl-setup.sh` | Ustawia `KUBECONFIG` — w tej powłoce i na stałe. Musi być `source`. |
| `./scripts/k9s/logs.sh [-f]` | Log k9s — jedyne miejsce, gdzie tłumaczy się ze swoich decyzji. |

---

## OpenTofu

| Polecenie | Co robi |
| --- | --- |
| `tofu init` | Pobiera providera, tworzy lockfile. Raz, i po zmianie wymagań. |
| `tofu fmt -recursive` | Formatuje pliki, także w `templates/`. |
| `tofu validate` | Sprawdza składnię i typy. Nie łączy się z niczym. |
| `tofu plan` | Różnica między kodem, stanem a rzeczywistością. |
| `tofu apply` | Wykonuje plan po potwierdzeniu. |
| `tofu destroy` | Kasuje **to, co Terraform utworzył**, i nic poza tym. |
| `tofu output` | Wypisuje wyjścia. `-raw nazwa` dla jednej wartości, bez cudzysłowów. |
| `tofu state list` | Co siedzi w stanie. |
| `tofu state mv A B` | Przenosi zasób pod nowy adres. Potrzebne przy przenoszeniu do modułu. |
| `tofu providers schema -json` | Pełny schemat providera — wszystkie pola, jakie istnieją. |

**Zasada:** `plan` przed `apply`, zawsze. Cokolwiek w kolumnie `destroy`, czego się nie
spodziewałeś, jest powodem, żeby się zatrzymać.

---

## kubectl

| Polecenie | Co robi |
| --- | --- |
| `kubectl get <zasób> -A` | Wypisuje. `-A` = wszystkie przestrzenie nazw. |
| `kubectl get <zasób> -o wide` | To samo plus adresy, węzły, obrazy. |
| `kubectl get <zasób> <nazwa> -o yaml` | Pełny obiekt tak, jak trzyma go API. |
| `kubectl describe <zasób> <nazwa>` | Opis i **zdarzenia** — pierwsze miejsce przy awarii. |
| `kubectl logs <pod>` | Logi. `-f` śledzi, `--previous` pokazuje poprzednie wcielenie. |
| `kubectl exec -it <pod> -- sh` | Powłoka w podzie. Nie zadziała na obrazach distroless. |
| `kubectl top nodes` / `top pods` | Zużycie procesora i pamięci. Wymaga metrics-servera. |
| `kubectl api-resources` | **Wszystkie zasoby i ich skróty** dla tego klastra. |
| `kubectl config current-context` | Na co aktualnie celujesz. |

---

## k9s — komendy

Po dwukropku. To te same nazwy, których używa `kubectl get`.

### Co uruchamia pody

| Wpisujesz | Czym to jest |
| --- | --- |
| `:po` | **Pod** — najmniejsza jednostka. Kontener lub kilka, dzielą adres IP. Wymienne: umiera, wstaje nowy, z innym adresem. |
| `:deploy` | **Deployment** — „ma działać N sztuk tego poda". Obsługuje wydania: podnosi nowe, zanim zwinie stare. |
| `:rs` | **ReplicaSet** — warstwa pośrednia Deploymentu, jedna na wersję. Służy do wycofywania zmian. |
| `:ds` | **DaemonSet** — „po jednym na *każdym* węźle, zawsze". Do rzeczy, które muszą być wszędzie. |
| `:sts` | **StatefulSet** — jak Deployment, ale trwałe nazwy (`db-0`) i własne dyski. Do baz. |
| `:jobs` | **Job** — zadanie do wykonania raz, do końca. |
| `:cj` | **CronJob** — Job według harmonogramu. |

### Sieć

| Wpisujesz | Czym to jest |
| --- | --- |
| `:svc` | **Service** — stała nazwa i adres przed zmienną grupą podów. |
| `:ep` | **Endpoints** — adresy podów stojących w tej chwili za usługą. Pusto = nic nie pasuje do selektora. |
| `:ing` | **Ingress** — „ta domena i ścieżka do tej usługi". |
| `:no` | **Node** — maszyna. |
| `:ns` | **Namespace** — przegródka na nazwy, nie na sprzęt. |

### Konfiguracja i dyski

| Wpisujesz | Czym to jest |
| --- | --- |
| `:cm` | **ConfigMap** — ustawienia jako zmienne albo pliki. |
| `:secret` | **Secret** — to samo dla haseł. Domyślnie **base64, nie szyfrowane**. |
| `:pvc` | **PersistentVolumeClaim** — *prośba* o dysk. To ty piszesz. |
| `:pv` | **PersistentVolume** — dysk, który tę prośbę zaspokoił. Powstaje sam. |
| `:sc` | **StorageClass** — *rodzaj* dysku. Tu jedna: `local-path`. |

### Reszta

| Wpisujesz | Czym to jest |
| --- | --- |
| `:ev` lub `:events` | **Event** — dziennik klastra: kto co utworzył, czego nie dało się zaplanować, co zostało zrestartowane i dlaczego. **Gdy pod nie wstaje, a logi są puste, odpowiedź jest tutaj.** |
| `:crd` | **CustomResourceDefinition** — nowy typ obiektu w API. |
| `:sa` | **ServiceAccount** — tożsamość poda wobec API. |
| `:hpa` | **HorizontalPodAutoscaler** — skalowanie pod obciążeniem. |
| `:helmchart` | Obiekty, przez które k3s instaluje swoje dodatki. |

---

## k9s — klawisze

| Klawisz | Co robi |
| --- | --- |
| `?` | Ściąga klawiszy **twojej** wersji. Źródło prawdy. |
| `Ctrl-A` | Lista zasobów i aliasów. |
| `0` | Wszystkie przestrzenie nazw. Cyfry 1–9 wybierają jedną. |
| `Enter` | Wejdź głębiej. Na Deploymencie przeskakuje **od razu do podów**. |
| `d` | Opis i zdarzenia. |
| `y` | Pełny YAML tak, jak trzyma go API. |
| `l` | Logi na żywo. |
| `s` | Powłoka w podzie. |
| `/` | Filtruj widok. `Esc` czyści. |
| `Esc` | Wstecz. |
| `:q` | Wyjście. |

**Pusty widok to zwykle nie awaria.** Albo patrzysz na pustą przestrzeń nazw (`0`
pomaga), albo k9s nie ma kontekstu — a to rozstrzyga `./scripts/k9s/logs.sh`:
`No resources found` znaczy „działa, tylko pusto”, `No context configured` znaczy
„nie wiem, gdzie jest klaster”.

---

## Proxmox

Przez `ssh pve`. Do zaglądania — tworzeniem zajmuje się Terraform.

| Polecenie | Co robi |
| --- | --- |
| `qm list` / `pct list` | Maszyny wirtualne / kontenery. |
| `qm config <id>` | Konfiguracja maszyny. |
| `pvesm status` | Storage: typy, zajętość. |
| `pvesm set local --content …` | Włącza typy zawartości. Tak dodaliśmy `snippets` i `import`. |
| `pveum user token add root@pam terraform --privsep 0` | Tworzy token API. Wartość widać **raz**. |
| `ls /etc/pve/qemu-server/ /etc/pve/lxc/` | Zajęte numery ID — pewniejsze niż `qm list`, bo widać też wyłączone. |

---

## Gdzie czego szukać

| Szukasz | Patrz |
| --- | --- |
| Czemu k9s dziwnie się zachowuje | `~/.local/state/k9s/k9s.log` |
| Czemu maszyna nie wstała | `ssh maniumek@192.168.0.119 'sudo tail -f /var/log/cloud-init-output.log'` |
| Czy cloud-init skończył | `ssh maniumek@192.168.0.119 'ls /var/lib/cloud/k3s-ready'` |
| Czemu pod nie wstaje | `kubectl describe pod <nazwa>` — sekcja Events, albo `:events` w k9s |
| Co się w klastrze dzieje w tej chwili | `:events` w k9s — zdarzenia z całego klastra, nie jednego obiektu |
| Co robi dane pole w `.tf` | `tofu providers schema -json`, albo kursor nad polem w edytorze |
