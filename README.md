# Console-Ships - a Battle-Ships clone for terminal/console

This game is a result of me trying to learn the [Odin](https://odin-lang.org) language by GingerBill.

The game is playable but I could think of some extra features and more optimizations, so I probably will commit some changes in the future. Therefore it's work in progress.

It does compile on Windows, OSX and Linux.

## Gameplay

As for now player plays vs. computer and player will always go first.

Like in real battle ships board game you have to place 5 ships on a map of 10x10 grid.

Name and Length of ships:

1. Carrier (5)
2. Battleship (4)
3. Cruiser (3)
4. Submarine (3)
5. Destroyer (2)

Ships are not allowed to place diagonal or adjacent to another ship, there has to be a minimum of one
empty cell between them.

Placing the ships work like `a1h` where `a` is the column and `1` the row. `h` means horizontal, `v` means vertical. So a carrier ship with a lenght of 5 would be placed vrom a1 to e1 horinzontal by typing in `a1h` You can also chose to type in `auto` so your ships will be placed randomly on the board.

After placing the ships you have to type in where you want to shoot at ... for e.g. `g5`.

If you hit a ship, you can continue shooting as long as your shots don't miss.
If you miss, computer is at turn. If the ship you were shooting at has sunk, you can choose a new  cell to shoot at.

Same rules go for computer's turns.

The game is considered won when either player or computer has sunk all ships.

You can type `q` at every time to either quit or start a new game.

### How to build the game

I've provided two build files for Windows and OSX.

* Windows: build.bat
  Usage: `build.bat debug` or `build.bat release`
* OSX and Linux: build.sh
  Usage: `./build.sh debug`or `./build.sh release`

Both files will also start the game automatically after succesful build.
The executables can be found in either bin/debug or bin/release folders.
