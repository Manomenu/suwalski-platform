#!/usr/bin/env bash
# `just argo deploy <app> [sha]` — move a project to a commit: sets targetRevision (the chart) and
# image.tag (the image) of argocd/apps/projects/<app>.yaml together. Commits nothing, pushes nothing.
#
#   argo-deploy.sh <app> [sha]
#
# <app> is the file name without .yaml (suwageval, automat-operat-dev). sha defaults to the newest
# commit on the repo's master whose CI run (WORKFLOW — the one that builds and publishes the
# images) succeeded. Before it changes anything it checks that the chart at that commit takes the
# file's parameters and renders, and that every image of the render tagged sha-<commit> exists in
# its registry. Anything wrong: a message, a non-zero exit and the file untouched.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.just/lib/charts.sh
source "$ROOT/.just/lib/charts.sh"

WORKFLOW=ci.yml

die() {
    echo "refused: $*" >&2
    echo "  nothing was changed" >&2
    exit 1
}

app="${1:?usage: argo-deploy.sh <app> [sha]}"
requested="${2:-}"
file="$ROOT/argocd/apps/projects/$app.yaml"
[ -f "$file" ] || die "no argocd/apps/projects/$app.yaml (the name is the file's, without .yaml)"
for tool in gh helm kubeconform python3 curl jq; do
    command -v "$tool" >/dev/null || die "missing: $tool"
done

url="$(app_field "$file" repoURL)"
path="$(app_field "$file" path)"
old_revision="$(app_field "$file" revision)"
old_tag="$(app_fields "$file" | awk -F'\t' '$1 == "param" && $2 == "image.tag" { print $3 }')"
[ -n "$old_tag" ] || die "$app has no image.tag parameter"
slug="$(repo_slug "$url")"

# ── which commit ─────────────────────────────────────────────────────────────
if [ -n "$requested" ]; then
    sha="$(gh api "repos/$slug/commits/$requested" -q .sha 2>/dev/null)" || die "$slug has no commit '$requested' (or gh cannot read it)"
else
    sha="$(gh run list -R "$slug" --workflow "$WORKFLOW" --branch master --event push --status success -L 1 \
        --json headSha -q '.[0].headSha // empty' 2>/dev/null)" || die "gh cannot list the runs of $slug"
    [ -n "$sha" ] || die "no successful $WORKFLOW run on master of $slug"
fi
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || die "resolved '$sha', not a full commit SHA"
tag="sha-${sha:0:7}"

if [ "$old_revision" = "$sha" ] && [ "$old_tag" = "$tag" ]; then
    echo "$app: unchanged — already at ${sha:0:7} ($slug)"
    exit 0
fi

# ── the chart at that commit takes the parameters and renders ────────────────
code=0
chart="$(chart_fetch "$url" "$sha" "$path")" || code=$?
[ "$code" -ne 3 ] || die "cannot read the chart of $slug (private repo, gh has no access)"
[ "$code" -eq 0 ] || die "cannot fetch the chart of $slug at ${sha:0:7}"
unknown="$(chart_unknown_params "$file" "$chart")"
[ -z "$unknown" ] || die "the chart at ${sha:0:7} has no values for: $(tr '\n' ' ' <<<"$unknown")(parameters of $app.yaml)"
rendered="$(mktemp)"
trap 'rm -f "$rendered" "$rendered.err"' EXIT
chart_render "$file" "$chart" "image.tag=$tag" >"$rendered" 2>"$rendered.err" ||
    die "helm template failed at ${sha:0:7}: $(head -3 "$rendered.err")"
manifests_valid <"$rendered" >/dev/null 2>&1 || die "the chart at ${sha:0:7} renders manifests that fail kubeconform -strict"

# ── every image of this build exists ─────────────────────────────────────────
# registry_has IMAGE — 0 when ghcr.io/<owner>/<name>:<tag> has a manifest. Anonymous token first
# (public packages); then gh's token (private ones). Tokens reach curl through stdin, not argv.
registry_has() {
    local image="$1" name tag token code accept
    name="${image#ghcr.io/}"
    name="${name%:*}"
    tag="${image##*:}"
    accept='application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json'
    for mode in anonymous gh; do
        if [ "$mode" = anonymous ]; then
            token="$(curl -fs "https://ghcr.io/token?service=ghcr.io&scope=repository:$name:pull" | jq -r '.token // empty')" || token=""
        else
            token="$(printf 'user = "x:%s"\n' "$(gh auth token)" |
                curl -fs -K - "https://ghcr.io/token?service=ghcr.io&scope=repository:$name:pull" | jq -r '.token // empty')" || token=""
        fi
        [ -n "$token" ] || continue
        code="$(printf 'header = "Authorization: Bearer %s"\n' "$token" |
            curl -s -o /dev/null -w '%{http_code}' -K - -H "Accept: $accept" "https://ghcr.io/v2/$name/manifests/$tag")"
        [ "$code" = 200 ] && return 0
    done
    return 1
}

images="$(grep -E '^[[:space:]]*-?[[:space:]]*image:' "$rendered" | sed -E 's/^[^:]*:[[:space:]]*//; s/["'"'"']//g' | sort -u |
    grep -E ":$tag\$" || true)"
[ -n "$images" ] || die "the chart at ${sha:0:7} renders no image tagged $tag — is image.tag the parameter that sets the image?"
for image in $images; do
    [[ "$image" == ghcr.io/* ]] || die "image $image: only ghcr.io is checked, and this one lives elsewhere"
    registry_has "$image" ||
        die "image $image does not exist, or is private and gh's token cannot read it (gh auth refresh -s read:packages) — or the build of ${sha:0:7} is still running or failed"
done

# ── change the two values, nothing else ──────────────────────────────────────
tmp="$(mktemp)"
awk -v rev="$sha" -v tag="$tag" '
    /^[[:space:]]*# unpinned: / { next }
    /^[[:space:]]*targetRevision:/ { sub(/targetRevision:[[:space:]]*[^[:space:]#]+/, "targetRevision: " rev) }
    /name:[[:space:]]*image\.tag[[:space:]]*$/ { pending = 1; print; next }
    pending && /^[[:space:]]*value:/ { sub(/value:[[:space:]]*[^[:space:]#]+/, "value: " tag); pending = 0 }
    { print }
' "$file" >"$tmp"
cat "$tmp" >"$file"
rm -f "$tmp"

if [[ "$old_revision" =~ ^[0-9a-f]{40}$ ]]; then base="$old_revision"; else base="${old_tag#sha-}"; fi
echo "$app ($slug):"
echo "  targetRevision  ${old_revision:0:7} → ${sha:0:7}"
echo "  image.tag       $old_tag → $tag"
for image in $images; do echo "  image exists    $image"; done
echo "  changes         https://github.com/$slug/compare/$base...$sha"
echo "Changed argocd/apps/projects/$app.yaml only — review with git diff, then commit and push (not done here)."
