#!/usr/bin/env bash
# Sekrety projektu witkowska, środowisko dev. Idempotentne.
#
#   .secrets/witkowska-dev.env ──>  Secrety w namespace witkowska-dev   (gdy apka ich zechce)
#
# Dostęp do witkowska-dev.gugnowski.com daje grupa „admin” z platformy (scripts/setup.sh),
# więc ten skrypt nie ma własnej grupy. Dziś apka nie ma sekretów — skrypt jest szkieletem,
# żeby było wiadomo, gdzie je dopisać.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

echo "== witkowska / dev: sekrety =="
wczytaj_zrodlo witkowska-dev
echo "  źródło: ${ZRODLO#"$ROOT"/}"

# ── Secrety aplikacji ─────────────────────────────────────────────────────────
# Gdy apka będzie potrzebować haseł: zapytaj o nie, zapisz źródło i włóż do klastra, np.:
#
# zapytaj DB_PASSWORD "Hasło do bazy w witkowska-dev" "" cicho
# echo
# zapisz_zrodlo DB_PASSWORD
# echo
# echo "== klaster =="
# if klaster_dostepny; then
#     secret witkowska-dev witkowska-sec "DB_PASSWORD=${OBECNE[DB_PASSWORD]}"
# fi

cat <<'MSG'
  Nic do ustawienia — ten skrypt nie ma dziś o co pytać.

  Dostęp do witkowska-dev.gugnowski.com daje grupa „admin” (Twój mail). To wartość
  platformy — ustawia ją:
    ./scripts/setup.sh                      pole ACCESS_ADMIN

  Grupę „witkowska” (Ty i ciocia, na produkcję) ustawia:
    ./scripts/projects/witkowska/prod/setup.sh

  Tutaj dojdą hasła aplikacji dev, gdy będą potrzebne (instrukcja w komentarzu w pliku).
MSG
