#!/usr/bin/env bash
# suwalski-investing-tools (suwinvtools) project secrets. Idempotent.
#
#   .secrets/suwalski-investing-tools.env ──>  Secret suwalski-sec (namespace suw-inv-tools)  (SEC_USER_AGENT)
#   .secrets/suwalski-investing-tools.env ──>  Secret signals      (namespace suw-inv-tools)  (the monthly AI cycle
#                                              signals job: Discord webhooks green/red/status, the mention on red,
#                                              and the OpenAI-compatible model it asks — LLM_BASE_URL, LLM_MODEL,
#                                              LLM_API_KEY)
#   (generated in the cluster)            ──>  Secret database     (namespace suw-inv-tools)  (DATABASE_URL, role and
#                                              database suwinvtools in the shared Postgres)
#
# The signals' channels are the app's own output (verdicts), not platform alerts, so they are plain
# keys of a Secret and not discord_channel entries. The model's address is the owner's private
# infrastructure and this repo is public — so it lives in .secrets/ and a Secret, never in the Application.
# The project has a single environment, so the script sits directly in the project directory.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

NAMESPACE=suw-inv-tools

echo "== suwalski-investing-tools: secrets =="
load_source suwalski-investing-tools
echo "  source: ${SOURCE#"$ROOT"/}"

ask SEC_USER_AGENT \
    "Identification for SEC EDGAR — 'First Last address@email'. Without it SEC rejects requests." \
    ""
ask DISCORD_WEBHOOK_GREEN \
    "Discord webhook of the signals' green channel (mute it on Discord if you like). Enter = keep" \
    "" silent
ask DISCORD_WEBHOOK_RED \
    "Discord webhook of the signals' red channel. Enter = keep" \
    "" silent
ask DISCORD_WEBHOOK_STATUS \
    "Discord webhook of the signals' status channel (INVALID readings, the run summary). Enter = keep, off = none" \
    "off" silent
ask DISCORD_RED_MENTION \
    "Mention in every red message, e.g. <@&role id>, so it pings on a muted server. off = none" \
    "off"
ask LLM_BASE_URL \
    "The signals' model — an OpenAI-compatible server, endpoints directly under it (e.g. http://host:port/v1). Enter = keep" \
    "" silent
ask LLM_MODEL \
    "The model's name on that server. Enter = keep" \
    "" silent
ask LLM_API_KEY \
    "Its API key. off = none" \
    "off" silent

echo
save_source SEC_USER_AGENT DISCORD_WEBHOOK_GREEN DISCORD_WEBHOOK_RED DISCORD_WEBHOOK_STATUS DISCORD_RED_MENTION \
    LLM_BASE_URL LLM_MODEL LLM_API_KEY

# "off" is how ask stores an empty optional answer; the app reads an empty value as "none".
value() {
    local v="${CURRENT[$1]}"
    [ "$v" = off ] && v=""
    printf '%s' "$v"
}

echo
echo "== cluster =="
if cluster_available; then
    secret "$NAMESPACE" suwalski-sec "SEC_USER_AGENT=${CURRENT[SEC_USER_AGENT]}"
    secret "$NAMESPACE" signals \
        "DISCORD_WEBHOOK_GREEN=$(value DISCORD_WEBHOOK_GREEN)" \
        "DISCORD_WEBHOOK_RED=$(value DISCORD_WEBHOOK_RED)" \
        "DISCORD_WEBHOOK_STATUS=$(value DISCORD_WEBHOOK_STATUS)" \
        "DISCORD_RED_MENTION=$(value DISCORD_RED_MENTION)" \
        "LLM_BASE_URL=$(value LLM_BASE_URL)" \
        "LLM_MODEL=$(value LLM_MODEL)" \
        "LLM_API_KEY=$(value LLM_API_KEY)"
    # Role and database are declared in argocd/manifests/postgres/. Python reads a postgresql:// URL.
    database_access "$NAMESPACE" suwinvtools
fi

echo
echo "== Next =="
echo "  just secrets backup   # the webhooks and the model's address into Bitwarden — they are nowhere else"
