#!/usr/bin/env bash
# suwalski-investing-tools project secrets. Idempotent.
#
#   .secrets/suwalski-investing-tools.env ──>  Secret suwalski-sec (namespace suw-inv-tools)
#
# The project has a single environment, so the script sits directly in the project directory.
# When dev/prod arrive, split it like scripts/projects/automat-operat/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

echo "== suwalski-investing-tools: secrets =="
migrate_old_env
load_source suwalski-investing-tools
echo "  source: ${SOURCE#"$ROOT"/}"

ask SEC_USER_AGENT \
    "Identification for SEC EDGAR — 'First Last address@email'. Without it SEC rejects requests." \
    ""

echo
save_source SEC_USER_AGENT

echo
echo "== cluster =="
if cluster_available; then
    secret suw-inv-tools suwalski-sec "SEC_USER_AGENT=${CURRENT[SEC_USER_AGENT]}"
fi
