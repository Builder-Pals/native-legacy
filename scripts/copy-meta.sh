# scripts/copy-meta.sh
#!/usr/bin/env bash

find src -type f -name '*.meta.json' | while read -r file; do
    target="dist/${file#src/}"
    mkdir -p "$(dirname "$target")"
    cp "$file" "$target"
    printf "meta files copied\n"
done