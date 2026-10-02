# k9s — the tool itself is in dotfiles; here only what helps understand what it does.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

[private]
default:
    @just --justfile {{justfile()}} --list k9s --unsorted --list-heading $'Commands — `just k9s <command>`:\n'

[doc('k9s log — the only place where it explains its decisions. -f follows, -n N lines')]
logs *args:
    @{{justfile_directory()}}/.just/lib/k9s-logs.sh "$@"
