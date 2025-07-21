#!/bin/zsh
# This script builds the console_ships project in either debug or release mode.
# Usage: build.bat [debug|release]

[ ! -d "bin" ] && mkdir -p bin

if [ "$1" = "debug" ]; then
    [ ! -d "bin/debug" ] && mkdir -p bin/debug
    odin build src/. -debug -out:bin/debug/console_ships && bin/debug/console_ships
elif [ "$1" = "release" ]; then
    [ ! -d "bin/release" ] && mkdir -p bin/release
    odin build src/. -o:size -out:bin/release/console_ships && bin/release/console_ships
else
    echo "Usage: build.sh [debug|release]"
fi
