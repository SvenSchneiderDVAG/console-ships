package main

import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

OUT_OF_BOUNDS :: "\nShip would go off board! Try again.\n"
INVALID_PLACEMENT :: "\nInvalid placement! Try again.\n"
CLOSE_SHIP_DBG :: "\nShip is too close to another ship! Try again.\n"
PLACED_SHIPS_DBG :: "\n%v's ships placed in %v\n"

ALL_SHIPS_PLACED :: "\nAll ships have been placed - let the Battle begin!\n\n"
PLACE_SHIP :: "\nPlacing %v (size %d)\n\n"
ENTER_COORDINATES :: "Enter coordinates (e.g. a1h or g4v) or 'auto' to place your ships automatically: "

make_board :: proc(board: ^Board) {
	board.row = GRID_SIZE
	board.column = GRID_SIZE

	for i in 0 ..< GRID_SIZE {
		for j in 0 ..< GRID_SIZE {
			board.cells[i][j] = "."
		}
	}
}

display_board :: proc(title: string, board: ^Board) {
	fmt.println(title, "\n")

	// Print column headers (A-H)
	fmt.print("     ") // Space for column numbers
	for j in 0 ..< GRID_SIZE {
		fmt.printf("%c ", 'A' + j)
		fmt.printf(" ")
	}
	fmt.println("\n")

	// Print rows with numbers and cells
	for i in 0 ..< board.row {
		fmt.printf("%d   ", i + 1)
		if i + 1 != 10 {fmt.printf(" ")} 	// Space for single digit numbers
		for j in 0 ..< board.column {
			fmt.print(board.cells[i][j], " ")
		}
		fmt.println()
	}
	fmt.println()
}

is_valid_placement :: proc(board: ^Board, x, y, size: int, vertical: bool) -> bool {
	//Check bounds
	if x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE {
		debug_print(INVALID_PLACEMENT)
		return false
	}

	if (vertical && y + size > GRID_SIZE) || (!vertical && x + size > GRID_SIZE) {
		debug_print(OUT_OF_BOUNDS)
		return false
	}

	for i in -1 ..= size {
		for j in -1 ..= 1 {
			check_x := vertical ? x + j : x + i
			check_y := vertical ? y + i : y + j

			// skip if outside board
			if check_x < 0 || check_x >= GRID_SIZE || check_y < 0 || check_y >= GRID_SIZE {
				continue
			}
			// if close to another ship
			if board.cells[check_y][check_x] == "C" || board.cells[check_y][check_x] == "P" {
				debug_print(CLOSE_SHIP_DBG)
				return false
			}
		}
	}
	return true
}

place_ships :: proc(game: ^Game, board: ^Board, is_computer: bool) {
	start_time := time.now()
	ships := is_computer ? &game.computer.ships : &game.player.ships
	char := is_computer ? "C" : "P"

	for &ship in ships {
		ship.placed = false
		for !ship.placed {
			x := rand.int_max(GRID_SIZE)
			y := rand.int_max(GRID_SIZE)
			vertical := rand.int_max(2) == 1

			if is_valid_placement(board, x, y, ship.size, vertical) {
				// Place ship
				if vertical {
					for i in 0 ..< ship.size {
						board.cells[y + i][x] = char
						append(&ship.position, Vec2{x, y + i})
					}
				} else {
					for i in 0 ..< ship.size {
						board.cells[y][x + i] = char
						append(&ship.position, Vec2{x + i, y})
					}
				}
				ship.placed = true
			}
		}
	}
	end_time := time.now()
	delta := time.diff(start_time, end_time)
	who := is_computer ? "Computer" : "Player"
	debug_print(PLACED_SHIPS_DBG, who, delta)
	if who == "Player" {
		time.sleep(LONG_PAUSE * time.Second)
		clear_console()
		// display_board("Your Board", &game.player.my_board)
	}
}

place_player_ships :: proc(game: ^Game, board: ^Board) {
	buf: [256]byte

	for &ship in game.player.ships {
		placed := false
		for !placed {
			clear_console()
			display_board("Your Board", board)
			fmt.printf(PLACE_SHIP, ship.name, ship.size)
			fmt.print(ENTER_COORDINATES)

			num_bytes, _ := os.read(os.stdin, buf[:])
			defer os.flush(os.stdin)
			input := string(buf[:num_bytes])
			input = strings.to_lower(strings.trim_right(input, "\r\n"))

			if input == "q" {
				restart_or_quit(game)
				return
			} else if input == "auto" {
				place_ships(game, &game.player.my_board, false)
				placed = true
				game.state = .TurnPlayer
				return
			}

			x, y, vertical, ok := parse_coordinates(input)

			if !ok || x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE {
				fmt.println(INVALID_PLACEMENT)
				time.sleep(SHORT_PAUSE * time.Millisecond)
				continue
			}

			// Check ship bounds before placement
			if vertical && y + ship.size > GRID_SIZE || !vertical && x + ship.size > GRID_SIZE {
				fmt.println(OUT_OF_BOUNDS)
				time.sleep(SHORT_PAUSE * time.Millisecond)
				continue
			}

			if is_valid_placement(board, x, y, ship.size, vertical) {
				// Place ship
				if vertical {
					for i in 0 ..< ship.size {
						board.cells[y + i][x] = "P"
						append(&ship.position, Vec2{x, y + i})
					}
				} else {
					for i in 0 ..< ship.size {
						board.cells[y][x + i] = "P"
						append(&ship.position, Vec2{x + i, y})
					}
				}
				clear_console()
				display_board("Your Board", &game.player.my_board)
				placed = true
			} else {
				fmt.println(INVALID_PLACEMENT)
				time.sleep(SHORT_PAUSE * time.Millisecond)
				continue
			}
		}
	}
	fmt.println(ALL_SHIPS_PLACED)
	time.sleep(LONG_PAUSE * time.Second)
	game.state = .TurnPlayer
}
