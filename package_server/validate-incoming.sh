#!/bin/bash

# Validates the packages staged in incoming/ before reprepro imports them.
#
# reprepro treats a .changes file as a plain manifest: it does not verify the
# checksums it lists and does not require a signature. Anything a package
# build pushes into packages/ would therefore reach clients unchecked, so the
# two checks below run first.

set -eo pipefail

INCOMING="${1:-incoming}"
ALLOWLIST="${2:-lintian-allowlist}"

# Prints the continuation lines of a deb822 multi-line field, e.g. the file
# entries under "Checksums-Sha256:".
field_lines() {
    awk -v field="$2" '
        /^[^ \t]/ { in_field = (tolower($0) ~ "^" tolower(field) ":") }
        /^[ \t]/  { if (in_field) print }
    ' "$1"
}

# Compares the checksums a .changes lists against the files next to it. A
# .changes without SHA-256 is rejected outright: it is mandatory for format
# 1.8, and its absence means the file was hand-assembled rather than produced
# by dpkg-genchanges.
verify_changes() {
    local changes="$1"
    local dir algo cmd field sum name actual failed=0

    dir=$(dirname "$changes")

    if [ -z "$(field_lines "$changes" Checksums-Sha256)" ]; then
        echo "::error::$(basename "$changes") carries no Checksums-Sha256 field" >&2
        return 1
    fi

    for algo in Md5 Sha1 Sha256; do
        case "$algo" in
            Md5)    cmd=md5sum ;;
            Sha1)   cmd=sha1sum ;;
            Sha256) cmd=sha256sum ;;
        esac

        [ "$algo" = Md5 ] && field=Files || field="Checksums-$algo"

        # "Files:" is the md5 field; the other two are "Checksums-<algo>:".
        # Files: lists "<md5> <size> <section> <priority> <filename>" while
        # the Checksums fields omit section and priority, so take the
        # checksum from the front and the filename from the back.
        while read -r sum name; do
            if [ ! -f "$dir/$name" ]; then
                echo "::error::$(basename "$changes") lists $name, which is not present" >&2
                failed=1
                continue
            fi

            actual=$("$cmd" "$dir/$name" | awk '{print $1}')
            if [ "$actual" != "$sum" ]; then
                echo "::error::$name: $algo mismatch (expected $sum, got $actual)" >&2
                failed=1
            fi
        done < <(field_lines "$changes" "$field" | awk '{print $1, $NF}')
    done

    return $failed
}

shopt -s nullglob

changes_files=("$INCOMING"/*.changes)
deb_files=("$INCOMING"/*.deb)

if [ ${#deb_files[@]} -eq 0 ]; then
    echo "No packages in $INCOMING, nothing to validate."
    exit 0
fi

echo "Verifying checksums ..."
status=0
for changes in "${changes_files[@]}"; do
    if verify_changes "$changes"; then
        echo "  OK  $(basename "$changes")"
    else
        status=1
    fi
done

echo
echo "Running lintian, ignoring these allowlisted tags:"
grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$ALLOWLIST" | sed 's/^/  /'
echo

for deb in "${deb_files[@]}"; do
    if lintian --tag-display-limit 0 --fail-on error \
        --suppress-tags-from-file "$ALLOWLIST" "$deb"; then
        echo "  OK  $(basename "$deb")"
    else
        echo "::error::$(basename "$deb") failed lintian" >&2
        status=1
    fi
done

if [ $status -ne 0 ]; then
    echo
    echo "Validation failed, refusing to publish." >&2
    exit 1
fi

echo
echo "All incoming packages validated."
