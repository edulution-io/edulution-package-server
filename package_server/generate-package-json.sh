#!/bin/bash

# Script to generate a packages.json file from the Packages file

echo "Generating packages.json..."

# Check if Packages file exists
PACKAGES_FILE="dists/nobel/main/binary-amd64/Packages"

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "[]" > packages.json
    echo "No Packages file found, created empty packages.json"
    exit 0
fi

# Parse Packages file and generate JSON
cat > packages.json << 'EOF'
[
EOF

first=true
while IFS= read -r line; do
    if [[ "$line" == "Package: "* ]]; then
        if [ "$first" = false ]; then
            echo "    }," >> packages.json
        fi
        first=false
        echo "    {" >> packages.json
        package_name="${line#Package: }"
        echo "        \"name\": \"$package_name\"," >> packages.json
    elif [[ "$line" == "Version: "* ]]; then
        version="${line#Version: }"
        echo "        \"version\": \"$version\"," >> packages.json
    elif [[ "$line" == "Architecture: "* ]]; then
        arch="${line#Architecture: }"
        echo "        \"architecture\": \"$arch\"," >> packages.json
    elif [[ "$line" == "Size: "* ]]; then
        size="${line#Size: }"
        echo "        \"size\": \"$size\"," >> packages.json
    elif [[ "$line" == "Filename: "* ]]; then
        filename="${line#Filename: }"
        echo "        \"filename\": \"/$filename\"" >> packages.json
    fi
done < "$PACKAGES_FILE"

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