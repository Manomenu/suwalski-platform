#!/usr/bin/env bash
# suwageval project secrets (evaluation of LLM agents). Idempotent.
#
#   .secrets/suwageval.env  ──>  Secret judge-model in namespace suwageval  (Models__judge__BaseUrl,
#                                Models__judge__Model — the model Suwageval calls to judge checks)
#   .secrets/suwageval.env  ──>  Secret discord in namespace suwageval      (LiveCheck__DiscordWebhookUrl —
#                                the daily check of the judge's model reports problems to #app-suwageval-notif)
#   (generated in the cluster) ──>  Secret database in namespace suwageval  (ConnectionStrings__Default,
#                                an Npgsql connection string — the server is .NET)
#
# The judge's model address and name are not strictly secrets, but they are the owner's private
# infrastructure, and this repo is public — so they live in .secrets/ and in a Secret, never in the
# Application. The model is an OpenAI-compatible server, its endpoints directly under the base URL
# (e.g. http://host:port/v1).
# suwageval.k8s.suwalski.internal is internal-network only (no Cloudflare, nothing in terraform/edge).
# Single environment, so the script sits directly in the project directory.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

NAMESPACE=suwageval

echo "== suwageval: secrets =="
load_source suwageval
echo "  source: ${SOURCE#"$ROOT"/}"

ask MODEL_BASE_URL \
    "Judge model's base URL — an OpenAI-compatible server, endpoints directly under it (e.g. http://host:port/v1). Private infrastructure, not for git. Enter = keep" \
    "" silent
ask MODEL_NAME \
    "Judge model's name on that server. Enter = keep" \
    "" silent

# This environment's alerts channel: deployment failed, Degraded, not answering, the judge's model broken.
ask DISCORD_APP_SUWAGEVAL_NOTIF \
    "Discord webhook of #app-suwageval-notif — alerts of suwageval. Enter = off" \
    "off" silent
echo
save_source MODEL_BASE_URL MODEL_NAME DISCORD_APP_SUWAGEVAL_NOTIF

echo
echo "== cluster =="
if cluster_available; then
    secret "$NAMESPACE" judge-model \
        "Models__judge__BaseUrl=${CURRENT[MODEL_BASE_URL]}" "Models__judge__Model=${CURRENT[MODEL_NAME]}"
    # Role and database are declared in argocd/manifests/postgres/. .NET reads an Npgsql connection string.
    database_access "$NAMESPACE" suwageval npgsql
    discord_channel app-suwageval-notif "${CURRENT[DISCORD_APP_SUWAGEVAL_NOTIF]}"
    # The same channel for the daily check of the judge's model (optional in the chart: without it
    # the check only fails its Job).
    if [ "${CURRENT[DISCORD_APP_SUWAGEVAL_NOTIF]}" != off ]; then
        secret "$NAMESPACE" discord "LiveCheck__DiscordWebhookUrl=${CURRENT[DISCORD_APP_SUWAGEVAL_NOTIF]}"
    fi
fi

echo
echo "== Next =="
echo "  just secrets backup   # the model's address into Bitwarden — it is nowhere else"
