# terraform/edge/access/

Grupy dostępu Cloudflare Access: **plik = grupa**, nazwa pliku to nazwa grupy, treść to lista
maili. Pliki `*.json` są **poza gitem** (repo jest publiczne) — generują je skrypty setup:

| Plik | Pisze go | Kto |
| --- | --- | --- |
| `admin.json` | `scripts/setup.sh` | Ty |
| `automat-operat-dev.json` | `scripts/projects/automat-operat/dev/setup.sh` | Ty i osoby testujące dev |
| `automat-operat.json` | `scripts/projects/automat-operat/prod/setup.sh` | Ty i ciocia (produkcja) |

Kształt:

```json
["ty@example.com", "ciocia@example.com"]
```

`access.tf` składa grupy ze wszystkich plików w tym katalogu. Aplikacja w `edge.auto.tfvars`
wskazuje grupę po nazwie (`access = "automat-operat"`). Więcej: `docs/edge/guide/edge-4-sekrety.md`.
