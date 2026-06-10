#!/bin/sh
# ref: https://github.com/grilme99/roblox-project-template/blob/main/scripts/dev.sh

# Stop execution if any tasks fail
set -e

# If Packages aren't installed, install them.
if [ ! -d "Packages" ]; then
    sh scripts/install-packages.sh
fi

rojo serve build.project.json \
    & rojo sourcemap default.project.json -o sourcemap.json --watch \
    & ROBLOX_DEV=true darklua process --config .darklua.json --watch src/ dist/