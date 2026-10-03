#!/usr/bin/env bash
# A copy of .secrets/*.env in Bitwarden, and back. .secrets/ stays where setup.sh reads and
# writes; Bitwarden is the copy that survives losing this laptop.
#
#   secrets.sh backup              every .secrets/*.env → a Secure Note in folder "Homelab"
#   secrets.sh restore [--force]   those notes → .secrets/ (a differing file is kept unless --force)
#
# One note per file, named "suwalski-platform/.secrets/<file>". Values travel through pipes
# and files only — never as arguments, never on screen. The deploy key is left out on purpose:
# a lost one is replaced by scripts/projects/automat-operat/setup.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SECRETS="$ROOT/.secrets"
FOLDER_NAME="Homelab"
PREFIX="suwalski-platform/.secrets/"
SERVER="https://vault.bitwarden.eu"

for tool in bw jq; do
    command -v "$tool" >/dev/null || {
        echo "$tool not found — it is in ~/.dotfiles/fedora/nix/home.nix" >&2
        exit 1
    }
done

# ── session ───────────────────────────────────────────────────────────────────
# Logging in is yours (master password, 2FA); unlocking asks for the master password here,
# and the session lives only in this process.
case "$(bw status | jq -r .status)" in
    unauthenticated)
        echo "not logged in to Bitwarden — once, in a terminal:" >&2
        echo "  bw config server $SERVER && bw login" >&2
        exit 1
        ;;
    locked)
        echo "unlocking the vault (master password):"
        BW_SESSION="$(bw unlock --raw </dev/tty)"
        export BW_SESSION
        ;;
esac
bw sync >/dev/null

folder_id() {
    local id
    id="$(bw list folders --search "$FOLDER_NAME" | jq -r --arg n "$FOLDER_NAME" '[.[] | select(.name == $n)][0].id // empty')"
    if [ -z "$id" ] && [ "${1:-}" = create ]; then
        id="$(bw get template folder | jq --arg n "$FOLDER_NAME" '.name = $n' | bw encode | bw create folder | jq -r .id)"
        echo "  folder $FOLDER_NAME: created" >&2
    fi
    printf '%s' "$id"
}

# ── backup ────────────────────────────────────────────────────────────────────
backup() {
    local folder file name id
    folder="$(folder_id create)"
    shopt -s nullglob
    for file in "$SECRETS"/*.env; do
        name="$PREFIX$(basename "$file")"
        id="$(bw list items --folderid "$folder" --search "$name" | jq -r --arg n "$name" '[.[] | select(.name == $n)][0].id // empty')"
        if [ -z "$id" ]; then
            bw get template item |
                jq --rawfile notes "$file" --arg n "$name" --arg f "$folder" \
                    '.type = 2 | .secureNote = {type: 0} | .login = null | .name = $n | .notes = $notes | .folderId = $f' |
                bw encode | bw create item >/dev/null
            echo "  $name: created"
        elif diff -q <(bw get item "$id" | jq -j .notes) "$file" >/dev/null; then
            echo "  $name: unchanged"
        else
            bw get item "$id" | jq --rawfile notes "$file" '.notes = $notes' | bw encode | bw edit item "$id" >/dev/null
            echo "  $name: updated"
        fi
    done
}

# ── restore ───────────────────────────────────────────────────────────────────
restore() {
    local force="${1:-}" folder id name file target kept=0
    folder="$(folder_id)"
    [ -n "$folder" ] || {
        echo "no folder $FOLDER_NAME in the vault — nothing was backed up yet (just secrets backup)" >&2
        exit 1
    }
    mkdir -p "$SECRETS" && chmod 700 "$SECRETS"
    while IFS=$'\t' read -r id name; do
        file="${name#"$PREFIX"}"
        # Only plain file names: a note name must not steer the write outside .secrets/.
        [[ "$file" =~ ^[A-Za-z0-9._-]+\.env$ ]] || {
            echo "  $name: skipped (not a .env file name)" >&2
            continue
        }
        target="$SECRETS/$file"
        if [ -f "$target" ] && diff -q <(bw get item "$id" | jq -j .notes) "$target" >/dev/null; then
            echo "  $file: unchanged"
        elif [ -f "$target" ] && [ "$force" != --force ]; then
            echo "  $file: differs from the vault — kept (restore --force to overwrite)"
            kept=1
        else
            (
                umask 077
                bw get item "$id" | jq -j .notes >"$target"
            )
            echo "  $file: restored"
        fi
    done < <(bw list items --folderid "$folder" | jq -r --arg p "$PREFIX" '.[] | select(.name | startswith($p)) | [.id, .name] | @tsv')
    echo
    echo "  next: ./scripts/setup.sh — distributes them to terraform/ and the cluster"
    return "$kept"
}

case "${1:-}" in
    backup) backup ;;
    restore) restore "${2:-}" ;;
    *)
        echo "usage: secrets.sh backup | restore [--force]" >&2
        exit 2
        ;;
esac
