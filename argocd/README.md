# argocd/

Co ma biec w klastrze. Argo CD obserwuje `apps/` i wprowadza zmiany samo — **tu nie
uruchamia się żadnych poleceń**.

```
apps/                                 Application'y — root app czyta ten katalog rekurencyjnie
├── platform/                         wspólne dla całego klastra, jedno na klaster
│   ├── cloudflared.yaml              łącznik tunelu Cloudflare (terraform/edge/)
│   ├── nas-storage.yaml              klasa storage „nas” — dysk na NAS-ie (docs/nas.md)
│   ├── cloudnative-pg.yaml           operator PostgreSQL — chart upstream, bez manifests/
│   └── postgres.yaml                 jeden współdzielony PostgreSQL: bazy i role projektów
└── projects/                         aplikacje — po pliku na projekt i środowisko
    ├── suwalski-investing-tools.yaml namespace suw-inv-tools
    └── automat-operat-dev.yaml       automat-operat (prywatne repo) pod automat-operat-dev.gugnowski.com
manifests/                            manifesty elementów platformy, które nie mają własnego repo
├── cloudflared/                      para z apps/platform/cloudflared.yaml
│   └── deployment.yaml
├── nas-storage/                      para z apps/platform/nas-storage.yaml
│   └── provisioner.yaml
└── postgres/                         para z apps/platform/postgres.yaml
    ├── cluster.yaml                  instancja „shared” na klasie nas + role projektów
    └── databases.yaml                po bazie na projekt i środowisko
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

Zmień `image.tag` w pliku aplikacji i wypchnij. To **jedyna** zmiana potrzebna do
wdrożenia — i dlatego `git log` na tym pliku jest historią wdrożeń, a `git revert`
wycofaniem.

Elementy platformy z `manifests/` aktualizuje się tak samo: zmiana wersji obrazu
w manifeście, commit, push.

## Czemu to repo, a nie repo z kodem

Chart mieszka przy kodzie, bo kształt wdrożenia zmienia się razem z nim. Ale **wersja
jest stanem środowiska**, nie kodu. Gdyby numer leżał w repo z kodem, każdy commit
z kodem byłby wdrożeniem — i znikłaby różnica między „przetestowane" a „uruchomione".
