#!/bin/bash

# Script to make every package available in all configured distributions.
#
# Packages are usually uploaded for a single Ubuntu release only (the
# .changes file carries e.g. "Distribution: noble"), so reprepro imports them
# into that distribution alone. The edulution packages are not tied to a
# specific Ubuntu release, therefore they are copied into every other
# distribution listed in conf/distributions as well - e.g. so that Ubuntu
# 26.04 (resolute) clients get the packages built for noble.
#
# A distribution-specific build always wins: if a package name already exists
# in a distribution, it is never overwritten by a copy from another one.

set -e

CODENAMES=$(awk '/^Codename:/ {print $2}' conf/distributions)

# Names of all packages currently present in a distribution.
packages_in() {
    reprepro list "$1" | awk '{print $2}' | sort -u
}

for dst in $CODENAMES; do
    for src in $CODENAMES; do
        [ "$src" = "$dst" ] && continue

        # Re-read after every source, so a package copied from an earlier
        # source is not copied a second time from a later one.
        existing=$(packages_in "$dst")

        for pkg in $(packages_in "$src"); do
            if grep -qxF "$pkg" <<< "$existing"; then
                echo "Skipping $pkg for $dst (already present)"
                continue
            fi
            echo "Copying $pkg from $src to $dst"
            reprepro -V copy "$dst" "$src" "$pkg"
        done
    done
done

echo "Distributions synchronised."
