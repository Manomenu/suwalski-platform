# Środowisko w GCP (cdev)

Zapisane 7.10.2026. Zadanie z tej notatki jest w [`TODO.md`](../TODO.md) („Środowisko cdev w GCP”).

## Plan i to, co po nim

Najpierw próbne wdrożenie automat-operat na k3s w maszynie GCP (środowisko `cdev`, plan w artefakcie
„Plan cdev” — artefakt Claude, nie plik tego repo): baza od
razu w Cloud SQL, logi w Cloud Logging, wejście dalej przez Cloudflare Tunnel i Access, Argo CD dalej
w domu. Ten dokument opisuje krok **po** nim, kiedy cdev się sprawdzi i będzie wiadomo, czy zostajemy w GCP.

## Kandydaci do zastąpienia usługami GCP

Każdy osobno i każdy tylko wtedy, gdy zysk przewyższy koszt:

| Dziś (cdev) | W GCP | Co zyskujemy / ile kosztuje |
| --- | --- | --- |
| Cloudflare Tunnel + Access | HTTPS Load Balancer + Identity-Aware Proxy | logowanie kontami Google bez Cloudflare; LB to ok. 18 USD/mies. stałej opłaty |
| hasło do Cloud SQL w Secrecie | logowanie IAM kontem usługi (Cloud SQL Auth Proxy jako sidecar) | brak hasła do pilnowania; zmiana w chartcie |
| obrazy w GHCR + pull secret | Artifact Registry | pobieranie bez tokena (konto usługi maszyny) |
| sekrety z `setup.sh` | Secret Manager + External Secrets | sekrety bez ręcznego rozprowadzania |
| k3s w jednej maszynie | GKE Autopilot | brak maszyny do utrzymania; płatność za pody |
| logowanie `gcloud` właściciela | Workload Identity Federation dla GitHub Actions | `tofu apply` i wdrożenia z CI bez kluczy |

## Do rozstrzygnięcia przy realizacji

Czy Argo CD zostaje w domu (dziś tak — decyzja właściciela), czy środowisko w chmurze ma działać, gdy
dom leży. Przy więcej niż jednym środowisku — [`multiple_env.md`](multiple_env.md).
