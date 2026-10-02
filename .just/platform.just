# platform layer: terraform/platform/ — Argo CD and the root application.
# Requires a running cluster and a kubeconfig: `just cluster kubeconfig`.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

lib := justfile_directory() / ".just/lib"

[private]
default:
    @just --justfile {{justfile()}} --list platform --unsorted --list-heading $'Commands — `just platform <command>`:\n'

[group('tofu')]
[doc('fmt + validate. Local, without touching the cluster')]
validate:
    @{{lib}}/tofu.sh validate platform

[group('tofu')]
[doc('Show what would change in the cluster. Changes nothing')]
plan *args:
    @{{lib}}/tofu.sh plan platform "$@"

[group('tofu')]
[doc('Apply. Arguments go to tofu, e.g. -auto-approve')]
apply *args:
    @{{lib}}/tofu.sh apply platform "$@"
