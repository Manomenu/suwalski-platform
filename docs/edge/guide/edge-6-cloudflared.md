# 6. cloudflared w klastrze

[← pliki Terraforma](edge-5-terraform.md) · [spis treści](edge-0.md) · [następny: pierwsze uruchomienie →](edge-7-uruchomienie.md)

Terraform stworzył tunel po stronie Cloudflare. Ten rozdział jest o drugim końcu:
programie, który w domu wpina się w ten tunel. Najpierw trzy pojęcia z Kubernetesa i Argo,
bez których układ plików nie ma sensu.

## Czym jest manifest

**Manifest** to plik YAML opisujący jeden (lub kilka) obiektów Kubernetesa w stanie
docelowym: „ma istnieć Deployment o nazwie `cloudflared`, z dwiema replikami, obrazem X,
zmienną Y”. Nie jest to polecenie („uruchom”), tylko opis („ma być tak”). Kubernetes —
albo Argo w jego imieniu — doprowadza klaster do zgodności z opisem.

Manifesty mogą być:

- **zwykłe** — napisane wprost, jak `argocd/manifests/cloudflared/deployment.yaml`;
- **generowane z charta Helma** — szablony z lukami (`{{ .Values.image.tag }}`), które
  Helm wypełnia wartościami i dopiero wtedy wychodzą z tego zwykłe manifesty.

## Czym jest Application w Argo

**Application** to *wskaźnik*: „weź manifesty z repo R, ścieżki P, rewizji V i utrzymuj
je w klastrze, w namespace N”. Sam w sobie nie opisuje żadnego poda — mówi tylko, **gdzie
leży opis**.

Porównaj dwa Application'y w tym repo:

```yaml
# argocd/apps/projects/suwalski-investing-tools.yaml
source:
  repoURL: https://github.com/Manomenu/suwalski-investing-tools.git   ← INNE repo
  path: deploy/chart                                                   ← chart Helma
```

```yaml
# argocd/apps/platform/cloudflared.yaml
source:
  repoURL: https://github.com/Manomenu/suwalski-platform.git          ← TO repo
  path: argocd/manifests/cloudflared                                   ← zwykłe manifesty
```

### Dwa namespace'y w jednym pliku

```yaml
metadata:
  namespace: argocd          # gdzie leży SAM Application (zlecenie dla Argo)
spec:
  destination:
    namespace: cloudflared   # gdzie lądują obiekty, które z niego powstają
```

Każdy Application leży w `argocd`, bo Argo domyślnie czyta zlecenia **tylko ze swojego
namespace** — celowo: Application decyduje, co i gdzie się instaluje, więc gdyby mógł
leżeć gdziekolwiek, każdy z prawem zapisu do dowolnego namespace'u mógłby kazać Argo
zainstalować coś w `kube-system`. Pody, Service'y i Ingressy trafiają do namespace'u
z `destination` — tego projektu albo elementu platformy.

`kubectl -n argocd get applications` pokazuje zlecenia, `kubectl -n <projekt> get all` —
to, co z nich powstało.

## Skąd katalog `argocd/manifests/`

Tak — to jest dokładnie ta różnica:

- **investing-tools ma własne repo**, a w nim chart (`deploy/chart`). Kształt wdrożenia
  zmienia się razem z kodem aplikacji, więc mieszka przy kodzie. W tym repo jest tylko
  Application ze wskaźnikiem i przypiętą wersją obrazu.
- **cloudflared nie ma „naszego” repo.** Obraz publikuje Cloudflare, ale *jak go
  uruchomić u nas* (ile replik, skąd token, jakie sondy) to nasza decyzja i nie ma jej
  gdzie trzymać poza tym repo. Więc manifest mieszka tutaj, w `argocd/manifests/`.

Czemu nie w `argocd/apps/`? Bo aplikacja korzeniowa (`root`) czyta `argocd/apps/`
**rekurencyjnie i wszystko, co tam znajdzie, stosuje w namespace `argocd`**. Deployment
cloudflared wrzucony do `apps/` wylądowałby w złym miejscu i bez własnego Application'a.
Podział jest więc taki:

```
argocd/apps/       Application'y   — CO ma biec (wskaźniki), czyta je root
argocd/manifests/  manifesty       — JAK to biegnie, dla rzeczy bez własnego repo
```

## Czemu cloudflared jest Application'em, a nie w `terraform/platform/`

cloudflared jest **na poziomie platformy** — jeden na klaster, z usług korzysta każda
aplikacja. Mogłoby się wydawać, że należy więc do `terraform/platform/`, obok Argo.

Ale Argo jest w Terraformie z konieczności: nie może zainstalować samego siebie. To wyjątek
bootstrapowy, a nie „miejsce na rzeczy platformowe”. Zasada repo brzmi: **Terraform stawia
Argo, a wszystko inne w klastrze idzie z gita przez Argo** — także elementy platformy.

Co zyskujemy:

- **samonaprawa** — ktoś usunie Deployment ręcznie, Argo odtworzy go w minutę
  (`selfHeal: true`); w Terraformie zostałby zepsuty do następnego `apply`;
