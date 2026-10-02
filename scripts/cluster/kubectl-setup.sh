#!/usr/bin/env bash
# Connect the homelab cluster to kubectl — alongside other clusters, not instead of them.
#
#   source ./scripts/cluster/kubectl-setup.sh   as below + refreshes KUBECONFIG in this shell
#   just cluster kubeconfig                     fetches, names the context, links
#
# It lives in scripts/, not in .just/, because only `source` touches the current shell —
# and a `just` recipe is always a child process.
#
# What it does, the same way every time (idempotently):
#   1. fetches ./kubeconfig from the node if it is missing,
#   2. names the context, cluster and user in it `homelab` (k3s names everything
#      `default`, which says nothing in a merged KUBECONFIG),
#   3. links it as ~/.kube/configs/homelab.yaml.
#
# KUBECONFIG is assembled from that directory by the 80-kube.zsh fragment in dotfiles.
# suwalski-gcloud-platform does the same with its file as gke.yaml — run order does not matter.
#
# A child process cannot set a variable in the parent shell. New shells get KUBECONFIG
# from the fragment; the current one only with `source`.

# ── mode ──────────────────────────────────────────────────────────────────────
_kube_sourced=0
if [ -n "${BASH_VERSION:-}" ]; then
    (return 0 2>/dev/null) && _kube_sourced=1
    _kube_self="${BASH_SOURCE[0]}"
else
    case "${ZSH_EVAL_CONTEXT:-}" in *file*) _kube_sourced=1 ;; esac
    _kube_self="$0"
fi

# `set -e` in a sourced file applies to YOUR interactive shell — the first failing grep
# would close your terminal. So only when run normally.
[ "$_kube_sourced" -eq 1 ] || set -euo pipefail

_kube_ctx="homelab"
_kube_root="$(cd "$(dirname "$_kube_self")/../.." && pwd)"
_kube_file="$_kube_root/kubeconfig"
_kube_dir="$HOME/.kube/configs"
_kube_frag="$HOME/.dotfiles/fedora/.config/zsh/rc.d/80-kube.zsh"

# An output that may not exist yet. -json first: with an empty state `output -raw`
# prints a warning TO STDOUT and exits zero — it would reach scp as the address.
_kube_out() {
    (cd "$_kube_root/terraform/cluster" && tofu output -json "$1" >/dev/null 2>&1) || return 0
    (cd "$_kube_root/terraform/cluster" && tofu output -raw "$1" 2>/dev/null)
}

# ── 1. fetch, if needed ───────────────────────────────────────────────────────
if [ ! -f "$_kube_file" ]; then
    _kube_ip="$(_kube_out vm_ip)"
    _kube_user="$(_kube_out vm_user)"
    _kube_user="${_kube_user:-maniumek}"
    if [ -n "$_kube_ip" ]; then
        echo "fetching kubeconfig from $_kube_user@$_kube_ip"
        scp -q "$_kube_user@$_kube_ip:~/.kube/config" "$_kube_file" && chmod 600 "$_kube_file"
    fi
fi

if [ -f "$_kube_file" ]; then
    # ── 2. names ──────────────────────────────────────────────────────────────
    # Only whole `default` values in name fields — the k3s file has a fixed shape.
    # After the first pass there is nothing left to replace, so running it again
    # changes nothing.
    sed -i -E "s/^([[:space:]]*(- )?(name|cluster|user|current-context): )default$/\1$_kube_ctx/" "$_kube_file"

    # ── 3. link ───────────────────────────────────────────────────────────────
    mkdir -p "$_kube_dir"
    ln -sfn "$_kube_file" "$_kube_dir/$_kube_ctx.yaml"
    echo "linked: $_kube_dir/$_kube_ctx.yaml -> $_kube_file"
fi

# ── current session ───────────────────────────────────────────────────────────
# The same list as in 80-kube.zsh, just without zsh syntax — the script is sometimes sourced from bash.
if [ "$_kube_sourced" -eq 1 ]; then
    [ -f "$HOME/.kube/config" ] || (umask 077 && : > "$HOME/.kube/config")
    _kube_list="$HOME/.kube/config"
    # find instead of a glob: an empty glob in zsh aborts the sourced script ("no matches").
    for _kube_f in $(find "$_kube_dir" -maxdepth 1 -name '*.yaml' 2>/dev/null | sort); do
        [ -f "$_kube_f" ] && _kube_list="$_kube_list:$_kube_f"
    done
    export KUBECONFIG="$_kube_list"
    echo "KUBECONFIG=$KUBECONFIG  (set in this shell)"
fi

# ── what next ─────────────────────────────────────────────────────────────────
echo
echo "== Next =="

if [ -f "$_kube_frag" ]; then
    _kube_link="$HOME/.config/zsh/rc.d/80-kube.zsh"
    if [ "$(readlink -f "$_kube_link" 2>/dev/null)" = "$(readlink -f "$_kube_frag")" ]; then
        echo "  new shells: active (fragment linked)"
    else
        # rc.d is a directory with a separate link per file, so a new file in the repo
        # does not show up in ~/.config until stow links it.
        echo "  new shells: NOT YET — the fragment is not linked"
        echo "    ~/scripts/fedora/dotfiles/apply.sh"
    fi
else
    echo "  $_kube_frag not found — new shells will not assemble KUBECONFIG on their own" >&2
fi

[ "$_kube_sourced" -eq 1 ] || echo "  this shell:   untouched — source $_kube_self"
echo "  switching:    kubectl config use-context $_kube_ctx   (or :ctx in k9s)"

[ -f "$_kube_file" ] || {
    echo
    echo "  warning: could not fetch $_kube_file"
    echo "    is the machine up? just cluster plan"
}

unset -f _kube_out
unset _kube_sourced _kube_self _kube_ctx _kube_root _kube_file _kube_dir _kube_frag \
    _kube_link _kube_ip _kube_user _kube_list _kube_f
