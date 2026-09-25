#!/usr/bin/env bash
# Krok setup.sh: zadbaj, żeby był just — bez niego nie działa nic z `just ...`.
# Nie uruchamiaj wprost; woła go scripts/setup.sh. Idempotentne: gdy just jest i czyta
# justfile tego repo, niczego nie robi.
#
# Kolejność źródeł: menedżer pakietów systemu (aktualizuje się razem z resztą), a dopiero
# gdy go brak — oficjalny instalator do ~/.local/bin. Na Fedorze z dotfiles just przychodzi
# z Nixa (~/.dotfiles/fedora/nix/home.nix), więc tu kończy się na potwierdzeniu.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Sprawdzamy nie numer wersji, tylko to, co naprawdę się liczy: czy ten just czyta NASZ
# justfile. Moduły z [doc] i [group] wymagają świeżej wersji, a starsza zgłosi błąd składni.
sprawdz() {
    if just --justfile "$ROOT/justfile" --list >/dev/null 2>&1; then
        echo "  just: $(just --version | cut -d' ' -f2), czyta justfile tego repo"
        return 0
    fi
    echo "  $(just --version) jest, ale nie czyta justfile tego repo — za stara wersja?" >&2
    just --justfile "$ROOT/justfile" --list 2>&1 | head -5 | sed 's/^/    /' >&2
    return 1
}

if command -v just >/dev/null; then
    sprawdz
    exit
fi

if [ -f "$HOME/.dotfiles/fedora/nix/home.nix" ] && grep -qw just "$HOME/.dotfiles/fedora/nix/home.nix"; then
    echo "  just jest w ~/.dotfiles/fedora/nix/home.nix, tylko nie jest jeszcze zainstalowany:" >&2
    echo "    ~/scripts/fedora/nix/apply.sh" >&2
    exit 1
fi

if command -v brew >/dev/null; then
    echo "  instaluję: brew install just"
    brew install just
elif command -v dnf >/dev/null; then
    echo "  instaluję: sudo dnf install just"
    sudo dnf install -y just
elif command -v apt-get >/dev/null && apt-cache show just >/dev/null 2>&1; then
    echo "  instaluję: sudo apt-get install just"
    sudo apt-get install -y just
elif command -v pacman >/dev/null; then
    echo "  instaluję: sudo pacman -S just"
    sudo pacman -S --needed --noconfirm just
else
    # Oficjalny instalator: pojedyncza binarka do katalogu użytkownika, bez sudo.
    echo "  instaluję: just.systems/install.sh -> ~/.local/bin"
    mkdir -p "$HOME/.local/bin"
    curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to "$HOME/.local/bin"
    case ":$PATH:" in
        *":$HOME/.local/bin:"*) ;;
        *) echo "  uwaga: ~/.local/bin nie jest w PATH — dopisz go w konfiguracji powłoki" >&2
           export PATH="$HOME/.local/bin:$PATH" ;;
    esac
fi

sprawdz
