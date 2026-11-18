#!/usr/bin/env bash
set -euo pipefail

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
base_name=GE-Proton11-12-x86_64
tool_name=Draconite-Proton-GE-11-12
dll=files/lib/wine/x86_64-windows/kernelbase.dll
archive_url=https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-12/$base_name.tar.gz
archive_hash=0595159e417c3dbbfb7cc3ae0d3ed15a617cc607aa23ef756ea79029d7af5d70
original_hash=5e9bd056c20db78d8242a35df18871452d8fb1fb64b64f91a3d7c959a93ffac1
patched_hash=05dafd0770ee7312224ec4b49a7ccdf9efd8a167d0c705b7cb3550de5eb4653c
proton_hash=873d311b25b9252bf95f7030d24b01b79de643481dc4bb47bbdd137994b95072
steam_root=
archive=

usage() {
    printf '%s\n' 'Usage: bash install.sh [--steam-root DIR] [--archive GE-Proton11-12-x86_64.tar.gz]'
}

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

matches_hash() {
    local result
    [[ -f "$1" && ! -L "$1" ]] || return 1
    result=$(sha256sum < "$1") || return 1
    [[ "${result%% *}" == "$2" ]]
}

while (( $# )); do
    case "$1" in
        --steam-root)
            (( $# >= 2 )) || fail '--steam-root requires a directory'
            steam_root=$2
            shift 2
            ;;
        --archive)
            (( $# >= 2 )) || fail '--archive requires a file'
            archive=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "Unknown option $1"
            ;;
    esac
done

[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || fail 'This package requires x86-64 Linux'
[[ $EUID -ne 0 ]] || fail 'Run this as your Steam user'
matches_hash "$package_dir/files/kernelbase.dll" "$patched_hash" || fail 'Packaged DLL failed the SHA-256 check'
[[ -f "$package_dir/files/compatibilitytool.vdf" ]] || fail 'Extract the entire ZIP before running the installer'

if [[ -z "$steam_root" ]]; then
    for candidate in "${XDG_DATA_HOME:-$HOME/.local/share}/Steam" "$HOME/.steam/root" "$HOME/.steam/steam"; do
        if [[ -d "$candidate/steamapps" ]]; then
            steam_root=$candidate
            break
        fi
    done
    flatpak_root=$HOME/.var/app/com.valvesoftware.Steam/data/Steam
    if [[ -d "$flatpak_root/steamapps" ]]; then
        [[ -z "$steam_root" ]] || fail 'Both native and Flatpak Steam found. Choose one with --steam-root.'
        steam_root=$flatpak_root
    fi
fi
[[ -n "$steam_root" && -d "$steam_root/steamapps" ]] || fail 'Steam library not found. Run Steam once or pass its data directory with --steam-root.'

tools_dir=$steam_root/compatibilitytools.d
destination=$tools_dir/$tool_name
base=$tools_dir/$base_name
mkdir -p -- "$tools_dir"

if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ ! -L "$destination" && -x "$destination/proton" ]] &&
        matches_hash "$destination/$dll" "$patched_hash" &&
        cmp -s -- "$destination/compatibilitytool.vdf" "$package_dir/files/compatibilitytool.vdf"; then
        printf 'Already installed in %s\n' "$destination"
        printf 'Restart Steam and select %s for Draconite.\n' "$tool_name"
        exit 0
    fi
    fail "A different tool already exists at $destination. Move that directory aside and rerun."
fi

stage=$(mktemp -d -- "$tools_dir/.draconite-install.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -- "$stage/tool"

if [[ -z "$archive" ]] && matches_hash "$base/$dll" "$original_hash" && matches_hash "$base/proton" "$proton_hash"; then
    printf 'Reusing installed %s\n' "$base_name"
    cp -a --reflink=auto -- "$base/." "$stage/tool/"
else
    if [[ -z "$archive" ]]; then
        command -v curl >/dev/null || fail 'Install curl or use --archive with the official download'
        archive=$stage/$base_name.tar.gz
        printf 'Downloading official %s (about 541 MiB)\n' "$base_name"
        curl --fail --location --retry 2 --output "$archive" "$archive_url"
    fi
    matches_hash "$archive" "$archive_hash" || fail 'GE-Proton archive failed the SHA-256 check'
    tar -xzf "$archive" --strip-components=1 -C "$stage/tool"
fi

matches_hash "$stage/tool/$dll" "$original_hash" || fail 'GE-Proton contains an unexpected original kernelbase.dll'
matches_hash "$stage/tool/proton" "$proton_hash" || fail 'GE-Proton contains an unexpected launcher'
[[ -x "$stage/tool/proton" && -f "$stage/tool/toolmanifest.vdf" ]] || fail 'The GE-Proton installation is incomplete'
install -m 644 -- "$package_dir/files/kernelbase.dll" "$stage/tool/$dll"
install -m 644 -- "$package_dir/files/compatibilitytool.vdf" "$stage/tool/compatibilitytool.vdf"
mv -T --no-clobber -- "$stage/tool" "$destination"
[[ ! -e "$stage/tool" ]] || fail "Another installation created $destination"
printf 'Installed in %s\n' "$destination"
printf 'Restart Steam and select %s for Draconite.\n' "$tool_name"
