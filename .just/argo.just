# Argo CD w klastrze homelab. Zawsze przez kubeconfig tego repo, nie przez KUBECONFIG
# z powłoki — ten złożony z wielu klastrów celuje w ten, który akurat jest wybrany.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

root := justfile_directory()

[private]
default:
    @just --justfile {{justfile()}} --list argo --unsorted --list-heading $'Polecenia — `just argo <polecenie>`:\n'

[doc('Hasło początkowe użytkownika admin')]
password:
    @{{root}}/.just/lib/argocd-password.sh

[doc('Aplikacje: czy zgadzają się z gitem (sync) i czy działają (health)')]
apps:
    @kubectl --kubeconfig {{root}}/kubeconfig -n argocd get applications \
        -o custom-columns='NAZWA:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,WERSJA:.status.sync.revision'
