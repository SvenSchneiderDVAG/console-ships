#!/bin/zsh
mkdir -p bin

cd src
odin build . -debug -out:../bin/game && ../bin/game
