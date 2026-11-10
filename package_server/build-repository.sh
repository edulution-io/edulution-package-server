#!/bin/bash

# Builds the APT repository from the packages under ../packages: validates and
# imports them and writes the landing page data. Run from package_server/.
# reprepro signs with the key conf/distributions names, so import it first, or
# drop SignWith for an unsigned build.
#
# The directory a package sits in names the distribution it is published to:
#
#     packages/<package-name>/<codename>/
#
# A package that is valid for more than one Ubuntu release says so itself, in
# an "also-in" file next to the .deb. There is deliberately no automatic copy
# into every distribution any more: linuxmuster-linbo7 builds kernel and
# initrd from the release it was built on, so a resolute build must never end
# up in noble.

set -eo pipefail

CODENAMES="$(awk '/^Codename:/ {print $2}' conf/distributions)"

known_codename() {
    grep -qxF "$1" <<< "$CODENAMES"
}

# All binary package names a set of .deb files carries. A "copy" works on the
# package name, and one directory can hold several of them (sophomorix4) as
# well as several architectures of one name (edulution-fileproxy).
package_names() {
    local deb
    for deb in "$@"; do
        dpkg-deb -f "$deb" Package
    done | sort -u
}

shopt -s nullglob

found=0
for dir in ../packages/*/*/; do
    dir="${dir%/}"
    codename="$(basename "$dir")"
    package="$(basename "$(dirname "$dir")")"

    if ! known_codename "$codename"; then
        echo "::error::$package: '$codename' is not a codename in conf/distributions" >&2
        exit 1
    fi

    debs=("$dir"/*.deb)
    dscs=("$dir"/*.dsc)
    if [ ${#debs[@]} -eq 0 ] && [ ${#dscs[@]} -eq 0 ]; then
        echo "No packages in $package/$codename, skipping"
        continue
    fi
    found=1

    # Refuse to publish packages whose checksums do not match or that lintian
    # rejects.
    bash validate-incoming.sh "$dir"

    [ ${#debs[@]} -eq 0 ] || reprepro -V includedeb "$codename" "${debs[@]}"
    for dsc in "${dscs[@]}"; do
        reprepro -V includedsc "$codename" "$dsc"
    done

    [ -f "$dir/also-in" ] || continue

    while read -r target; do
        if ! known_codename "$target"; then
            echo "::error::$package/$codename/also-in names unknown codename '$target'" >&2
            exit 1
        fi
        for name in $(package_names "${debs[@]}"); do
            echo "Copying $name from $codename to $target"
            reprepro -V copy "$target" "$codename" "$name"
        done
    done < <(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$dir/also-in")
done

[ "$found" = 1 ] || echo "No packages found, nothing imported"

reprepro -V export

# Create symlink so the legacy typo URL 'nobel' keeps working for clients that
# still have it in their sources.list.
ln -s noble dists/nobel

bash generate-package-json.sh
bash generate-indices.sh
