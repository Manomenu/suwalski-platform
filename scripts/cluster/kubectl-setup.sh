#!/usr/bin/env bash
# Podłącz klaster homelab do kubectl — obok innych klastrów, nie zamiast nich.
#
#   source ./scripts/cluster/kubectl-setup.sh   jak niżej + odświeża KUBECONFIG w tej powłoce
#   just cluster kubeconfig                     pobiera, nazywa kontekst, dowiązuje
#
# Leży w scripts/, a nie w .just/, bo tylko `source` dotyka bieżącej powłoki —
# a recepta `just` jest zawsze procesem potomnym.
#
# Co robi, za każdym razem tak samo (idempotentnie):
#   1. pobiera ./kubeconfig z węzła, jeśli go nie ma,
#   2. nazywa w nim kontekst, klaster i użytkownika `homelab` (k3s nazywa wszystko
#      `default`, co w połączonym KUBECONFIG nic nie mówi),
#   3. dowiązuje go jako ~/.kube/configs/homelab.yaml.
#
# KUBECONFIG składa z tego katalogu fragment 80-kube.zsh w dotfiles. suwalski-gcloud-platform
# robi to samo ze swoim plikiem jako gke.yaml — kolejność uruchamiania nie ma znaczenia.
#
# Proces potomny nie może ustawić zmiennej w powłoce rodzica. Nowe powłoki dostaną
# KUBECONFIG z fragmentu; bieżąca tylko przy `source`.

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

_kube_ctx="homelab"
_kube_root="$(cd "$(dirname "$_kube_self")/../.." && pwd)"
_kube_file="$_kube_root/kubeconfig"
_kube_dir="$HOME/.kube/configs"
_kube_frag="$HOME/.dotfiles/fedora/.config/zsh/rc.d/80-kube.zsh"

# Wyjście, którego może jeszcze nie być. Najpierw -json: przy pustym stanie `output -raw`
# wypisuje ostrzeżenie NA STDOUT i kończy zerem — trafiłoby do scp jako adres.
_kube_out() {
    (cd "$_kube_root/terraform/cluster" && tofu output -json "$1" >/dev/null 2>&1) || return 0
    (cd "$_kube_root/terraform/cluster" && tofu output -raw "$1" 2>/dev/null)
}

# ── 1. pobranie, jeśli trzeba ─────────────────────────────────────────────────
if [ ! -f "$_kube_file" ]; then
    _kube_ip="$(_kube_out vm_ip)"
    _kube_user="$(_kube_out vm_user)"
    _kube_user="${_kube_user:-maniumek}"
    if [ -n "$_kube_ip" ]; then
        echo "pobieram kubeconfig z $_kube_user@$_kube_ip"
        scp -q "$_kube_user@$_kube_ip:~/.kube/config" "$_kube_file" && chmod 600 "$_kube_file"
    fi
fi

if [ -f "$_kube_file" ]; then
    # ── 2. nazwy ──────────────────────────────────────────────────────────────
    # Tylko pełne wartości `default` w polach nazw — plik z k3s ma stały kształt.
    # Po pierwszym przebiegu nie ma już czego zamieniać, więc ponowne uruchomienie
    # niczego nie zmienia.
    sed -i -E "s/^([[:space:]]*(- )?(name|cluster|user|current-context): )default$/\1$_kube_ctx/" "$_kube_file"

    # ── 3. dowiązanie ─────────────────────────────────────────────────────────
    mkdir -p "$_kube_dir"
    ln -sfn "$_kube_file" "$_kube_dir/$_kube_ctx.yaml"
    echo "dowiązany: $_kube_dir/$_kube_ctx.yaml -> $_kube_file"
fi

# ── bieżąca sesja ─────────────────────────────────────────────────────────────
# Ta sama lista co w 80-kube.zsh, tylko bez składni zsh — skrypt bywa sourcowany z basha.
if [ "$_kube_sourced" -eq 1 ]; then
    [ -f "$HOME/.kube/config" ] || (umask 077 && : > "$HOME/.kube/config")
    _kube_list="$HOME/.kube/config"
    # find zamiast globu: pusty glob w zsh przerywa zasourcowany skrypt („no matches").
    for _kube_f in $(find "$_kube_dir" -maxdepth 1 -name '*.yaml' 2>/dev/null | sort); do
        [ -f "$_kube_f" ] && _kube_list="$_kube_list:$_kube_f"
    done
    export KUBECONFIG="$_kube_list"
    echo "KUBECONFIG=$KUBECONFIG  (ustawione w tej powłoce)"
fi

# ── co dalej ──────────────────────────────────────────────────────────────────
echo
echo "== Dalej =="

if [ -f "$_kube_frag" ]; then
    _kube_link="$HOME/.config/zsh/rc.d/80-kube.zsh"
    if [ "$(readlink -f "$_kube_link" 2>/dev/null)" = "$(readlink -f "$_kube_frag")" ]; then
        echo "  nowe powłoki: aktywne (fragment dowiązany)"
    else
        # rc.d to katalog z osobnym dowiązaniem na każdy plik, więc nowy plik w repo
        # nie pojawi się w ~/.config, póki stow go nie zlinkuje.
        echo "  nowe powłoki: JESZCZE NIE — fragment nie jest dowiązany"
        echo "    ~/scripts/fedora/dotfiles/apply.sh"
    fi
else
    echo "  nie znalazłem $_kube_frag — nowe powłoki nie złożą KUBECONFIG same" >&2
fi

[ "$_kube_sourced" -eq 1 ] || echo "  ta powłoka:   nietknięta — source $_kube_self"
echo "  przełączenie: kubectl config use-context $_kube_ctx   (albo :ctx w k9s)"

[ -f "$_kube_file" ] || {
    echo
    echo "  uwaga: nie udało się pobrać $_kube_file"
    echo "    czy maszyna stoi? just cluster plan"
}

unset -f _kube_out
unset _kube_sourced _kube_self _kube_ctx _kube_root _kube_file _kube_dir _kube_frag \
    _kube_link _kube_ip _kube_user _kube_list _kube_f
