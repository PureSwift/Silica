#!/bin/sh
#
# Builds the Swift modules SilicaCairo imports (PureSwift/FontConfig and
# PureSwift/Cairo) as shared libraries in a directory, for the CMake build
# to find with `-I <dir> -L <dir>`. They have no CMake build of their own,
# so this compiles their sources directly.
#
#   build-cairo-modules.sh <output directory> [<work directory>]

set -eu

out=$1
work=${2:-${TMPDIR:-/tmp}/silica-cairo-modules}
mkdir -p "$out" "$work"

case "$(uname -s)" in
  Darwin) suffix=dylib ;;
  *) suffix=so ;;
esac

clone() {
  [ -d "$work/$1" ] || git clone --depth 1 "https://github.com/PureSwift/$1.git" "$work/$1"
}

# pkg-config's compiler flags, for the C headers the modules wrap.
xcc() {
  for flag in $(pkg-config --cflags "$@"); do
    printf -- '-Xcc %s ' "$flag"
  done
}

# Puts a C module where `-I <out>` finds it, as <out>/<name>/module.modulemap.
cmodule() {
  mkdir -p "$out/$2"
  cp "$work/$1/Sources/$2/module.modulemap" "$work/$1/Sources/$2/shim.h" "$out/$2/"
}

# Compiles a Swift module's sources into lib<name> and <name>.swiftmodule.
module() {
  repository=$1
  name=$2
  shift 2
  # shellcheck disable=SC2046
  swiftc -emit-library -emit-module -parse-as-library -swift-version 6 -O \
    -module-name "$name" -module-link-name "$name" \
    -emit-module-path "$out/$name.swiftmodule" \
    -o "$out/lib$name.$suffix" \
    -I "$out" -L "$out" \
    $(xcc cairo fontconfig freetype2) \
    "$@" \
    "$work/$repository/Sources/$name"/*.swift
}

clone FontConfig
clone Cairo

cmodule FontConfig CFontConfig
cmodule Cairo CCairo
cmodule Cairo CFreeType

# shellcheck disable=SC2046
module FontConfig FontConfig $(pkg-config --libs fontconfig freetype2)
# shellcheck disable=SC2046
module Cairo Cairo -lFontConfig $(pkg-config --libs cairo fontconfig freetype2)
