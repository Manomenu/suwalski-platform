#!/usr/bin/env bash
# Sekrety projektu automat-operat, środowisko prod. Idempotentne.
#
#   .secrets/automat-operat-prod.env ──┬──>  terraform/edge/access/automat-operat.json   (grupa „automat-operat”)
#                                 └──>  Secrety w namespace automat-operat-prod     (gdy apka ich zechce)
#
# Grupa „automat-operat” (Ty i ciocia) należy do produkcji: to ona wpuszcza na
# automat-operat.gugnowski.com. Dev ma własną grupę „automat-operat-dev” (dev/setup.sh).
# Po zmianie listy osób: just edge plan → just edge apply.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

echo "== automat-operat / prod: sekrety =="
wczytaj_zrodlo automat-operat-prod
echo "  źródło: ${ZRODLO#"$ROOT"/}"

zapytaj ACCESS_AUTOMAT_OPERAT \
    "Maile grupy 'automat-operat', po przecinku — kto wchodzi na automat-operat.gugnowski.com (np. Ty i ciocia)" \
    ""

echo
zapisz_zrodlo ACCESS_AUTOMAT_OPERAT

echo
echo "== terraform/edge =="
zapisz_grupe automat-operat "${OBECNE[ACCESS_AUTOMAT_OPERAT]}"

# ── Secrety aplikacji ─────────────────────────────────────────────────────────
# Gdy apka będzie potrzebować haseł (np. do bazy): zapytaj o nie wyżej, dopisz klucz do
# zapisz_zrodlo i odkomentuj:
#
# echo
# echo "== klaster =="
# if klaster_dostepny; then
#     secret automat-operat-prod automat-operat-sec "DB_PASSWORD=${OBECNE[DB_PASSWORD]}"
# fi

echo
echo "== Dalej =="
echo "  just edge plan    # zmiana grupy „automat-operat” — sprawdź listę maili"
