#!/usr/bin/env bash
# Every step below is called through run_step "$@", which shellcheck cannot follow.
# shellcheck disable=SC2329
# The repo's quality gate: `just check` runs it, and CI runs exactly the same on every push.
# Prints a PASS/FAIL report; non-zero exit when any step failed.
#
#   check.sh          offline: formats, lints, schemas, repo rules, secrets
#   check.sh fmt      apply the formatters the offline check verifies
#   check.sh live     against the real environment: does every layer's plan match it, and
#                     is every Argo application synced and healthy (needs secrets + LAN)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAYERS=(cluster platform edge)
# Argo's Application CRD is not in the Kubernetes schemas; the CRDs catalog has it.
CRD_SCHEMAS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'

declare -a REPORT
FAILED=0

run_step() {
    local name="$1"
    shift
    echo
    echo "==> $name"
    if "$@"; then
        REPORT+=("PASS  $name")
    else
        REPORT+=("FAIL  $name")
        FAILED=1
    fi
}

# A step that needs a tool nobody installed is a failure, not a silent skip: the gate
# would otherwise pass on a machine that checked nothing.
require() {
    local missing=()
    for tool in "$@"; do command -v "$tool" >/dev/null || missing+=("$tool"); done
    [ ${#missing[@]} -eq 0 ] && return 0
    echo "missing: ${missing[*]} — they are in ~/.dotfiles/fedora/nix/home.nix (apply.sh)" >&2
    return 1
}

# The repo's files as the working tree has them: committed or new, minus what git ignores
# (.secrets/, tfstate, kubeconfig) and minus files deleted but not committed yet.
tracked() {
    git -C "$ROOT" ls-files --cached --others --exclude-standard -- "$@" |
        while IFS= read -r file; do [ -e "$ROOT/$file" ] && printf '%s\n' "$file"; done | sort -u
}

# ── offline ───────────────────────────────────────────────────────────────────

tofu_fmt() {
    require tofu && tofu fmt -check -diff -recursive "$ROOT/terraform"
}

tofu_validate() {
    require tofu || return 1
    local layer status=0
    for layer in "${LAYERS[@]}"; do
        local dir="$ROOT/terraform/$layer"
        # validate needs the providers' schemas. -backend=false: no state is read, and the
        # lockfile stays as committed.
        if [ ! -d "$dir/.terraform" ]; then
            tofu -chdir="$dir" init -backend=false -input=false -lockfile=readonly >/dev/null || status=1
        fi
        local out
        if out="$(tofu -chdir="$dir" validate -no-color 2>&1)"; then
            echo "  $layer: valid"
        else
            echo "  $layer:"
            printf '%s\n' "$out" | sed 's/^/    /'
            status=1
        fi
    done
    return "$status"
}

tflint_layers() {
    require tflint || return 1
    local layer status=0
    for layer in "${LAYERS[@]}"; do
        tflint --chdir="$ROOT/terraform/$layer" --config="$ROOT/.tflint.hcl" --format=compact || status=1
    done
    return "$status"
}

bash_lint() {
    require shellcheck || return 1
    # -x follows `source`, so functions from scripts/.internal/lib.sh are known.
    (cd "$ROOT" && tracked '*.sh' | xargs shellcheck -x)
}

bash_format() {
    require shfmt || return 1
    # 4 spaces, indented case branches — the style the scripts are written in.
    (cd "$ROOT" && tracked '*.sh' | xargs shfmt -i 4 -ci -d)
}

just_format() {
    require just || return 1
    local file status=0
    for file in $(cd "$ROOT" && tracked justfile '.just/*.just'); do
        just --unstable --fmt --check --justfile "$ROOT/$file" >/dev/null 2>&1 || {
            echo "  needs formatting: $file (just check fmt)"
            status=1
        }
    done
    return "$status"
}

yaml_lint() {
    require yamllint && (cd "$ROOT" && tracked '*.yaml' '*.yml' | xargs yamllint --strict -c .yamllint.yaml)
}

manifests() {
    require kubeconform || return 1
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/kubeconform"
    mkdir -p "$cache"
    # -strict: unknown fields are errors (a typo in a field name is otherwise silently
    # ignored by the API). No -ignore-missing-schemas: an unknown kind fails too.
    (cd "$ROOT" && tracked 'argocd/*.yaml' | xargs kubeconform -strict -summary -cache "$cache" \
        -schema-location default -schema-location "$CRD_SCHEMAS")
}

workflows() {
    require actionlint && (cd "$ROOT" && actionlint)
}

repo_rules() {
    "$ROOT/.just/lib/repo-rules.sh"
}

secrets() {
    require gitleaks || return 1
    # The whole history (a secret deleted in a later commit is still published), then what
    # is changed but not committed yet.
    gitleaks git "$ROOT" --no-banner --redact --log-level warn &&
        gitleaks git "$ROOT" --pre-commit --no-banner --redact --log-level warn
}

# ── live ──────────────────────────────────────────────────────────────────────

plans_match() {
    require tofu || return 1
    local layer status=0 code log
    log="$(mktemp)"
    for layer in "${LAYERS[@]}"; do
        # -lock=false: only reads; -detailed-exitcode: 0 no changes, 2 changes, 1 error.
        code=0
        tofu -chdir="$ROOT/terraform/$layer" plan -detailed-exitcode -lock=false -input=false -no-color >"$log" 2>&1 || code=$?
        case "$code" in
            0) echo "  $layer: no changes" ;;
            2)
                echo "  $layer: DRIFT — $(grep -E '^(Plan:|Changes to Outputs)' "$log" | head -1) — just $layer plan"
                status=1
                ;;
            *)
                echo "  $layer: plan failed:"
                tail -5 "$log" | sed 's/^/    /'
                status=1
                ;;
        esac
    done
    rm -f "$log"
    return "$status"
}

