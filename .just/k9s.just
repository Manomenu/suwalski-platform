# k9s — narzędzie jest w dotfiles, tu tylko to, co pomaga zrozumieć, co robi.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

[private]
default:
    @just --justfile {{justfile()}} --list k9s --unsorted --list-heading $'Polecenia — `just k9s <polecenie>`:\n'

[doc('Log k9s — jedyne miejsce, gdzie tłumaczy się ze swoich decyzji. -f śledzi, -n N linii')]
logs *args:
    @{{justfile_directory()}}/.just/lib/k9s-logs.sh "$@"
