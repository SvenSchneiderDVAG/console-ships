:: This script builds the console_ships project in either debug or release mode.
:: Usage: build.bat [debug|release]
@echo off
if not exist bin mkdir bin

if "%1" == "debug" (
    odin build src/. -debug -out:bin/debug/console_ships.exe
    if %errorlevel% == 0 (
        bin/debug/console_ships.exe
    )
) else if "%1" == "release" (
    odin build src/. -o:speed -out:bin/release/console_ships.exe
    if %errorlevel% == 0 (
        bin/release/console_ships.exe
    )
) else (
    echo "Usage: build.bat [debug|release]"
)