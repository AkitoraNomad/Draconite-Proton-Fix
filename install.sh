#!/usr/bin/env bash
set -euo pipefail

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
base_name=GE-Proton11-12-x86_64
tool_name=Draconite-Proton-GE-11-12
kernelbase_dll=files/lib/wine/x86_64-windows/kernelbase.dll
dwrite_dll=files/lib/wine/x86_64-windows/dwrite.dll
symbols_font=Draconite-NotoSansSymbols2-Regular.ttf
font_license=Draconite-NotoSansSymbols2-OFL.txt
archive_url=https://github.com/GloriousEggroll/proton-ge-custom/releases/download/GE-Proton11-12/$base_name.tar.gz
archive_hash=0595159e417c3dbbfb7cc3ae0d3ed15a617cc607aa23ef756ea79029d7af5d70
original_kernelbase_hash=5e9bd056c20db78d8242a35df18871452d8fb1fb64b64f91a3d7c959a93ffac1
patched_kernelbase_hash=05dafd0770ee7312224ec4b49a7ccdf9efd8a167d0c705b7cb3550de5eb4653c
original_dwrite_hash=98e8cf104a3c83f91948f27ecbd497842e053fe88f682847d311b9008945c54d
patched_dwrite_hash=f3d27c2793a43d8f5ec8d9fcc1cf42acaae853d17b863dfe5a47be178c9faea2
symbols_font_hash=c4a0a80f0041ce4be81e2478faad22776d23edb98ae3f0d19bd37044820ecf9d
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
matches_hash "$package_dir/files/kernelbase.dll" "$patched_kernelbase_hash" || fail 'Packaged kernelbase.dll failed the SHA-256 check'
matches_hash "$package_dir/files/dwrite.dll" "$patched_dwrite_hash" || fail 'Packaged dwrite.dll failed the SHA-256 check'
matches_hash "$package_dir/files/$symbols_font" "$symbols_font_hash" || fail 'Packaged symbol font failed the SHA-256 check'
[[ -f "$package_dir/files/compatibilitytool.vdf" && -f "$package_dir/files/$font_license" ]] ||
    fail 'The package is incomplete. Download and extract the entire repository ZIP.'

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
mkdir -p -- "$tools_dir"

if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ ! -L "$destination" && -x "$destination/proton" ]] &&
        matches_hash "$destination/$kernelbase_dll" "$patched_kernelbase_hash" &&
        matches_hash "$destination/$dwrite_dll" "$patched_dwrite_hash" &&
        matches_hash "$destination/files/share/fonts/$symbols_font" "$symbols_font_hash" &&
        cmp -s -- "$destination/$font_license" "$package_dir/files/$font_license" &&
        cmp -s -- "$destination/compatibilitytool.vdf" "$package_dir/files/compatibilitytool.vdf"; then
        printf 'Already installed in %s\n' "$destination"
        printf 'Restart Steam and select %s for Draconite.\n' "$tool_name"
        exit 0
    fi
    fail "An older or different tool already exists at $destination. Exit Steam, move it outside $tools_dir, and rerun."
fi

stage=$(mktemp -d -- "$tools_dir/.draconite-install.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -- "$stage/tool"

base=
if [[ -z "$archive" ]]; then
    for candidate in "$tools_dir/$base_name" "$tools_dir/Proton-GE Latest"; do
        if [[ -x "$candidate/proton" && -f "$candidate/toolmanifest.vdf" && -d "$candidate/files/share/fonts" ]] &&
            matches_hash "$candidate/$kernelbase_dll" "$original_kernelbase_hash" &&
            matches_hash "$candidate/$dwrite_dll" "$original_dwrite_hash" &&
            matches_hash "$candidate/proton" "$proton_hash"; then
            base=$candidate
            break
        fi
    done
fi

if [[ -n "$base" ]]; then
    printf 'Reusing installed GE-Proton from %s\n' "$base"
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

matches_hash "$stage/tool/$kernelbase_dll" "$original_kernelbase_hash" || fail 'GE-Proton contains an unexpected original kernelbase.dll'
matches_hash "$stage/tool/$dwrite_dll" "$original_dwrite_hash" || fail 'GE-Proton contains an unexpected original dwrite.dll'
matches_hash "$stage/tool/proton" "$proton_hash" || fail 'GE-Proton contains an unexpected launcher'
[[ -x "$stage/tool/proton" && -f "$stage/tool/toolmanifest.vdf" && -d "$stage/tool/files/share/fonts" ]] ||
    fail 'The GE-Proton installation is incomplete'
install -m 644 -- "$package_dir/files/kernelbase.dll" "$stage/tool/$kernelbase_dll"
install -m 644 -- "$package_dir/files/dwrite.dll" "$stage/tool/$dwrite_dll"
install -m 644 -- "$package_dir/files/$symbols_font" "$stage/tool/files/share/fonts/$symbols_font"
install -m 644 -- "$package_dir/files/$font_license" "$stage/tool/$font_license"
install -m 644 -- "$package_dir/files/compatibilitytool.vdf" "$stage/tool/compatibilitytool.vdf"
mv -T --no-clobber -- "$stage/tool" "$destination"
[[ ! -e "$stage/tool" ]] || fail "Another installation created $destination"
printf 'Installed in %s\n' "$destination"
printf 'Restart Steam and select %s for Draconite.\n' "$tool_name"
