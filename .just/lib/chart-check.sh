#!/usr/bin/env bash
# One project's Application against its chart: `chart-check.sh argocd/apps/projects/<name>.yaml`.
# Part of `just check` (one step per project).
#
#   1. fetch the chart at the Application's targetRevision (a pinned SHA is cached);
#   2. every helm.parameters name is a key path of the chart's values.yaml — Helm ignores an
#      unknown key silently, so a typo would show up only on the cluster;
#   3. `helm template` with those parameters renders, and the result passes kubeconform -strict.
#
# Exit: 0 passed, 1 failed, 3 skipped (the chart cannot be read on this machine: a private
# repo without gh access — always the case in CI). A skip is never reported as a pass.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.just/lib/charts.sh
source "$ROOT/.just/lib/charts.sh"

file="${1:?usage: chart-check.sh <Application file>}"
for tool in helm kubeconform python3 curl tar; do
    command -v "$tool" >/dev/null || {
        echo "  missing: $tool — helm and kubeconform are in ~/.dotfiles/fedora/nix/home.nix (apply.sh)" >&2
        exit 1
    }
done

url="$(app_field "$file" repoURL)"
revision="$(app_field "$file" revision)"
path="$(app_field "$file" path)"

code=0
chart="$(chart_fetch "$url" "$revision" "$path")" || code=$?
if [ "$code" -eq 3 ]; then
    echo "  SKIP $file: chart not readable here — $(repo_slug "$url") is private (needs gh access)"
    exit 3
elif [ "$code" -ne 0 ]; then
    exit 1
fi

status=0
unknown="$(chart_unknown_params "$file" "$chart")"
if [ -n "$unknown" ]; then
    while IFS= read -r param; do
        echo "  $file: parameter '$param' is not a key in $(repo_slug "$url")@${revision:0:7} $path/values.yaml"
    done <<<"$unknown"
    status=1
fi

rendered="$(mktemp)"
trap 'rm -f "$rendered"' EXIT
if chart_render "$file" "$chart" >"$rendered" 2>"$rendered.err"; then
    manifests_valid <"$rendered" || status=1
else
    echo "  $file: helm template failed:"
    sed 's/^/    /' "$rendered.err"
    status=1
fi
rm -f "$rendered.err"
[ "$status" -ne 0 ] || echo "  $file: ${path} at ${revision:0:7} — parameters known, renders, valid"
exit "$status"
