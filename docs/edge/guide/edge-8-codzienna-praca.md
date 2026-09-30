# 8. Codzienna praca

[← pierwsze uruchomienie](edge-7-uruchomienie.md) · [spis treści](edge-0.md) · [następny: diagnostyka →](edge-9-diagnostyka.md)

Przepisy na rzeczy, które będziesz robić co jakiś czas. Każdy zaczyna się od pytania,
**którą warstwę** dotykasz — bo to decyduje, czy potrzebny jest `apply`, czy `git push`.

| Chcę… | Warstwa | Jak |
| --- | --- | --- |
| wystawić nową aplikację | edge **i** projekt | `edge.auto.tfvars` + Ingress w projekcie |
| dopisać / usunąć osobę | sekrety projektu | `scripts/projects/…/setup.sh` → `just edge apply` |
| zaktualizować cloudflared | Argo | wersja obrazu → push |
| zmienić długość sesji | edge | `variables.tf` → `just edge apply` |

## Wystawić nową aplikację

Przykład: aplikacja cioci w namespace `automat-operat-prod`, pod `automat-operat.gugnowski.com`.

**1. Strona projektu — Ingress w klastrze.** W manifestach / charcie aplikacji:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: automat-operat
  namespace: automat-operat-prod
spec:
  ingressClassName: traefik
  rules:
    - host: automat-operat.gugnowski.com        # dokładnie ten host, który jest w edge
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service: { name: automat-operat, port: { number: 80 } }
```

I Application w `argocd/apps/projects/automat-operat-prod.yaml`, który wskazuje, gdzie te
manifesty leżą (repo aplikacji, jak investing-tools).

**2. Strona edge — wpis w mapie.** Jeśli host jest nowy (`automat-operat-dev` już jest; tu dokładamy produkcję):

```hcl
apps = {
  automat-operat-dev = { access = "admin" }            # dev — tylko Ty
  automat-operat     = { access = "automat-operat" }   # ← nowa linijka: produkcja, Ty i ciocia
}
```

```sh
just edge plan     # 3 do dodania: aplikacja Access, rekord DNS, trasa w konfiguracji tunelu (~ zmiana)
just edge apply
```

Jedna linijka tworzy wszystkie trzy rzeczy naraz — rozdział 5, „Najważniejsza właściwość”.

## Dopisać albo usunąć osobę

Listę osób grupy trzyma skrypt, do którego grupa należy — nie platforma. Dla grupy
`automat-operat`:

```sh
./scripts/projects/automat-operat/prod/setup.sh   # ACCESS_AUTOMAT_OPERAT: nowa lista po przecinku
just edge plan                               # ~ zmiana reguły "Grupa: automat-operat" — sprawdź include
just edge apply
```

Dla grupy `admin` to samo, tylko `./scripts/setup.sh` i `ACCESS_ADMIN`.

Usunięcie osoby z reguły **nie wylogowuje** jej od razu — jej sesja (ciasteczko) jest
ważna do końca `session_duration`. Żeby odciąć od razu: panel Zero Trust → *My Team →
Users* → wybierz osobę → *Revoke*.

## Nowa grupa (np. tylko Ty)

Grupa `admin` już istnieje (Twój mail). Wystarczy, że aplikacja jej użyje:

```hcl
argocd = { access = "admin" }
```

Nowa grupa to jedno wywołanie `zapisz_grupe <nazwa> "<maile>"` w setup.sh, do którego
należy — tak jak w `scripts/projects/automat-operat/prod/setup.sh`. Powstaje plik
`terraform/edge/access/<nazwa>.json`, a `access.tf` podchwyci go sam.

## Nowy projekt albo środowisko

Skopiuj `scripts/projects/automat-operat/dev/setup.sh` do
`scripts/projects/<projekt>/<środowisko>/setup.sh` i popraw nazwy. Każdy skrypt czyta
i pisze tylko swój plik w `.secrets/`, więc projekty sobie nie przeszkadzają.

## Zaktualizować cloudflared

```yaml
# argocd/manifests/cloudflared/deployment.yaml
image: cloudflare/cloudflared:2026.9.3   →   nowa wersja
```

Commit, push. Argo zauważy zmianę; Kubernetes wymieni pody po jednym, więc tunel nie
znika ani na chwilę. Wycofanie: `git revert`.

Nowe wersje: [github.com/cloudflare/cloudflared/releases](https://github.com/cloudflare/cloudflared/releases).
Przed dużymi skokami przejrzyj listę zmian — Cloudflare czasem wycofuje stare opcje.

## Zaktualizować provider Terraforma

```sh
cd terraform/edge
tofu init -upgrade        # w ramach ~> 5.25, czyli do < 6.0
just edge plan            # powinno być "No changes"
```

Zmieniony `.terraform.lock.hcl` commitujesz. Przejście na 6.x to osobna, świadoma decyzja
— zmiana wersji głównej zwykle znaczy przepisanie części zasobów.

## Usunąć aplikację

Usuń wpis z `apps`, `just edge plan` pokaże usunięcie trzech rzeczy (aplikacja Access,
rekord, trasa). Potem `apply`. Ingress i Application projektu usuwasz osobno — to inna
warstwa.

[następny: diagnostyka →](edge-9-diagnostyka.md)
