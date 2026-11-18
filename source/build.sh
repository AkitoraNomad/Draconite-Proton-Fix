#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output_dir=${1:-"$PWD/wine-draconite-build"}
mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
mkdir -- "$output_dir/src" "$output_dir/build"
tar -xzf "$source_dir/wine-fda79a5.tar.gz" --strip-components=1 -C "$output_dir/src"
patch -d "$output_dir/src" -p1 < "$source_dir/ge-version-info.patch"
patch -d "$output_dir/src" -p1 < "$source_dir/Draconite-thread-priority.patch"
(
    cd "$output_dir/src"
    ./autogen.sh
)
(
    cd "$output_dir/build"
    ../src/configure --enable-archs=i386,x86_64 --disable-tests --without-x --without-wayland
    make -j"${JOBS:-4}" dlls/kernelbase/x86_64-windows/kernelbase.dll
)
printf '%s\n' "$output_dir/build/dlls/kernelbase/x86_64-windows/kernelbase.dll"
