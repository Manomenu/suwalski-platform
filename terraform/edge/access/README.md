# terraform/edge/access/

Grupy dostępu Cloudflare Access: **plik = grupa**, nazwa pliku to nazwa grupy, treść to lista
maili. Pliki `*.json` są **poza gitem** (repo jest publiczne) — generują je skrypty setup:

| Plik | Pisze go | Kto |
| --- | --- | --- |
| `admin.json` | `scripts/setup.sh` | Ty |
| `witkowska.json` | `scripts/projects/witkowska/prod/setup.sh` | Ty i ciocia |

Kształt:

```json
["ty@gmail.com", "ciocia@gmail.com"]
```

`access.tf` składa grupy ze wszystkich plików w tym katalogu. Aplikacja w `edge.auto.tfvars`
wskazuje grupę po nazwie (`access = "witkowska"`). Więcej: `docs/edge/guide/edge-4-sekrety.md`.
