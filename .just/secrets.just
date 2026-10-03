# A copy of .secrets/ in Bitwarden: after setup.sh changed something, and on a new machine.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

lib := justfile_directory() / ".just/lib"

[private]
default:
    @just --justfile {{ justfile() }} --list secrets --unsorted --list-heading $'Commands — `just secrets <command>`:\n'

[doc('Copy every .secrets/*.env into Bitwarden (folder Homelab). After each setup.sh that changed something')]
backup:
    @{{ lib }}/secrets.sh backup

[doc('New machine: Bitwarden → .secrets/, then ./scripts/setup.sh. --force overwrites differing files')]
restore *args:
    @{{ lib }}/secrets.sh restore "$@"
