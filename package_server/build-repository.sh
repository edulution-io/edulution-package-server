#!/bin/bash

# Builds the APT repository from the packages under ../packages: validates and
# imports them, makes them available in every distribution and writes the
# landing page data. Run from package_server/. reprepro signs with the key
# conf/distributions names, so import it first, or drop SignWith for an
# unsigned build.

set -eo pipefail

mkdir incoming

if [ -n "$(find ../packages -type f -name '*.deb' 2>/dev/null)" ]; then
    cp ../packages/*/*/* incoming/

    # Refuse to publish packages whose checksums do not match or that lintian
    # rejects.
    bash validate-incoming.sh

    reprepro -V processincoming default
else
    echo "No packages found, skipping processincoming"
fi

# Make every package available in all configured Ubuntu releases (packages are
# usually uploaded for a single codename only).
bash sync-distributions.sh

reprepro -V export

# Create symlink so the legacy typo URL 'nobel' keeps working for clients that
# still have it in their sources.list.
ln -s noble dists/nobel

bash generate-package-json.sh
bash generate-indices.sh
