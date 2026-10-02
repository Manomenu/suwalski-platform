# The quality gate: `just check` is the same script CI runs on every push.

set positional-arguments
set shell := ["bash", "-euo", "pipefail", "-c"]

lib := justfile_directory() / ".just/lib"

# Unlike the other modules, `just check` alone runs the gate instead of listing commands:
# it is the command typed most often.
[doc('Everything that can be checked offline: formats, lints, schemas, repo rules, secrets')]
default:
    @{{ lib }}/check.sh offline

[doc('Against the real environment: each layer plans no changes, every Argo app synced and healthy')]
live:
    @{{ lib }}/check.sh live

[doc('Apply the formatters the gate checks: tofu fmt, shfmt, just --fmt')]
fmt:
    @{{ lib }}/check.sh fmt
