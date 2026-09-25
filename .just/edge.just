# Warstwa edge: terraform/edge/ — Cloudflare: tunel, DNS i logowanie (Access).
# Nie potrzebuje klastra ani Proxmoksa; da się ją stosować niezależnie od nich.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

lib := justfile_directory() / ".just/lib"

[private]
default:
    @just --justfile {{justfile()}} --list edge --unsorted --list-heading $'Polecenia — `just edge <polecenie>`:\n'

[group('tofu')]
[doc('fmt + validate. Lokalnie, bez dotykania Cloudflare')]
validate:
    @{{lib}}/tofu.sh validate edge

[group('tofu')]
[doc('Pokaż, co by się zmieniło w Cloudflare. Niczego nie zmienia')]
plan *args:
    @{{lib}}/tofu.sh plan edge "$@"

[group('tofu')]
[doc('Zastosuj. Argumenty idą do tofu, np. -auto-approve')]
apply *args:
    @{{lib}}/tofu.sh apply edge "$@"

[group('stan')]
[doc('Czy cloudflared w klastrze trzyma tunel: pody i ostatnie linie logu')]
tunnel:
    @kubectl --kubeconfig {{justfile_directory()}}/kubeconfig -n cloudflared get pods -o wide
    @echo
    @kubectl --kubeconfig {{justfile_directory()}}/kubeconfig -n cloudflared logs deploy/cloudflared --tail=10 2>&1 || true
