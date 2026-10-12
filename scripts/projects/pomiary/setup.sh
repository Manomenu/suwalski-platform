#!/usr/bin/env bash
# pomiary project secrets (ZAI 26Z course app). Idempotent.
#
#   .secrets/pomiary.env  ──>  Secret admin in namespace pomiary    (ADMIN_USERNAME, ADMIN_PASSWORD —
#                              the first administrator, created by the server when there is none)
#   (generated in the cluster) ──>  Secret database in namespace pomiary  (DATABASE_URL)
#
# pomiary-lasy.gugnowski.com has no Cloudflare Access (public = true in terraform/edge): the
# course's tests call it directly and the app protects admin and sensor operations itself.
# The admin account goes to the teacher in the submission form, so it must keep working until
# grading: do not change the password after submitting. The server creates the administrator
# only when there is none, so a new value here does NOT change an existing account's password.
# Single environment, so the script sits directly in the project directory.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
source "$ROOT/scripts/.internal/lib.sh"

NAMESPACE=pomiary

echo "== pomiary: secrets =="
load_source pomiary
echo "  source: ${SOURCE#"$ROOT"/}"

ask ADMIN_USERNAME \
    "Administrator's login — goes to the teacher in the submission form. Enter = keep / accept the suggestion" \
    "admin"

ask ADMIN_PASSWORD \
    "Administrator's password — goes to the teacher in the submission form, keep it until grading. Enter = keep / accept the suggestion" \
    "$(openssl rand -base64 18)" \
    silent
save_source ADMIN_USERNAME ADMIN_PASSWORD

echo
echo "== cluster =="
if cluster_available; then
    secret "$NAMESPACE" admin "ADMIN_USERNAME=${CURRENT[ADMIN_USERNAME]}" "ADMIN_PASSWORD=${CURRENT[ADMIN_PASSWORD]}"
    # Role and database are declared in argocd/manifests/postgres/.
    database_access "$NAMESPACE" pomiary
fi

echo
echo "== Next =="
echo "  just secrets backup   # the password into Bitwarden — the submission form needs it"
