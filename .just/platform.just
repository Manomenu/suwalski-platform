# Warstwa platform: terraform/platform/ — Argo CD i aplikacja korzeniowa.
# Wymaga działającego klastra i kubeconfiga: `just cluster kubeconfig`.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

lib := justfile_directory() / ".just/lib"

[private]
default:
    @just --justfile {{justfile()}} --list platform --unsorted --list-heading $'Polecenia — `just platform <polecenie>`:\n'

[group('tofu')]
[doc('fmt + validate. Lokalnie, bez dotykania klastra')]
validate:
    @{{lib}}/tofu.sh validate platform

[group('tofu')]
[doc('Pokaż, co by się zmieniło w klastrze. Niczego nie zmienia')]
plan *args:
    @{{lib}}/tofu.sh plan platform "$@"

[group('tofu')]
[doc('Zastosuj. Argumenty idą do tofu, np. -auto-approve')]
apply *args:
    @{{lib}}/tofu.sh apply platform "$@"
