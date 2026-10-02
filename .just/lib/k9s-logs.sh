#!/usr/bin/env bash
# Show the k9s log — the only place where k9s explains its decisions.
#
#   just k9s logs          last 40 lines
#   just k9s logs -f       follow live (handy in a second terminal)
#   just k9s logs -n 200   more history
#
# Two entries are worth telling apart, because on screen they look identical:
#   "No resources found for v1/pods in \"default\" namespace"  -> works, just empty
#   "No context configured"                                    -> does not know where the cluster is
set -euo pipefail

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/k9s/k9s.log"
LINES=40
FOLLOW=0

while [ $# -gt 0 ]; do
    case "$1" in
        -f|--follow) FOLLOW=1; shift ;;
        -n) LINES="${2:?-n requires a number}"; shift 2 ;;
        *) echo "unknown option: $1" >&2; echo "usage: $(basename "$0") [-f] [-n N]" >&2; exit 2 ;;
    esac
done

[ -f "$LOG" ] || {
    echo "missing $LOG" >&2
    echo "  k9s creates it on first run — start k9s and try again" >&2
    exit 1
}

echo "==> $LOG"

# k9s writes color codes into the log. They look fine in a terminal, but in a pipe they
# break grep, so we strip them there. `-t 1` checks whether the output is a terminal.
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
