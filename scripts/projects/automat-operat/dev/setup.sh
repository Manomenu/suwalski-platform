#!/usr/bin/env bash
# automat-operat project secrets, dev environment. Idempotent.
#
#   .secrets/automat-operat-dev.env  ──>  terraform/edge/access/automat-operat-dev.json  (group "automat-operat-dev")
#   .secrets/automat-operat.env      ──>  Secret ghcr-pull in namespace automat-operat-dev  (project token)
#   (generated in the cluster)       ──>  Secret database in namespace automat-operat-dev   (DATABASE_URL)
#
# Access to automat-operat-dev.gugnowski.com is granted by dev's OWN group, "automat-operat-dev":
# you and the testers. Deliberately not the production group — changing the list of people in
# production must not silently change who gets into dev, and vice versa. After changing the
# list: just edge plan → apply.
#
# The GHCR token belongs to the project (scripts/projects/automat-operat/setup.sh — run it
# first); here we only put it into this environment's namespace.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

NAMESPACE=automat-operat-dev

echo "== automat-operat / dev: secrets =="

# ── project token ─────────────────────────────────────────────────────────────
load_source automat-operat
if [ -z "${CURRENT[GHCR_TOKEN]:-}" ]; then
    echo "  no project GHCR token — first: ./scripts/projects/automat-operat/setup.sh" >&2
    exit 1
fi
GHCR_USER="${CURRENT[GHCR_USER]}"
GHCR_TOKEN="${CURRENT[GHCR_TOKEN]}"

# ── access ────────────────────────────────────────────────────────────────────
load_source automat-operat-dev
echo
echo "  source: ${SOURCE#"$ROOT"/}"

ask ACCESS_AUTOMAT_OPERAT_DEV \
    "Emails of the 'automat-operat-dev' group, comma-separated — who gets into automat-operat-dev.gugnowski.com (you and the testers)" \
    ""

echo
save_source ACCESS_AUTOMAT_OPERAT_DEV

echo
echo "== terraform/edge =="
write_group automat-operat-dev "${CURRENT[ACCESS_AUTOMAT_OPERAT_DEV]}"

# ── cluster ───────────────────────────────────────────────────────────────────
echo
echo "== cluster =="
if cluster_available; then
    registry_secret "$NAMESPACE" ghcr-pull ghcr.io "$GHCR_USER" "$GHCR_TOKEN"
    # Role and database are declared in argocd/manifests/postgres/.
    database_access "$NAMESPACE" automat_operat_dev
fi

echo
echo "== Next =="
echo "  just edge plan    # change to the list of people in group \"automat-operat-dev\" — check include"
