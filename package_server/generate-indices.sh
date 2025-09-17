#!/bin/bash

# Script to generate index.html files for directory browsing with dark theme

generate_index() {
    local dir="$1"
    local title="$(basename "$dir")"
    local parent_link=""
    
    # Add parent directory link if not in root
    if [ "$dir" != "." ]; then
        parent_link='<a href="../" class="parent-link">📁 Parent Directory</a>'
    fi
    
    cat > "$dir/index.html" << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Directory: TITLE_PLACEHOLDER</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1a1a1a 0%, #2d2d2d 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
            color: #ecf0f1;
        }

        .container {
            max-width: 900px;
            width: 100%;
            background: rgba(30, 30, 30, 0.95);
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
            backdrop-filter: blur(15px);
            border: 1px solid rgba(255, 255, 255, 0.1);
        }

        h1 {
            color: #ecf0f1;
            margin-bottom: 10px;
            font-size: 2em;
            display: flex;
            align-items: center;
            gap: 10px;
        }

        .path {
            color: #95a5a6;
            margin-bottom: 30px;
            font-family: 'Courier New', monospace;
            font-size: 0.9em;
        }

        .parent-link {
            display: inline-block;
            margin-bottom: 20px;
            color: #3498db;
            text-decoration: none;
            padding: 10px 15px;
            background: rgba(52, 152, 219, 0.1);
            border-radius: 5px;
            transition: all 0.3s;
        }

        .parent-link:hover {
            background: rgba(52, 152, 219, 0.2);
            transform: translateX(-5px);
        }

        .file-list {
            list-style: none;
        }

        .file-item {
            margin: 5px 0;
        }

        .file-link {
            display: flex;
            align-items: center;
            padding: 12px 15px;
            color: #ecf0f1;
            text-decoration: none;
            border-radius: 5px;
            transition: all 0.3s;
            border: 1px solid transparent;
        }

        .file-link:hover {
            background: rgba(52, 152, 219, 0.1);
            border-color: rgba(52, 152, 219, 0.3);
            transform: translateX(5px);
        }

        .file-icon {
            margin-right: 12px;
            font-size: 1.2em;
        }

        .file-name {
            flex-grow: 1;
        }

        .file-size {
            color: #7f8c8d;
            font-size: 0.9em;
            margin-left: auto;
            padding-left: 20px;
        }

        .file-date {
            color: #7f8c8d;
            font-size: 0.9em;
            margin-left: 20px;
            min-width: 150px;
            text-align: right;
        }

        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid rgba(255, 255, 255, 0.1);
            color: #95a5a6;
            font-size: 0.9em;
        }

        .stats {
            margin-top: 20px;
            padding: 15px;
            background: rgba(44, 62, 80, 0.3);
            border-radius: 5px;
            color: #95a5a6;
            font-size: 0.9em;
        }

        @media (max-width: 600px) {
            .file-size, .file-date {
                display: none;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📂 Directory: TITLE_PLACEHOLDER</h1>
        <div class="path">PATH_PLACEHOLDER</div>
        
        PARENT_LINK_PLACEHOLDER
        
        <ul class="file-list">
CONTENT_PLACEHOLDER
        </ul>
        
        <div class="stats">
            STATS_PLACEHOLDER
        </div>
        
        <div class="footer">
            Edulution Package Server | <a href="/" style="color: #3498db;">Home</a>
        </div>
    </div>
</body>
</html>
EOF

    # Replace placeholders
    sed -i "s|TITLE_PLACEHOLDER|$title|g" "$dir/index.html"
    sed -i "s|PATH_PLACEHOLDER|/$dir|g" "$dir/index.html"
    sed -i "s|PARENT_LINK_PLACEHOLDER|$parent_link|g" "$dir/index.html"
    
    # Generate content list
    local content=""
    local dir_count=0
    local file_count=0
    
    # Add directories first
    for item in "$dir"/*/ 2>/dev/null; do
        if [ -d "$item" ]; then
            name=$(basename "$item")
            if [ "$name" != "media" ]; then  # Skip media folder
                content+="            <li class=\"file-item\"><a href=\"$name/\" class=\"file-link\"><span class=\"file-icon\">📁</span><span class=\"file-name\">$name/</span></a></li>\n"
                ((dir_count++))
            fi
        fi
    done
    
    # Add files
    for item in "$dir"/* 2>/dev/null; do
        if [ -f "$item" ]; then
            name=$(basename "$item")
            size=$(du -h "$item" | cut -f1)
            date=$(date -r "$item" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "")
            
            # Choose icon based on file extension
            icon="📄"
            case "$name" in
                *.deb) icon="📦" ;;
                *.gpg|*.key) icon="🔐" ;;
                *.gz|*.xz|*.bz2) icon="🗜️" ;;
                *.html) icon="🌐" ;;
                Packages*) icon="📋" ;;
                Release*|InRelease*) icon="📝" ;;
            esac
            
            # Don't link to index.html itself
            if [ "$name" != "index.html" ]; then
                content+="            <li class=\"file-item\"><a href=\"$name\" class=\"file-link\"><span class=\"file-icon\">$icon</span><span class=\"file-name\">$name</span><span class=\"file-size\">$size</span><span class=\"file-date\">$date</span></a></li>\n"
                ((file_count++))
            fi
        fi
    done
    
    # Replace content
    sed -i "s|CONTENT_PLACEHOLDER|$content|" "$dir/index.html"
    
    # Add stats
    local stats="$dir_count directories, $file_count files"
    sed -i "s|STATS_PLACEHOLDER|$stats|g" "$dir/index.html"
    
    echo "Generated index for: $dir"
}

# Generate indices for main directories
echo "Generating directory indices..."

# Main directories
for dir in dists pool; do
    if [ -d "$dir" ]; then
        # Generate index for main directory
        generate_index "$dir"
        
        # Generate for subdirectories
        find "$dir" -type d | while read -r subdir; do
            generate_index "$subdir"
        done
    fi
done

# Generate root index if needed (but don't overwrite custom index.html)
if [ ! -f "index.html" ]; then
    generate_index "."
fi

echo "Directory indices generated successfully!"