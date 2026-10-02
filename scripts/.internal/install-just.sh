#!/usr/bin/env bash
# setup.sh step: make sure just is present — nothing in `just ...` works without it.
# Do not run directly; scripts/setup.sh calls it. Idempotent: when just is present and reads
# this repo's justfile, it does nothing.
#
# Order of sources: the system package manager (updates together with everything else), and
# only when there is none — the official installer into ~/.local/bin. On Fedora with dotfiles
# just comes from Nix (~/.dotfiles/fedora/nix/home.nix), so here it ends with a confirmation.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# We check not the version number but what actually matters: whether this just reads OUR
# justfile. Modules with [doc] and [group] need a recent version; an older one reports a syntax error.
check() {
    if just --justfile "$ROOT/justfile" --list >/dev/null 2>&1; then
        echo "  just: $(just --version | cut -d' ' -f2), reads this repo's justfile"
        return 0
    fi
    echo "  $(just --version) is installed, but it cannot read this repo's justfile — too old?" >&2
    just --justfile "$ROOT/justfile" --list 2>&1 | head -5 | sed 's/^/    /' >&2
    return 1
}

if command -v just >/dev/null; then
    check
    exit
fi

if [ -f "$HOME/.dotfiles/fedora/nix/home.nix" ] && grep -qw just "$HOME/.dotfiles/fedora/nix/home.nix"; then
    echo "  just is in ~/.dotfiles/fedora/nix/home.nix, it is just not installed yet:" >&2
    echo "    ~/scripts/fedora/nix/apply.sh" >&2
    exit 1
fi

if command -v brew >/dev/null; then
    echo "  installing: brew install just"
    brew install just
elif command -v dnf >/dev/null; then
    echo "  installing: sudo dnf install just"
    sudo dnf install -y just
elif command -v apt-get >/dev/null && apt-cache show just >/dev/null 2>&1; then
    echo "  installing: sudo apt-get install just"
    sudo apt-get install -y just
elif command -v pacman >/dev/null; then
    echo "  installing: sudo pacman -S just"
    sudo pacman -S --needed --noconfirm just
else
    # Official installer: a single binary into the user's directory, no sudo.
    echo "  installing: just.systems/install.sh -> ~/.local/bin"
    mkdir -p "$HOME/.local/bin"
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to "$HOME/.local/bin"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *)
            echo "  warning: ~/.local/bin is not in PATH — add it in your shell config" >&2
            export PATH="$HOME/.local/bin:$PATH"
            ;;
    esac
fi

check
