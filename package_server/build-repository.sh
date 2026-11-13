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
# A build that is valid for more than one Ubuntu release is listed in
# conf/also-in. There is deliberately no automatic copy into every
# distribution any more: linuxmuster-linbo7 builds kernel and initrd from the
# release it was built on, so a resolute build must never end up in noble.

set -eo pipefail

CODENAMES="$(awk '/^Codename:/ {print $2}' conf/distributions)"
ALSO_IN=conf/also-in

known_codename() {
    grep -qxF "$1" <<< "$CODENAMES"
}

# conf/also-in without comments and blank lines.
also_in_entries() {
    grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$ALSO_IN"
}

# The codenames conf/also-in lists for one build, e.g. "edulution-fileproxy/noble".
also_in() {
    also_in_entries | awk -v build="$1" '$1 == build { for (i = 2; i <= NF; i++) print $i }'
}

# Fails on entries the import loop could not apply cleanly. A build that is not
# under packages/ only warns, so a package can be listed before its first
# upload has been merged.
check_also_in() {
    local build targets target failed=0

    while read -r build targets; do
        if [[ "$build" != */* ]] || [ -z "$targets" ]; then
            echo "::error::$ALSO_IN: malformed entry '$build${targets:+ $targets}'" >&2
            failed=1
            continue
        fi
        if ! known_codename "${build#*/}"; then
            echo "::error::$ALSO_IN: $build names unknown codename '${build#*/}'" >&2
            failed=1
        fi
        if [ ! -d "../packages/$build" ]; then
            echo "::warning::$ALSO_IN: $build is not under packages/, entry unused"
        fi
        for target in $targets; do
            if ! known_codename "$target"; then
                echo "::error::$ALSO_IN: $build lists unknown codename '$target'" >&2
                failed=1
            elif [ "$target" = "${build#*/}" ]; then
                echo "::error::$ALSO_IN: $build lists its own codename" >&2
                failed=1
            elif [ -d "../packages/${build%/*}/$target" ]; then
                # The copy and the separate build would replace each other.
                echo "::error::$ALSO_IN: $build lists $target, which has its own build under packages/" >&2
                failed=1
            fi
        done
    done < <(also_in_entries)

    return $failed
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

check_also_in || exit 1

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

    for target in $(also_in "$package/$codename"); do
        for name in $(package_names "${debs[@]}"); do
            echo "Copying $name from $codename to $target"
            reprepro -V copy "$target" "$codename" "$name"
        done
    done
done

[ "$found" = 1 ] || echo "No packages found, nothing imported"

reprepro -V export

# Create symlink so the legacy typo URL 'nobel' keeps working for clients that
# still have it in their sources.list.
ln -s noble dists/nobel

bash generate-package-json.sh
bash generate-indices.sh