argo_apps() {
    require kubectl || return 1
    [ -f "$ROOT/kubeconfig" ] || {
        echo "missing kubeconfig — just cluster kubeconfig" >&2
        return 1
    }
    local apps bad
    apps="$(kubectl --kubeconfig "$ROOT/kubeconfig" -n argocd get applications \
        -o jsonpath='{range .items[*]}{.metadata.name} {.status.sync.status} {.status.health.status}{"\n"}{end}')"
    printf '%s\n' "$apps" | sed 's/^/  /'
    bad="$(printf '%s\n' "$apps" | awk 'NF && ($2 != "Synced" || $3 != "Healthy")')"
    [ -z "$bad" ]
}

# ── run ───────────────────────────────────────────────────────────────────────

case "${1:-offline}" in
    offline)
        run_step "terraform format (tofu fmt -check)" tofu_fmt
        run_step "terraform validate (every layer)" tofu_validate
        run_step "terraform lint (tflint)" tflint_layers
        run_step "bash lint (shellcheck)" bash_lint
        run_step "bash format (shfmt)" bash_format
        run_step "just format (just --fmt --check)" just_format
        run_step "yaml lint (yamllint)" yaml_lint
        run_step "manifests vs Kubernetes schemas (kubeconform)" manifests
        run_step "CI workflows (actionlint)" workflows
        run_step "repo rules (AGENTS.md)" repo_rules
        run_step "secrets in git (gitleaks)" secrets
        ;;
    fmt)
        tofu fmt -recursive "$ROOT/terraform"
        (cd "$ROOT" && tracked '*.sh' | xargs shfmt -i 4 -ci -w)
        for file in $(cd "$ROOT" && tracked justfile '.just/*.just'); do
            just --unstable --fmt --quiet --justfile "$ROOT/$file"
        done
        exit 0
        ;;
    live)
        run_step "every layer's plan matches the environment" plans_match
        run_step "Argo applications synced and healthy" argo_apps
        ;;
    *)
        echo "usage: check.sh [offline|fmt|live]" >&2
        exit 2
        ;;
esac

echo
echo "==================== check report ===================="
for line in "${REPORT[@]}"; do
    echo "  $line"
done
echo "======================================================"
exit "$FAILED"
