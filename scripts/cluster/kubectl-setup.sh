#!/usr/bin/env bash
# Ustaw KUBECONFIG — na stałe i, jeśli skrypt zostanie zasourcowany, od razu.
#
#   source ./scripts/cluster/kubectl-setup.sh   pobiera, ustawia tu i na stałe
#   ./scripts/cluster/kubectl-setup.sh          tylko na stałe, bieżąca powłoka bez zmian
#
# Ta różnica nie jest niedoróbką: proces potomny fizycznie nie może ustawić zmiennej
# w powłoce rodzica. Jedyny sposób, żeby dotknąć bieżącej sesji, to wykonać się w niej.

# ── tryb ──────────────────────────────────────────────────────────────────────
_kube_sourced=0
if [ -n "${BASH_VERSION:-}" ]; then
    (return 0 2>/dev/null) && _kube_sourced=1
    _kube_self="${BASH_SOURCE[0]}"
else
    case "${ZSH_EVAL_CONTEXT:-}" in *file*) _kube_sourced=1 ;; esac
    _kube_self="$0"
fi

# `set -e` w zasourcowanym pliku obowiązuje TWOJĄ interaktywną powłokę — pierwszy
# nieudany grep zamknąłby ci terminal. Dlatego tylko przy normalnym uruchomieniu.
[ "$_kube_sourced" -eq 1 ] || set -euo pipefail

_kube_root="$(cd "$(dirname "$_kube_self")/../.." && pwd)"
_kube_file="$_kube_root/kubeconfig"
_kube_frag="$HOME/.dotfiles/fedora/.config/zsh/rc.d/80-kube.zsh"

# ── pobranie, jeśli trzeba ────────────────────────────────────────────────────
# Wchłonięte z dawnego kubeconfig.sh: osobny skrypt tylko po to, żeby zrobić jedno scp,
# był jednym krokiem za dużo.
if [ ! -f "$_kube_file" ]; then
    _kube_tf="$_kube_root/terraform/cluster"
    _kube_ip="$(cd "$_kube_tf" && tofu output -raw vm_ip 2>/dev/null || true)"
    _kube_user="$(cd "$_kube_tf" && tofu output -raw vm_user 2>/dev/null || echo maniumek)"
    if [ -n "$_kube_ip" ]; then
        echo "pobieram kubeconfig z $_kube_user@$_kube_ip"
        scp -q "$_kube_user@$_kube_ip:~/.kube/config" "$_kube_file" && chmod 600 "$_kube_file"
    fi
fi

# ── bieżąca sesja ─────────────────────────────────────────────────────────────
if [ "$_kube_sourced" -eq 1 ]; then
    export KUBECONFIG="$_kube_file"
    echo "KUBECONFIG=$KUBECONFIG  (ustawione w tej powłoce)"
fi

# ── na stałe ──────────────────────────────────────────────────────────────────
_kube_body="# Klaster k3s z suwalski-platform. Plik generowany przez scripts/cluster/kubectl-setup.sh.
# Ścieżka jest bezwzględna, więc kubectl działa z dowolnego katalogu.
export KUBECONFIG=\"$_kube_file\""

_kube_have_dotfiles=0
if [ -d "$(dirname "$_kube_frag")" ]; then
    _kube_have_dotfiles=1
    if [ -f "$_kube_frag" ] && [ "$(cat "$_kube_frag")" = "$_kube_body" ]; then
        echo "fragment bez zmian: $_kube_frag"
    else
        printf '%s\n' "$_kube_body" > "$_kube_frag"
        echo "zapisany fragment: $_kube_frag"
    fi
else
    echo "nie znalazłem ~/.dotfiles/fedora/.config/zsh/rc.d — dopisz ręcznie:" >&2
    printf '%s\n' "$_kube_body" >&2
fi

# ── co dalej ──────────────────────────────────────────────────────────────────
# Sprawdzane przy KAŻDYM uruchomieniu, nie tylko po zapisie: fragment może leżeć
# w repo od dawna i dalej nie być dowiązany, a wtedy nowe powłoki go nie widzą.
echo
echo "== Dalej =="

if [ "$_kube_have_dotfiles" -eq 1 ]; then
    _kube_link="$HOME/.config/zsh/rc.d/80-kube.zsh"
    if [ "$(readlink -f "$_kube_link" 2>/dev/null)" = "$(readlink -f "$_kube_frag")" ]; then
        echo "  nowe powłoki: aktywne (fragment dowiązany)"
    else
        # rc.d to katalog z osobnym dowiązaniem na każdy plik, więc nowy plik w repo
        # nie pojawi się w ~/.config, póki stow go nie zlinkuje.
        echo "  nowe powłoki: JESZCZE NIE — fragment nie jest dowiązany"
        echo "    ~/scripts/fedora/dotfiles/apply.sh"
    fi
fi

if [ "$_kube_sourced" -eq 1 ]; then
    echo "  ta powłoka:   ustawione"
else
    echo "  ta powłoka:   nietknięta — source $_kube_self"
fi

[ -f "$_kube_file" ] || {
    echo
    echo "  uwaga: nie udało się pobrać $_kube_file"
    echo "    czy maszyna stoi? $_kube_root/scripts/cluster/tofu-plan.sh"
}

unset _kube_sourced _kube_self _kube_root _kube_file _kube_frag _kube_body _kube_have_dotfiles _kube_link _kube_tf _kube_ip _kube_user
