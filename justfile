# suwalski-platform — entry point.
#
#   just                  list of modules
#   just <module>         the module's commands
#   just <module> <cmd>   run one, e.g. `just cluster plan`
#
# Modules live in .just/, and the bash they use in .just/lib/. Only what you run yourself
# stays in scripts/: `source`d scripts (kubectl-setup.sh) and setup.sh, which installs
# just and distributes secrets — because a just recipe cannot change your shell and does
# not work before just exists.

set shell := ["bash", "-euo", "pipefail", "-c"]

[private]
default:
    @just --justfile {{justfile()}} --list --unsorted --list-heading $'Modules — `just <module>` shows its commands:\n'

[doc('Proxmox: virtual machine with k3s')]
[group('layers')]
mod cluster '.just/cluster.just'

[doc('Inside the cluster: Argo CD and the root application')]
[group('layers')]
mod platform '.just/platform.just'

[doc('Cloudflare: tunnel, DNS and login (Access) — entry from the internet')]
[group('layers')]
mod edge '.just/edge.just'

[doc('Argo CD: password and application status')]
[group('operations')]
mod argo '.just/argo.just'

[doc('k9s: its own log')]
[group('operations')]
mod k9s '.just/k9s.just'
