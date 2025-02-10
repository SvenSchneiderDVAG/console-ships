#!/bin/zsh
mkdir -p bin

cd src
odin build . -out:../bin/game && ../bin/game
