#!/usr/bin/env bash
# Sekrety projektu automat-operat, środowisko dev. Idempotentne.
#
#   .secrets/automat-operat-deploy-key  ──>  Secret repo-automat-operat (namespace argocd)
#   .secrets/automat-operat-dev.env     ──┬──>  terraform/edge/access/automat-operat-dev.json  (grupa „automat-operat-dev”)
#                                         └──>  Secret ghcr-pull           (namespace automat-operat-dev)
#
# Apka to prywatne repo Manomenu/automat-operat, więc klaster potrzebuje dwóch przepustek:
# Argo — żeby przeczytać chart z gita, k3s — żeby pobrać obrazy z GHCR. Obie tylko do
# odczytu.
#
# Dostęp do automat-operat-dev.gugnowski.com daje WŁASNA grupa dev, „automat-operat-dev”:
# Ty i osoby testujące. Celowo nie grupa produkcji — zmiana listy osób na produkcji nie może
# po cichu zmieniać, kto wchodzi na dev, i odwrotnie. Po zmianie listy: just edge plan → apply.
#
# Klucz deploy należy do repo, nie do środowiska. Gdy dojdzie prod, przenieś go do
# wspólnego scripts/projects/automat-operat/setup.sh, zamiast generować drugi.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

REPO_URL="git@github.com:Manomenu/automat-operat.git"
KLUCZ="$SECRETS_DIR/automat-operat-deploy-key"

echo "== automat-operat / dev: sekrety =="

# ── klucz deploy dla Argo ─────────────────────────────────────────────────────
# Generowany, nie wpisywany: prywatna połowa trafia tylko do klastra, publiczną wklejasz
# na GitHubie. Wieloliniowy, więc leży we własnym pliku, a nie w .env.
echo
echo "  klucz deploy: ${KLUCZ#"$ROOT"/}"
if [ ! -f "$KLUCZ" ]; then
    mkdir -p "$SECRETS_DIR" && chmod 700 "$SECRETS_DIR"
    ssh-keygen -q -t ed25519 -N "" -C "argocd@automat-operat" -f "$KLUCZ"
    echo "  wygenerowany. Dodaj publiczną połowę jako deploy key (bez „Allow write access”):"
    echo "    https://github.com/Manomenu/automat-operat/settings/keys/new"
    echo
    sed 's/^/    /' "$KLUCZ.pub"
else
    echo "  istnieje — bez zmian"
fi

# ── dostęp i token do GHCR ────────────────────────────────────────────────────
wczytaj_zrodlo automat-operat-dev
echo
echo "  źródło: ${ZRODLO#"$ROOT"/}"

zapytaj ACCESS_AUTOMAT_OPERAT_DEV \
    "Maile grupy 'automat-operat-dev', po przecinku — kto wchodzi na automat-operat-dev.gugnowski.com (Ty i osoby testujące)" \
    ""

zapytaj GHCR_USER \
    "Użytkownik GitHuba, do którego należy token" \
    "Manomenu"

zapytaj GHCR_TOKEN \
    "Token (classic) z JEDNYM uprawnieniem read:packages — k3s pobiera nim obrazy z GHCR. https://github.com/settings/tokens/new?scopes=read:packages" \
    "" cicho

echo
zapisz_zrodlo ACCESS_AUTOMAT_OPERAT_DEV GHCR_USER GHCR_TOKEN

echo
echo "== terraform/edge =="
zapisz_grupe automat-operat-dev "${OBECNE[ACCESS_AUTOMAT_OPERAT_DEV]}"

# ── klaster ───────────────────────────────────────────────────────────────────
echo
echo "== klaster =="
if klaster_dostepny; then
    repo_argo repo-automat-operat "$REPO_URL" "$KLUCZ"
    secret_rejestru automat-operat-dev ghcr-pull ghcr.io "${OBECNE[GHCR_USER]}" "${OBECNE[GHCR_TOKEN]}"
fi
