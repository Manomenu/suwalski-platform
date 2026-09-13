#!/usr/bin/env bash
# Nakładka. Cała logika jest w scripts/.internal/tofu.sh — tutaj tylko cel i akcja.
exec "$(dirname "$0")/../.internal/tofu.sh" validate platform "$@"
