# shellcheck shell=bash
# Shared functions for the scripts that look at a project's Helm chart as Argo CD sees it:
# chart-check.sh (the gate) and argo-deploy.sh (`just argo deploy`). Sourced, not executed.
#
#   source "$ROOT/.just/lib/charts.sh"
#
# An Application in argocd/apps/projects/ names a repo, a revision, a path inside it and the
# parameters (`helm.parameters`) Argo passes to `helm template`. Everything here reproduces that:
# fetch the chart at the revision, render it with the parameters, look at the result.
#
# Exit code 3 from a function means "cannot be done on this machine" (no read access to a private
# repo): callers report SKIP, never PASS.

CHARTS_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/suwalski-platform/charts"
CRD_SCHEMAS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

# app_fields FILE — the fields of a project Application, one `key<TAB>value` line each:
# repoURL, revision, path, namespace, name, then `param<TAB>name<TAB>value<TAB>forceString`.
app_fields() {
    python3 -I - "$1" <<'PY'
import sys

try:
    import yaml
except ImportError:
    sys.exit("python3 needs PyYAML (python3-yaml)")

app = yaml.safe_load(open(sys.argv[1]))
source = app["spec"]["source"]
print("name", app["metadata"]["name"], sep="\t")
print("repoURL", source["repoURL"], sep="\t")
print("revision", source["targetRevision"], sep="\t")
print("path", source["path"], sep="\t")
print("namespace", app["spec"]["destination"]["namespace"], sep="\t")
for p in source.get("helm", {}).get("parameters", []):
    print("param", p["name"], p["value"], str(p.get("forceString", False)).lower(), sep="\t")
PY
}

# app_field FILE KEY — one scalar field of app_fields.
app_field() {
    app_fields "$1" | awk -F'\t' -v key="$2" '$1 == key { print $2; exit }'
}

# repo_slug URL — owner/repo of a GitHub URL (https or ssh).
repo_slug() {
    local slug="${1#git@github.com:}"
    slug="${slug#https://github.com/}"
    printf '%s\n' "${slug%.git}"
}

# chart_fetch URL REVISION PATH — prints the directory with the chart at that revision.
# A commit SHA is cached for good (it never changes); a branch is fetched again every time.
# https URL: anonymous (a public repo). ssh URL: a private repo, read through `gh` — returns 3
# when the machine cannot read it (no gh, not logged in, no access; CI).
chart_fetch() {
    local url="$1" revision="$2" path="$3" slug key dir tmp
    slug="$(repo_slug "$url")"
    key="${slug//\//_}-$revision"
    dir="$CHARTS_CACHE/$key"
    if [[ "$revision" =~ ^[0-9a-f]{40}$ ]] && [ -d "$dir/$path" ]; then
        printf '%s\n' "$dir/$path"
        return 0
    fi
    tmp="$(mktemp -d)"
    if [[ "$url" == git@* ]]; then
        if ! command -v gh >/dev/null; then
            echo "gh is not installed — $slug is private" >&2
            rm -rf "$tmp"
            return 3
        fi
        if ! gh api "repos/$slug/tarball/$revision" 2>/dev/null >"$tmp/src.tar.gz"; then
            echo "no read access to the private repo $slug (gh not logged in, or CI)" >&2
            rm -rf "$tmp"
            return 3
        fi
    elif ! curl -fsSL -o "$tmp/src.tar.gz" "https://codeload.github.com/$slug/tar.gz/$revision"; then
        echo "cannot download $slug at $revision" >&2
        rm -rf "$tmp"
        return 1
    fi
    mkdir "$tmp/src"
    tar -xzf "$tmp/src.tar.gz" --strip-components=1 -C "$tmp/src"
    if [ ! -d "$tmp/src/$path" ]; then
        echo "$slug at $revision has no $path" >&2
        rm -rf "$tmp"
        return 1
    fi
    rm -rf "$dir"
    mkdir -p "$dir/$(dirname "$path")"
    mv "$tmp/src/$path" "$dir/$path"
    rm -rf "$tmp"
    printf '%s\n' "$dir/$path"
}

# chart_unknown_params FILE CHARTDIR — the parameters of the Application that are not a key path
# of the chart's values.yaml (dots = nesting), one per line. Helm ignores an unknown key without
# a word, so a typo shows up only on the cluster.
chart_unknown_params() {
    local file="$1" chart="$2"
    app_fields "$file" | python3 -I -c '
import sys, yaml

values = yaml.safe_load(open(sys.argv[1] + "/values.yaml")) or {}
for line in sys.stdin:
    kind, *rest = line.rstrip("\n").split("\t")
    if kind != "param":
        continue
    node = values
    for part in rest[0].split("."):
        if not isinstance(node, dict) or part not in node:
            print(rest[0])
            break
        node = node[part]
' "$chart"
}

# chart_render FILE CHARTDIR [NAME=VALUE…] — `helm template` the way Argo runs it: release name =
# the Application's name, the destination namespace, every helm.parameters entry as --set
# (--set-string with forceString), then the extra NAME=VALUE overrides. Rendered YAML on stdout.
chart_render() {
    local file="$1" chart="$2" name namespace kind pname pvalue force
    shift 2
    local args=()
    name="$(app_field "$file" name)"
    namespace="$(app_field "$file" namespace)"
    while IFS=$'\t' read -r kind pname pvalue force; do
        [ "$kind" = param ] || continue
        if [ "$force" = true ]; then args+=(--set-string "$pname=$pvalue"); else args+=(--set "$pname=$pvalue"); fi
    done < <(app_fields "$file")
    local override
    for override in "$@"; do args+=(--set "$override"); done
    helm template "$name" "$chart" --namespace "$namespace" "${args[@]}"
}

# manifests_valid — reads rendered manifests on stdin, checks them like the gate checks argocd/*.yaml.
manifests_valid() {
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/kubeconform"
    mkdir -p "$cache"
    kubeconform -strict -summary -cache "$cache" -schema-location default -schema-location "$CRD_SCHEMAS" -
}
