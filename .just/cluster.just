# cluster layer: terraform/cluster/ — the machine on Proxmox and k3s.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()
lib := root / ".just/lib"

[private]
default:
    @just --justfile {{justfile()}} --list cluster --unsorted --list-heading $'Commands — `just cluster <command>`:\n'

[group('tofu')]
[doc('fmt + validate. Local, without touching Proxmox — before every commit')]
validate:
    @{{lib}}/tofu.sh validate cluster

[group('tofu')]
[doc('Show what would change. Changes nothing')]
plan *args:
    @{{lib}}/tofu.sh plan cluster "$@"

[group('tofu')]
[doc('Apply. Arguments go to tofu, e.g. -auto-approve')]
apply *args:
    @{{lib}}/tofu.sh apply cluster "$@"

[group('access')]
[doc('Fetch the kubeconfig and add the homelab context alongside other clusters')]
kubeconfig:
    @{{root}}/scripts/cluster/kubectl-setup.sh
    @echo "  or right away in this shell:  exec zsh"

[group('access')]
[doc('Log in to the k3s node (not the Proxmox host — that is `ssh pve`)')]
ssh:
    @cd {{root}}/terraform/cluster && exec ssh "$(tofu output -raw vm_user)@$(tofu output -raw vm_ip)"
