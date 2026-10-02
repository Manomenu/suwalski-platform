# platform layer: terraform/platform/ — Argo CD and the root application.
# Requires a running cluster and a kubeconfig: `just cluster kubeconfig`.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

lib := justfile_directory() / ".just/lib"

[private]
default:
    @just --justfile {{ justfile() }} --list platform --unsorted --list-heading $'Commands — `just platform <command>`:\n'

[doc('Show what would change in the cluster. Changes nothing')]
[group('tofu')]
plan *args:
    @{{ lib }}/tofu.sh plan platform "$@"

[doc('Apply. Arguments go to tofu, e.g. -auto-approve')]
[group('tofu')]
apply *args:
    @{{ lib }}/tofu.sh apply platform "$@"
