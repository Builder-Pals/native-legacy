#!/bin/sh

set -e

# Creates the dist/ directory if darklua hasn't already created it
mkdir -p dist/

./scripts/copy-meta.sh
rojo sourcemap build_default.project.json -o sourcemap.json
darklua process --config .darklua.json src/ dist/

echo built!