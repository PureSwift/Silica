#!/bin/bash
#
# Runs the CoreGraphics conformance programs in Conformance/CoreGraphics.
#
#   conformance.sh record
#       On macOS: builds each program against Apple's CoreGraphics and writes
#       what it prints to Conformance/CoreGraphics/expected/<program>.txt.
#
#   conformance.sh check <library directory> [library name]
#       Builds each program against Silica's headers and libCoreGraphics
#       (or the named library, e.g. SilicaCoreGraphicsABI for SwiftPM's) in
#       the directory, runs it, and compares what it prints with the
#       recorded output. Lines listed in expected/<program>.differences are
#       known differences: a line there is the output line Silica prints,
#       accepted in place of Apple's. Exits nonzero on any other difference.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCES="$ROOT/Conformance/CoreGraphics"
EXPECTED="$SOURCES/expected"
CC="${CC:-cc}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mode="${1:-}"
case "$mode" in
record)
    [ "$(uname)" = Darwin ] || { echo "record runs on macOS, against Apple's CoreGraphics" >&2; exit 1; }
    mkdir -p "$EXPECTED"
    for source in "$SOURCES"/*.c; do
        name="$(basename "$source" .c)"
        "$CC" -std=gnu11 -O0 -DCONFORMANCE_FONTS="\"$SOURCES/fonts\"" -o "$WORK/$name" "$source" -framework CoreGraphics
        "$WORK/$name" > "$EXPECTED/$name.txt"
        echo "recorded $name"
    done
    ;;
check)
    libdir="${2:?the directory with the library}"
    library="${3:-CoreGraphics}"
    failed=0
    for source in "$SOURCES"/*.c; do
        name="$(basename "$source" .c)"
        "$CC" -std=gnu11 -O0 -DCONFORMANCE_FONTS="\"$SOURCES/fonts\"" -o "$WORK/$name" "$source" \
            -I "$ROOT/Sources/CSilicaCoreGraphics/include" \
            -L "$libdir" -l"$library" -lm -Wl,-rpath,"$libdir"
        "$WORK/$name" > "$WORK/$name.txt"
        known="$EXPECTED/$name.differences"
        if diff -u "$EXPECTED/$name.txt" "$WORK/$name.txt" > "$WORK/$name.diff"; then
            echo "conforms: $name"
        else
            # a difference is accepted when Silica's line is a known difference
            unexplained=$(grep '^+[^+]' "$WORK/$name.diff" | sed 's/^+//' | \
                { if [ -f "$known" ]; then grep -vxF -f <(grep -v '^#' "$known" | grep -v '^$'); else cat; fi; } || true)
            if [ -z "$unexplained" ]; then
                echo "conforms, with known differences: $name"
            else
                echo "differs: $name"
                cat "$WORK/$name.diff"
                failed=1
            fi
        fi
    done
    exit "$failed"
    ;;
*)
    echo "usage: $0 record | check <library directory> [library name]" >&2
    exit 2
    ;;
esac
