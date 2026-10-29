# argocd/

Co ma biec w klastrze. Argo CD obserwuje `apps/` i wprowadza zmiany samo — **tu nie
uruchamia się żadnych poleceń**.

```
apps/                                 Application'y — root app czyta ten katalog rekurencyjnie
├── platform/                         wspólne dla całego klastra, jedno na klaster
│   ├── cloudflared.yaml              łącznik tunelu Cloudflare (terraform/edge/)
│   ├── nas-storage.yaml              klasa storage „nas” — dysk na NAS-ie (docs/nas.md)
│   ├── cloudnative-pg.yaml           operator PostgreSQL — chart upstream, bez manifests/
│   ├── postgres.yaml                 jeden współdzielony PostgreSQL: bazy i role projektów
│   ├── tailscale.yaml                węzeł w tailnecie — wyjście do maszyn tylko z Tailscale
│   └── traggo.yaml                   czas pracy dla klientów (tylko sieć domowa) pod traggo.k8s.suwalski.internal
└── projects/                         aplikacje — po pliku na projekt i środowisko
    ├── suwalski-investing-tools.yaml namespace suw-inv-tools
    ├── automat-operat-dev.yaml       automat-operat (prywatne repo) pod automat-operat-dev.gugnowski.com
    ├── grzyby.yaml                   serwer MCP dla chatbotów (publiczny) pod grzyby.gugnowski.com
    ├── pomiary.yaml                  projekt ZAI 26Z (publiczny, własne logowanie) pod pomiary-lasy.gugnowski.com
    └── suwageval.yaml                ewaluacja agentów LLM (tylko sieć domowa) pod suwageval.k8s.suwalski.internal
manifests/                            manifesty elementów platformy, które nie mają własnego repo
├── cloudflared/                      para z apps/platform/cloudflared.yaml
│   └── deployment.yaml
├── nas-storage/                      para z apps/platform/nas-storage.yaml
│   └── provisioner.yaml
├── postgres/                         para z apps/platform/postgres.yaml
│   ├── cluster.yaml                  instancja „shared” na klasie nas + role projektów
│   └── databases.yaml                po bazie na projekt i środowisko
├── tailscale/                        para z apps/platform/tailscale.yaml
│   └── daemonset.yaml
└── traggo/                           para z apps/platform/traggo.yaml
    └── deployment.yaml               Traggo + wolumen z bazą SQLite na klasie nas
```

## platform/ czy projects/

**platform/** — rzecz, z której korzysta cały klaster, niezależnie od tego, ile aplikacji na
nim biegnie: wejście z internetu (cloudflared), w przyszłości np. cert-manager czy
monitoring. Jedna sztuka na klaster, własna przestrzeń nazw.

**projects/** — aplikacja, dla której klaster w ogóle istnieje. Po pliku na projekt
i środowisko (np. `automat-operat-dev.yaml`, `automat-operat-prod.yaml`), każdy we własnej
przestrzeni nazw.

To rozróżnienie jest tylko dla ludzi: dla Argo oba katalogi to po prostu Application'y.
Argo samo siedzi w Terraformie (`terraform/platform/`) wyłącznie dlatego, że nie może
zainstalować samego siebie — wszystko inne, także platforma, idzie stąd.

## Jak dodać aplikację

Nowy plik w `apps/projects/`, commit, push. Argo zauważy go w ciągu kilku minut. Nie ma
kroku `apply` i nie powinno być. Jeśli ma być dostępna z internetu, dopisz ją też do
`apps` w `terraform/edge/edge.auto.tfvars` — patrz `docs/edge/guide/`.

## Jak wdrożyć nową wersję

Wdrożenie to **dwie wartości w pliku aplikacji, zmieniane razem**: `targetRevision` (pełny SHA
commita repo projektu — z niego bierze się chart) i `image.tag` (`sha-` + pierwsze 7 znaków
tego samego commita — obraz). Robi to `just argo deploy <aplikacja> [sha]`: sprawdza, że obrazy
tego commita istnieją w rejestrze, ustawia obie wartości i zostawia zmianę do commita;
potem commit i push. Ręczna zmiana jednej wartości jest błędem — `just check` (reguła w
`repo-rules.sh`) wymaga, żeby SHA zaczynał się od taga. I dlatego `git log` na tym pliku jest
historią wdrożeń, a `git revert` wycofaniem — kodu i charta naraz.

Wyjątek: Application może zostać na `targetRevision: master` tylko z komentarzem
`# unpinned: <powód>` (decyzja, którą da się przeczytać).

Elementy platformy z `manifests/` aktualizuje się prościej: zmiana wersji obrazu
w manifeście, commit, push (manifesty leżą w tym repo, więc nie ma osobnego charta do przypięcia).

## Czemu to repo, a nie repo z kodem

Chart mieszka przy kodzie, bo kształt wdrożenia zmienia się razem z nim — ale **która jego
wersja biegnie, jest stanem środowiska**, nie kodu. Gdyby `targetRevision` wskazywał gałąź
`master`, każdy commit z chartem byłby wdrożeniem (ze starym obrazem), i znikłaby różnica
między „przetestowane" a „uruchomione". Dlatego chart jest przypięty do commita, tak samo
jak obraz.
