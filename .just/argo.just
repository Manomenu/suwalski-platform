# Argo CD in the homelab cluster. Always via this repo's kubeconfig, not KUBECONFIG from
# the shell — one merged from many clusters targets whichever happens to be selected.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()

[private]
default:
    @just --justfile {{ justfile() }} --list argo --unsorted --list-heading $'Commands — `just argo <command>`:\n'

[doc('Initial password of the admin user')]
password:
    @{{ root }}/.just/lib/argocd-password.sh

[doc('Make Argo check git now instead of waiting up to 3 min. No argument: all applications')]
refresh app="":
    @kubectl --kubeconfig {{ root }}/kubeconfig -n argocd annotate applications \
        {{ if app == "" { "--all" } else { app } }} argocd.argoproj.io/refresh=normal --overwrite
    @echo "  in a few seconds: just argo apps"

[doc('Applications: do they match git (sync) and do they work (health)')]
apps:
    @kubectl --kubeconfig {{ root }}/kubeconfig -n argocd get applications \
        -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision'
