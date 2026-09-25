# suwalski-platform — punkt wejścia.
#
#   just                  lista modułów
#   just <moduł>          polecenia modułu
#   just <moduł> <cel>    wykonanie, np. `just cluster plan`
#
# Moduły leżą w .just/, a bash, którego używają, w .just/lib/. W scripts/ zostaje tylko
# to, co uruchamiasz sam: `source`owanie (kubectl-setup.sh) i setup.sh, który instaluje
# just i rozprowadza sekrety — bo recepta just nie zmieni Twojej powłoki i nie zadziała,
# zanim just istnieje.

set shell := ["bash", "-euo", "pipefail", "-c"]

[private]
default:
    @just --justfile {{justfile()}} --list --unsorted --list-heading $'Moduły — `just <moduł>` pokazuje jego polecenia:\n'

[doc('Proxmox: maszyna wirtualna z k3s')]
[group('warstwy')]
mod cluster '.just/cluster.just'

[doc('Wnętrze klastra: Argo CD i aplikacja korzeniowa')]
[group('warstwy')]
mod platform '.just/platform.just'

[doc('Cloudflare: tunel, DNS i logowanie (Access) — wejście z internetu')]
[group('warstwy')]
mod edge '.just/edge.just'

[doc('Argo CD: hasło i stan aplikacji')]
[group('operacje')]
mod argo '.just/argo.just'

[doc('k9s: jego własny log')]
[group('operacje')]
mod k9s '.just/k9s.just'