- **aktualizacja = commit** — zmiana wersji obrazu, push, reszta dzieje się sama;
- **jedno miejsce podglądu** — `just argo apps` i UI Argo pokazują cloudflared obok
  aplikacji;
- **niezależne warstwy** — `terraform/platform` nie musi znać tokena z `terraform/edge`.

Dlatego w `argocd/apps/` są dwa podkatalogi — rozróżnienie dla ludzi, nie dla Argo:

- `platform/` — jedno na klaster (cloudflared; w przyszłości np. monitoring);
- `projects/` — aplikacje, po pliku na projekt i środowisko (np. `automat-operat-dev.yaml`).

## Czemu jeden cloudflared na klaster, a nie na projekt

Tunel wpuszcza ruch do Traefika, a Traefik rozdziela go po hostach do namespace'ów
projektów. Kolejna aplikacja nie potrzebuje nowego cloudflared — tylko wpisu w `apps`
(edge) i Ingressu w swoim namespace. Osobny tunel na projekt ma sens przy wielu zespołach,
które nie mogą dzielić wejścia. Tu byłby to tylko drugi token do pilnowania.

## `argocd/apps/platform/cloudflared.yaml` — Application

```yaml
destination:
  namespace: cloudflared
syncPolicy:
  automated: { selfHeal: true, prune: true }
  syncOptions:
    - CreateNamespace=true
```

- Własny namespace `cloudflared` — łatwo znaleźć, łatwo ograniczyć, kto widzi Secret.
- `CreateNamespace=true` — Argo założy namespace, jeśli go nie ma. `setup.sh` też go
  zakłada, bo musi gdzieś włożyć Secret *przed* pierwszą synchronizacją. Oba sposoby
  są idempotentne, więc nie przeszkadzają sobie.

## `argocd/manifests/cloudflared/deployment.yaml` — linijka po linijce

```yaml
replicas: 2
```
Węzeł jest jeden, więc to nie jest wysoka dostępność. Chodzi o **aktualizacje bez
przerwy**: przy wymianie wersji Kubernetes najpierw stawia nowy pod, potem usuwa stary —
zawsze któryś trzyma tunel. Każda replika to osobny connector; Cloudflare rozkłada ruch
między nie.

```yaml
image: cloudflare/cloudflared:2026.9.3
```
Oficjalny obraz od Cloudflare, **przypięta wersja** — jak k3s, provider i obrazy aplikacji.
Aktualizacja: zmień numer, commit, push (rozdział 8).

```yaml
args: [tunnel, --no-autoupdate, --metrics, 0.0.0.0:2000, run]
```
- `tunnel … run` — podłącz się pod tunel i trzymaj połączenie.
- `--no-autoupdate` — cloudflared umie sam się aktualizować; w kontenerze to błąd, bo
  wersję ma wyznaczać plik w gicie, nie program w biegu.
- `--metrics 0.0.0.0:2000` — mały serwer HTTP z `/ready` i metrykami. `0.0.0.0`, bo
  sonda kubeleta puka spoza kontenera.

Brak `--config` i brak tras — to jest skutek `config_src = "cloudflare"` z rozdziału 5.
cloudflared po podłączeniu **pobiera trasy z Cloudflare**.

```yaml
env:
  - name: TUNNEL_TOKEN
    valueFrom: { secretKeyRef: { name: cloudflared-token, key: token } }
```
Token ze Secretu, który tworzy `setup.sh`. Przez zmienną środowiskową, nie przez argument
`--token`: argumenty procesu widać w `ps` i w `kubectl describe pod`.

**Dopóki Secretu nie ma**, pody stoją w `CreateContainerConfigError`. To nie awaria —
Kubernetes czeka na Secret i wystartuje pody sam, gdy się pojawi.

```yaml
livenessProbe:
  httpGet: { path: /ready, port: metrics }
```
`/ready` odpowiada 200 dopiero, gdy jest przynajmniej jedno połączenie z Cloudflare.
cloudflared bez połączenia nic nie robi, więc restart jest właściwą reakcją.

```yaml
resources: { requests: { cpu: 10m, memory: 32Mi }, limits: { memory: 128Mi } }
```
cloudflared jest lekki. Limit pamięci chroni węzeł przed wyciekiem; limitu CPU celowo brak
(dławienie CPU spowalnia ruch zamiast chronić przed czymkolwiek).

```yaml
securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities: { drop: ["ALL"] }
```
cloudflared to jedyny pod, który rozmawia z internetem — więc dostaje najmniej uprawnień:
nie root, bez możliwości ich podniesienia, bez zapisu na dysk, bez żadnych capabilities.
Gdyby ktoś znalazł w nim dziurę, nie ma czego przejąć.

Brak Service'u — **do cloudflared nic nie przychodzi z klastra**. To on łączy się na
zewnątrz (do Cloudflare) i do środka (do Traefika). Nikt nie musi go znaleźć.

[następny: pierwsze uruchomienie →](edge-7-uruchomienie.md)
