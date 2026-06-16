#!/bin/sh
# ref: https://github.com/grilme99/roblox-project-template/blob/main/scripts/dev.sh

# Stop execution if any tasks fail
set -e

# Creates the dist/ directory if darklua hasn't already created it
mkdir -p dist/

./scripts/copy-meta.sh

rojo serve build.project.json \
    & rojo sourcemap default.project.json -o sourcemap.json --watch \
    & ROBLOX_DEV=true darklua process --config .darklua.json --watch src/ dist/ \