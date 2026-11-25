#!/bin/bash
#
# Checks that a built libCoreGraphics exports exactly the symbols in
# symbols.txt, each also under its Mach-O name (`_CGPathCreateMutable`), and
# otherwise only its own Swift API.
#
#   check_exports.sh <path to libCoreGraphics.so>

set -euo pipefail

library="${1:?the path to libCoreGraphics.so}"
SYMBOLS="$(cd "$(dirname "$0")" && pwd)/symbols.txt"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

grep -v '^#' "$SYMBOLS" | awk 'NF { print $1; print "_" $1 }' | sort -u > "$WORK/expected"
nm -D --defined-only "$library" | awk '{ print $NF }' | sed 's/@.*//' | sort -u > "$WORK/exported"

# the Swift API Perry uses
grep -v '^\$s21SilicaCoreGraphicsABI' "$WORK/exported" > "$WORK/exported-c" || true

missing="$(comm -23 "$WORK/expected" "$WORK/exported-c")"
extra="$(comm -13 "$WORK/expected" "$WORK/exported-c")"

if [ -n "$missing" ]; then
    echo "missing exports:"; echo "$missing"
fi
if [ -n "$extra" ]; then
    echo "unexpected exports:"; echo "$extra"
fi
[ -z "$missing" ] && [ -z "$extra" ] || exit 1
echo "$(wc -l < "$WORK/expected" | tr -d ' ') CoreGraphics exports, as listed"
