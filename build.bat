@echo off

cd src
odin build . -out:../bin/game.exe
cd ../bin
game.exe
