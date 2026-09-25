#!/usr/bin/env bash
# Sekrety projektu witkowska, środowisko prod. Idempotentne.
#
#   .secrets/witkowska-prod.env ──┬──>  terraform/edge/access/witkowska.json   (grupa „witkowska”)
#                                 └──>  Secrety w namespace witkowska-prod     (gdy apka ich zechce)
#
# Grupa „witkowska” (Ty i ciocia) należy do produkcji: to ona wpuszcza na
# witkowska.gugnowski.com. Dev wpuszcza grupę „admin” z platformy (scripts/setup.sh).
# Po zmianie listy osób: just edge plan → just edge apply.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

echo "== witkowska / prod: sekrety =="
wczytaj_zrodlo witkowska-prod
echo "  źródło: ${ZRODLO#"$ROOT"/}"

zapytaj ACCESS_WITKOWSKA \
    "Maile grupy 'witkowska', po przecinku — kto wchodzi na witkowska.gugnowski.com (np. Ty i ciocia)" \
    ""

echo
zapisz_zrodlo ACCESS_WITKOWSKA

echo
echo "== terraform/edge =="
zapisz_grupe witkowska "${OBECNE[ACCESS_WITKOWSKA]}"

# ── Secrety aplikacji ─────────────────────────────────────────────────────────
# Gdy apka będzie potrzebować haseł (np. do bazy): zapytaj o nie wyżej, dopisz klucz do
# zapisz_zrodlo i odkomentuj:
#
# echo
# echo "== klaster =="
# if klaster_dostepny; then
#     secret witkowska-prod witkowska-sec "DB_PASSWORD=${OBECNE[DB_PASSWORD]}"
# fi

echo
echo "== Dalej =="
echo "  just edge plan    # zmiana grupy „witkowska” — sprawdź listę maili"
