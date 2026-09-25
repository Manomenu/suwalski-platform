#!/usr/bin/env bash
# Sekrety projektu suwalski-investing-tools. Idempotentne.
#
#   .secrets/suwalski-investing-tools.env ──>  Secret suwalski-sec (namespace suw-inv-tools)
#
# Projekt ma jedno środowisko, więc skrypt leży bezpośrednio w katalogu projektu. Gdy dojdą
# dev/prod, rozdziel go jak scripts/projects/witkowska/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

echo "== suwalski-investing-tools: sekrety =="
migruj_stary_env
wczytaj_zrodlo suwalski-investing-tools
echo "  źródło: ${ZRODLO#"$ROOT"/}"

zapytaj SEC_USER_AGENT \
    "Identyfikacja dla SEC EDGAR — 'Imię Nazwisko adres@email'. Bez tego SEC odrzuca żądania." \
    ""

echo
zapisz_zrodlo SEC_USER_AGENT

echo
echo "== klaster =="
if klaster_dostepny; then
    secret suw-inv-tools suwalski-sec "SEC_USER_AGENT=${OBECNE[SEC_USER_AGENT]}"
fi
