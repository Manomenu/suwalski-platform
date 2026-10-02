#!/usr/bin/env bash
# automat-operat project secrets shared by all environments. Idempotent.
#
#   .secrets/automat-operat-deploy-key  ──>  Secret repo-automat-operat (namespace argocd)
#   .secrets/automat-operat.env         ──>  GHCR_USER, GHCR_TOKEN for the environments (dev/setup.sh, prod/setup.sh)
#
# The app is the private repo Manomenu/automat-operat, so the cluster needs two passes:
# Argo — to read the chart from git, k3s — to pull images from GHCR. Both belong to the
# repository, not to an environment: dev and prod read the same chart and the same images.
# The ghcr-pull Secret, however, lives in the environment's namespace, so the environment
# script creates it, taking the token from here. Order: this script first, then dev/setup.sh
# (and prod/setup.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

REPO_URL="git@github.com:Manomenu/automat-operat.git"
KEY_FILE="$SECRETS_DIR/automat-operat-deploy-key"

echo "== automat-operat: project secrets =="

# ── deploy key for Argo ───────────────────────────────────────────────────────
# Generated, not typed in: the private half goes only to the cluster, the public half you
# paste on GitHub. It is multi-line, so it lives in its own file rather than in the .env.
echo
echo "  deploy key: ${KEY_FILE#"$ROOT"/}"
if [ ! -f "$KEY_FILE" ]; then
    mkdir -p "$SECRETS_DIR" && chmod 700 "$SECRETS_DIR"
    ssh-keygen -q -t ed25519 -N "" -C "argocd@automat-operat" -f "$KEY_FILE"
    echo "  generated. Add the public half as a deploy key (without \"Allow write access\"):"
    echo "    https://github.com/Manomenu/automat-operat/settings/keys/new"
    echo
    sed 's/^/    /' "$KEY_FILE.pub"
else
    echo "  exists — unchanged"
fi

# ── GHCR token ────────────────────────────────────────────────────────────────
load_source automat-operat
echo
echo "  source: ${SOURCE#"$ROOT"/}"

ask GHCR_USER \
    "GitHub user who owns the token" \
    "Manomenu"

ask GHCR_TOKEN \
    "Token (classic) with ONE permission, read:packages — k3s uses it to pull images from GHCR. https://github.com/settings/tokens/new?scopes=read:packages" \
    "" silent

echo
save_source GHCR_USER GHCR_TOKEN

# ── cluster ───────────────────────────────────────────────────────────────────
echo
echo "== cluster =="
if cluster_available; then
    argo_repo_secret repo-automat-operat "$REPO_URL" "$KEY_FILE"
fi

echo
echo "== Next =="
echo "  ./scripts/projects/automat-operat/dev/setup.sh    # dev access group and the ghcr-pull Secret in automat-operat-dev"
