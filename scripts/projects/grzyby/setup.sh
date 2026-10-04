#!/usr/bin/env bash
# grzyby project secrets. Idempotent.
#
#   .secrets/grzyby.env  ──>  Secret mcp in namespace grzyby       (MCP_KEY — the key /mcp asks for)
#   (generated in the cluster) ──>  Secret database in namespace grzyby  (DATABASE_URL)
#
# grzyby.gugnowski.com has no Cloudflare Access (public = true in terraform/edge): chatbots call
# it from their own servers. The key is the whole protection — it goes into the connector's URL
# (https://grzyby.gugnowski.com/mcp?key=…). A new value here invalidates every connector using
# the old one. Single environment, so the script sits directly in the project directory.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

NAMESPACE=grzyby

echo "== grzyby: secrets =="
load_source grzyby
echo "  source: ${SOURCE#"$ROOT"/}"

# URL-safe: it travels in a query string.
ask MCP_KEY \
    "Key for /mcp — goes into the chatbot connector's URL (?key=…). Enter = keep / accept the suggestion" \
    "$(openssl rand -hex 24)" \
    silent

echo
save_source MCP_KEY

echo
echo "== cluster =="
if cluster_available; then
    secret "$NAMESPACE" mcp "MCP_KEY=${CURRENT[MCP_KEY]}"
    # Role and database are declared in argocd/manifests/postgres/.
    database_access "$NAMESPACE" grzyby
fi

echo
echo "== Next =="
echo "  just secrets backup   # the key into Bitwarden — the connector URL needs it"
