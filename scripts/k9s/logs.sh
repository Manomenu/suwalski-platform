#!/usr/bin/env bash
# Pokaż log k9s — jedyne miejsce, w którym k9s tłumaczy się ze swoich decyzji.
#
#   ./scripts/k9s/logs.sh          ostatnie 40 linii
#   ./scripts/k9s/logs.sh -f       śledź na żywo (przydatne przy drugim terminalu)
#   ./scripts/k9s/logs.sh -n 200   więcej historii
#
# Dwa wpisy warto umieć rozróżnić, bo na ekranie wyglądają identycznie:
#   "No resources found for v1/pods in \"default\" namespace"  -> działa, tylko pusto
#   "No context configured"                                    -> nie wie, gdzie jest klaster
set -euo pipefail

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/k9s/k9s.log"
LINES=40
FOLLOW=0

while [ $# -gt 0 ]; do
    case "$1" in
        -f|--follow) FOLLOW=1; shift ;;
        -n) LINES="${2:?-n wymaga liczby}"; shift 2 ;;
        *) echo "nieznana opcja: $1" >&2; echo "użycie: $(basename "$0") [-f] [-n N]" >&2; exit 2 ;;
    esac
done

[ -f "$LOG" ] || {
    echo "brak $LOG" >&2
    echo "  k9s tworzy go przy pierwszym uruchomieniu — odpal k9s i spróbuj ponownie" >&2
    exit 1
}

echo "==> $LOG"

# k9s zapisuje do logu kody kolorów. W terminalu wyglądają dobrze, ale w potoku psują
# grepa, więc tam je zdejmujemy. `-t 1` sprawdza, czy wyjście jest terminalem.
if [ -t 1 ]; then
    strip() { cat; }
else
    strip() { sed -E 's/\x1b\[[0-9;]*m//g'; }
fi

if [ "$FOLLOW" -eq 1 ]; then
    tail -n "$LINES" -f "$LOG" | strip
else
    tail -n "$LINES" "$LOG" | strip
fi
