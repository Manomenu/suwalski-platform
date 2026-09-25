# Warstwa cluster: terraform/cluster/ — maszyna na Proxmoksie i k3s.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()
lib := root / ".just/lib"

[private]
default:
    @just --justfile {{justfile()}} --list cluster --unsorted --list-heading $'Polecenia — `just cluster <polecenie>`:\n'

[group('tofu')]
[doc('fmt + validate. Lokalnie, bez dotykania Proxmoksa — przed każdym commitem')]
validate:
    @{{lib}}/tofu.sh validate cluster

[group('tofu')]
[doc('Pokaż, co by się zmieniło. Niczego nie zmienia')]
plan *args:
    @{{lib}}/tofu.sh plan cluster "$@"

[group('tofu')]
[doc('Zastosuj. Argumenty idą do tofu, np. -auto-approve')]
apply *args:
    @{{lib}}/tofu.sh apply cluster "$@"

[group('dostęp')]
[doc('Pobierz kubeconfig i dodaj kontekst homelab obok innych klastrów')]
kubeconfig:
    @{{root}}/scripts/cluster/kubectl-setup.sh
    @echo "  albo w tej powłoce od razu:  exec zsh"

[group('dostęp')]
[doc('Zaloguj się na węzeł k3s (nie na hosta Proxmoksa — to `ssh pve`)')]
ssh:
    @cd {{root}}/terraform/cluster && exec ssh "$(tofu output -raw vm_user)@$(tofu output -raw vm_ip)"
