# cluster layer: terraform/cluster/ — the machine on Proxmox and k3s.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()
lib := root / ".just/lib"

[private]
default:
    @just --justfile {{ justfile() }} --list cluster --unsorted --list-heading $'Commands — `just cluster <command>`:\n'

[doc('Show what would change. Changes nothing')]
[group('tofu')]
plan *args:
    @{{ lib }}/tofu.sh plan cluster "$@"

[doc('Apply. Arguments go to tofu, e.g. -auto-approve')]
[group('tofu')]
apply *args:
    @{{ lib }}/tofu.sh apply cluster "$@"

[doc('Fetch the kubeconfig and add the homelab context alongside other clusters')]
[group('access')]
kubeconfig:
    @{{ root }}/scripts/cluster/kubectl-setup.sh
    @echo "  or right away in this shell:  exec zsh"

[doc('Format (only if empty) and mount the NAS disk at /mnt/nas on the k3s node. Safe to repeat')]
[group('machine')]
nas-disk:
    @cd {{ root }}/terraform/cluster && {{ lib }}/nas-disk.sh "$(tofu output -raw vm_user)@$(tofu output -raw vm_ip)"

[doc('Log in to the k3s node (not the Proxmox host — that is `ssh pve`)')]
[group('access')]
ssh:
    @cd {{ root }}/terraform/cluster && exec ssh "$(tofu output -raw vm_user)@$(tofu output -raw vm_ip)"
