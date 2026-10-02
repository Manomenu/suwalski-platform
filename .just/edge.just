# edge layer: terraform/edge/ — Cloudflare: tunnel, DNS and login (Access).
# Needs neither the cluster nor Proxmox; it can be applied independently of them.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

lib := justfile_directory() / ".just/lib"

[private]
default:
    @just --justfile {{ justfile() }} --list edge --unsorted --list-heading $'Commands — `just edge <command>`:\n'

[doc('Show what would change in Cloudflare. Changes nothing')]
[group('tofu')]
plan *args:
    @{{ lib }}/tofu.sh plan edge "$@"

[doc('Apply. Arguments go to tofu, e.g. -auto-approve')]
[group('tofu')]
apply *args:
    @{{ lib }}/tofu.sh apply edge "$@"

[doc('Is cloudflared in the cluster holding the tunnel: pods and the last log lines')]
[group('status')]
tunnel:
    @kubectl --kubeconfig {{ justfile_directory() }}/kubeconfig -n cloudflared get pods -o wide
    @echo
    @kubectl --kubeconfig {{ justfile_directory() }}/kubeconfig -n cloudflared logs deploy/cloudflared --tail=10 2>&1 || true
