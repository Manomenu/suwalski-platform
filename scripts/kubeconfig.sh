#!/usr/bin/env bash
# Ściągnij kubeconfig z węzła i sprawdź, że działa.
#
# Plik ląduje zawsze w tym samym miejscu — w korzeniu repo, gdzie .gitignore go pilnuje.
# Stała ścieżka jest celowa: dzięki niej da się raz ustawić KUBECONFIG w powłoce i nie
# wracać do tematu.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF="$ROOT/terraform"
DEST="$ROOT/kubeconfig"

# Adres bierzemy z Terraforma, żeby nie powielać go w skrypcie. -raw na pojedynczej
# wartości; stderr zostaje oddzielony, bo tofu wypisuje tam ostrzeżenia.
ip="$(cd "$TF" && tofu output -raw vm_ip 2>/dev/null)" || {
    echo "nie udało się odczytać vm_ip z tofu — czy infrastruktura stoi?" >&2
    exit 1
}
user="$(cd "$TF" && tofu output -raw vm_user 2>/dev/null || echo maniumek)"

echo "==> pobieram z $user@$ip"
scp -q "$user@$ip:~/.kube/config" "$DEST"
chmod 600 "$DEST"

echo "==> sprawdzam"
KUBECONFIG="$DEST" kubectl get nodes 2>&1 | sed 's/^/    /'

cat <<MSG

Ustaw w bieżącej powłoce:

  export KUBECONFIG=$DEST

Na stałe — dopisz tę linię do ~/.dotfiles/fedora/.config/zsh/rc.d/ (np. 80-kube.zsh).
MSG
