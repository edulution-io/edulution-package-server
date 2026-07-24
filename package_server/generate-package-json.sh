#!/bin/bash

# Script to generate a packages.json file from the reprepro Packages indices.
#
# All distributions under dists/ are scanned, so the package list on the
# landing page is not tied to a single Ubuntu release. Symlinked distribution
# directories (e.g. dists/noble -> nobel) are skipped automatically because
# `find` does not descend into symlinked directories, which keeps the list
# free of duplicates.

echo "Generating packages.json..."

# Collect every binary Packages index across all distributions/components.
mapfile -t PACKAGES_FILES < <(find dists -type f -path '*/binary-*/Packages' 2>/dev/null | sort)

if [ ${#PACKAGES_FILES[@]} -eq 0 ]; then
    echo "[]" > packages.json
    echo "No Packages files found, created empty packages.json"
    exit 0
fi

# Parse all Packages files and generate JSON. Each distribution is derived
# from the path (dists/<codename>/...) and added as a "dist" field so the
# landing page can show which Ubuntu release a package belongs to.
cat > packages.json << 'EOF'
[
EOF

first=true
declare -A SEEN
emit_entry() {
    # Skip incomplete blocks (no package name).
    [ -z "$package_name" ] && return
    # Architecture-independent packages ("Architecture: all") are listed in
    # every binary-<arch> index of a distribution, so the same package would
    # otherwise show up once per architecture. Emit each distinct entry once.
    local key="$dist|$package_name|$version|$arch|$filename"
    [ -n "${SEEN[$key]}" ] && return
    SEEN[$key]=1
    if [ "$first" = false ]; then
        echo "    }," >> packages.json
    fi
    first=false
    echo "    {" >> packages.json
    echo "        \"name\": \"$package_name\"," >> packages.json
    echo "        \"version\": \"$version\"," >> packages.json
    echo "        \"architecture\": \"$arch\"," >> packages.json
    echo "        \"dist\": \"$dist\"," >> packages.json
    echo "        \"size\": \"$size\"," >> packages.json
    echo "        \"filename\": \"/$filename\"" >> packages.json
}

for pkg_file in "${PACKAGES_FILES[@]}"; do
    # dists/<codename>/<component>/binary-<arch>/Packages -> <codename>
    dist=$(echo "$pkg_file" | sed -E 's|^dists/([^/]+)/.*|\1|')
    # Normalise the legacy typo codename for display (the real dir is "nobel",
    # exposed to users as "noble" via AlsoAcceptFor and a symlink).
    [ "$dist" = "nobel" ] && dist="noble"

    package_name="" version="" arch="" size="" filename=""
    while IFS= read -r line; do
        if [[ "$line" == "Package: "* ]]; then
            emit_entry
            package_name="${line#Package: }"
            version="" arch="" size="" filename=""
        elif [[ "$line" == "Version: "* ]]; then
            version="${line#Version: }"
        elif [[ "$line" == "Architecture: "* ]]; then
            arch="${line#Architecture: }"
        elif [[ "$line" == "Size: "* ]]; then
            size="${line#Size: }"
        elif [[ "$line" == "Filename: "* ]]; then
            filename="${line#Filename: }"
        fi
    done < "$pkg_file"
    emit_entry
done

if [ "$first" = false ]; then
    echo "    }" >> packages.json
fi

echo "]" >> packages.json

# Validate JSON (if jq is available)
if command -v jq &> /dev/null; then
    jq . packages.json > packages.json.tmp && mv packages.json.tmp packages.json
    echo "packages.json generated and validated successfully!"
else
    echo "packages.json generated successfully!"
fi
