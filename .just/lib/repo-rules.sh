#!/usr/bin/env bash
# The rules from AGENTS.md that no linter knows. Part of `just check`; prints one line per
# broken rule and exits non-zero when there is any.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BROKEN=0

broken() {
    echo "  $*"
    BROKEN=1
}

# Same file list as check.sh: the working tree minus ignored and deleted files.
tracked() {
    git ls-files --cached --others --exclude-standard -- "$@" |
        while IFS= read -r file; do [ -e "$file" ] && printf '%s\n' "$file"; done | sort -u
}

# 1. Every project Application has the resources finalizer, or deleting its file leaves the
#    project's resources orphaned in the cluster.
for app in $(tracked 'argocd/apps/projects/*.yaml'); do
    grep -q 'resources-finalizer.argocd.argoproj.io' "$app" ||
        broken "$app: no finalizer resources-finalizer.argocd.argoproj.io (AGENTS.md, Zasady)"
done

# 2. Versions are pinned: no image without a tag, none on `latest`, and every project
#    deploys one exact build (image.tag = sha-…).
while IFS= read -r line; do
    image="${line#*image: }"
    image="${image%%[[:space:]#]*}"
    case "$image" in
        *:latest | *:latest@*) broken "${line%%:*}: image on latest: $image" ;;
        *:*) ;; # a tag, or a digest (@sha256:…)
        *) broken "${line%%:*}: image without a tag: $image" ;;
    esac
done < <(tracked 'argocd/*.yaml' | xargs grep -nE '^[[:space:]]*image:[[:space:]]*[^[:space:]]' || true)

for app in $(tracked 'argocd/apps/projects/*.yaml'); do
    tag="$(grep -A1 'name: image.tag' "$app" | sed -n 's/.*value:[[:space:]]*//p')"
    [[ "$tag" =~ ^sha-[0-9a-f]{7,}$ ]] || broken "$app: image.tag is '$tag', expected one build: sha-<commit>"
done

# 3. A platform element is an Application in argocd/apps/platform/<name>.yaml and either
#    - its manifests in argocd/manifests/<name>/ (path), or
#    - an upstream Helm chart (chart) at a pinned version, and then no manifests directory.
for app in $(tracked 'argocd/apps/platform/*.yaml'); do
    name="$(basename "$app" .yaml)"
    chart="$(sed -n 's/^[[:space:]]*chart:[[:space:]]*//p' "$app")"
    if [ -n "$chart" ]; then
        version="$(sed -n 's/^[[:space:]]*targetRevision:[[:space:]]*\([^[:space:]#]*\).*/\1/p' "$app")"
        [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || broken "$app: chart $chart at '$version', expected an exact version"
        [ ! -d "argocd/manifests/$name" ] || broken "$app: installs a chart, yet argocd/manifests/$name exists"
        continue
    fi
    path="$(sed -n 's/^[[:space:]]*path:[[:space:]]*//p' "$app")"
    [ "$path" = "argocd/manifests/$name" ] || broken "$app: path is '$path', expected argocd/manifests/$name"
    [ -d "argocd/manifests/$name" ] || broken "$app: argocd/manifests/$name does not exist"
done
for dir in argocd/manifests/*/; do
    name="$(basename "$dir")"
    [ -f "argocd/apps/platform/$name.yaml" ] || broken "$dir: no Application argocd/apps/platform/$name.yaml deploys it"
done

# 4. The repo is public: no addresses of real people. Examples use example.com; git@github.com
#    is an SSH remote and user@host.svc/.local/.internal a connection string, not a person.
while IFS= read -r hit; do
    broken "$hit: an email address in a public repo (use name@example.com in examples)"
done < <(tracked | xargs grep -nIoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' |
    grep -vE '@example\.(com|org)$|:git@github\.com$|noreply|\.(svc|local|internal)$' || true)

# 5. Every just module in .just/ is mounted in the justfile — a module nobody mounts is dead.
for module in $(tracked '.just/*.just'); do
    grep -qE "^mod [a-z0-9-]+ '$module'" justfile || broken "$module: not mounted in justfile (mod … '$module')"
done

# 6. Scripts run directly are executable and stop on the first error. Sourced scripts are
#    exempt: `set -e` in them would change the caller's shell.
SOURCED=(scripts/.internal/lib.sh scripts/cluster/kubectl-setup.sh)
for script in $(tracked '*.sh'); do
    if [[ " ${SOURCED[*]} " == *" $script "* ]]; then continue; fi
    [ -x "$script" ] || broken "$script: not executable (chmod +x)"
    grep -q '^set -euo pipefail' "$script" || broken "$script: no 'set -euo pipefail'"
done

if [ "$BROKEN" -eq 0 ]; then echo "  all rules hold"; fi
exit "$BROKEN"
