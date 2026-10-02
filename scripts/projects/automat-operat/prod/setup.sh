#!/usr/bin/env bash
# automat-operat project secrets, prod environment. Idempotent.
#
#   .secrets/automat-operat-prod.env ──┬──>  terraform/edge/access/automat-operat.json   (group "automat-operat")
#                                 └──>  Secrets in namespace automat-operat-prod     (when the app needs them)
#
# The "automat-operat" group (you and auntie) belongs to production: it is what lets people into
# automat-operat.gugnowski.com. Dev has its own group, "automat-operat-dev" (dev/setup.sh).
# After changing the list of people: just edge plan → just edge apply.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

echo "== automat-operat / prod: secrets =="
load_source automat-operat-prod
echo "  source: ${SOURCE#"$ROOT"/}"

ask ACCESS_AUTOMAT_OPERAT \
    "Emails of the 'automat-operat' group, comma-separated — who gets into automat-operat.gugnowski.com (e.g. you and auntie)" \
    ""

echo
save_source ACCESS_AUTOMAT_OPERAT

echo
echo "== terraform/edge =="
write_group automat-operat "${CURRENT[ACCESS_AUTOMAT_OPERAT]}"

# ── application Secrets ───────────────────────────────────────────────────────
# When the app needs passwords (e.g. for a database): ask for them above, add the key to
# save_source and uncomment:
#
# echo
# echo "== cluster =="
# if cluster_available; then
#     secret automat-operat-prod automat-operat-sec "DB_PASSWORD=${CURRENT[DB_PASSWORD]}"
# fi

echo
echo "== Next =="
echo "  just edge plan    # change to group \"automat-operat\" — check the email list"
