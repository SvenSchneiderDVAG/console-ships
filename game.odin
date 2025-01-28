package main

import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

CLEAR: string = "\033c"
GRID_SIZE :: 10
DEBUG :: #config(DEBUG, true)

// ANSI Colors
RED :: "\x1b[31m"
GREEN :: "\x1b[32m"
YELLOW :: "\x1b[33m"
BLUE :: "\x1b[34m"
RESET :: "\x1b[0m"

Vec2 :: struct {
	x: int,
	y: int,
}

Board :: struct {
	row, column: int,
	cells:       [GRID_SIZE][GRID_SIZE]string,
}

Ship :: struct {
	name:     Ships,
	size:     int,
	position: [dynamic]Vec2,
	hits:     int,
	placed:   bool,
	sunk:     bool,
}

Player :: struct {
	name:         string,
	ships:        [5]Ship,
	my_board:     Board,
	target_board: Board,
	turns:        int,
}

LastHit :: struct {
	x:       int,
	y:       int,
	direction: enum {None, North, East, South, West},
	has_hit: bool,
}

Game :: struct {
	board:      Board,
	player:     Player,
	computer:   Player,
	state:      States,
	turns:      int,
	is_running: bool,
	last_hit:   LastHit,
}

Ships :: enum {
	Carrier    = 5,
	Battleship = 4,
	Cruiser    = 3,
	Submarine  = 3,
	Destroyer  = 2,
}

States :: enum {
	Win,
	Lost,
	GameOver,
	Restart,
	Init,
	TurnPlayer,
	TurnComputer,
	PlaceShips,
}

debug_print :: proc(message: string, args: ..any) {
	when ODIN_DEBUG {
		fmt.printf(message, ..args)
		fmt.println("\n")
	}
}

game_init :: proc(game: ^Game) {
	debug_print("Initializing game...")
	game.player.name = "Human"
	game.computer.name = "Computer"

	game.computer.ships[0] = Ship {
		name = .Carrier,
		size = 5,
	}
	game.computer.ships[1] = Ship {
		name = .Battleship,
		size = 4,
	}
	game.computer.ships[2] = Ship {
		name = .Cruiser,
		size = 3,
	}
	game.computer.ships[3] = Ship {
		name = .Submarine,
		size = 3,
	}
	game.computer.ships[4] = Ship {
		name = .Destroyer,
		size = 2,
	}

	game.player.ships[0] = Ship {
		name = .Carrier,
		size = 5,
	}
	game.player.ships[1] = Ship {
		name = .Battleship,
		size = 4,
	}
	game.player.ships[2] = Ship {
		name = .Cruiser,
		size = 3,
	}
	game.player.ships[3] = Ship {
		name = .Submarine,
		size = 3,
	}
	game.player.ships[4] = Ship {
		name = .Destroyer,
		size = 2,
	}

	debug_print("Initializing game boards...")

	make_board(&game.player.my_board)
	make_board(&game.player.target_board)
	make_board(&game.computer.my_board)

	game.state = .PlaceShips
	game.player.turns = 0
	game.computer.turns = 0
	game.last_hit = LastHit {
		x       = 0,
		y       = 0,
		has_hit = false,
		direction = .None,
	}

	clear_console()
	fmt.println("Welcome to Terminal-Battleships\n\n")
	time.sleep(2 * time.Second)
}

make_board :: proc(board: ^Board) {
	board.row = GRID_SIZE
	board.column = GRID_SIZE

	for i in 0 ..< GRID_SIZE {
		for j in 0 ..< GRID_SIZE {
			board.cells[i][j] = "."
			// debug_print(fmt.tprintf("Cell [%d][%d] set to .", i, j))
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
	if y + size > GRID_SIZE || x + size > GRID_SIZE {
		debug_print("Ship is out of bounds\n")
		return false
	}

	for i in -1 ..= size {
		for j in -1 ..= 1 {
			check_x := vertical ? x + j : x + i
			check_y := vertical ? y + i : y + j

			// skip if outside board
			if check_x < 0 || check_x >= GRID_SIZE || check_y < 0 || check_y >= GRID_SIZE {
				debug_print("Coords outside board.\n")
				return false
			}
			// if close to another ship
			if board.cells[check_y][check_x] == "C" || board.cells[check_y][check_x] == "P" {
				debug_print("Too close to another ship.\n")
				return false
			}
		}
	}
	return true
}

process_player_shot :: proc(game: ^Game, board: ^Board) -> bool {
	// clear_console()
	fmt.println("\nPlayer's turn\n")
	display_board("Player's Target Board", &game.player.target_board)

	// Get player input
	buf: [256]byte

	fmt.print("Enter coordinates to attack (e.g. A1, C7): ")
	num_bytes, _ := os.read(os.stdin, buf[:])
	defer os.flush(os.stdin)
	input := string(buf[:num_bytes])
	input = strings.to_lower(strings.trim_right(input, "\r\n"))

	if input == "q" {
		return restart_or_quit(game)
	}

	if input == "" || len(input) < 2 || len(input) > 4 {
		fmt.println("\nInvalid input. Try again\n")
		return true
	}

	x := int(input[0]) - 'a'
	y_str := input[1:]
	y := strconv.atoi(y_str) - 1 // decrement by 1 because of 0-based indexing

	if x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE || y >= 11 {
		fmt.println("\nInvalid input: out of bounds! Try again.\n")
		time.sleep(1 * time.Second)
		clear_console()
		return true
	}

	if board.cells[y][x] == "X" || board.cells[y][x] == "o" {
		fmt.println("\nYou've already attacked this field. Try again.\n")
		time.sleep(1 * time.Second)
		clear_console()
		return true
	}

	hit, sunk := check_ship_hit(board, game.computer.ships[:], x, y)

	if hit {
		board.cells[y][x] = "X"
		fmt.println("\nBOOM!!! Hit!\n")
		if sunk {
			fmt.println("Computer's ship sunk!\n")
		}
		game.player.turns += 1
		time.sleep(1 * time.Second)
		clear_console()
		return true
	} else {
		board.cells[y][x] = "o"
		fmt.println("\nMiss...it's Computer's turn\n")
		game.player.turns += 1
		return false
	}
}

process_computer_shot :: proc(game: ^Game, board: ^Board) -> bool {
	clear_console()
	fmt.println("\nComputer's turn\n")

	if !game.last_hit.has_hit {
	// Random targetting

		x := rand.int_max(GRID_SIZE)
		y := rand.int_max(GRID_SIZE)

		// Skip if already tried
		if board.cells[y][x] == "X" || board.cells[y][x] == "o" {
			return true
		}

		// Computer's turn - attack player's board while hitting
		hit, sunk := check_ship_hit(&game.player.my_board, game.player.ships[:], x, y)

		if board.cells[y][x] == "P" || hit {
			// if hit {
			board.cells[y][x] = "X"
			game.last_hit = LastHit {
				x       = x,
				y       = y,
				has_hit = true,
			}
			game.computer.turns += 1
			// clear_console()
			display_board("Player's Board", &game.player.my_board)
			fmt.printf("\nBOOM!!! Computer hit at %c%d\n", x + 'A', y + 1)
			if sunk {
				fmt.println("Player's Ship sunk!\n")
				game.last_hit.has_hit = false
			}
			return true
		} else {
			board.cells[y][x] = "o"
			// clear_console()
			display_board("Player's Board", &game.player.my_board)
			fmt.println("\nComputer misses...\n")
			game.last_hit.has_hit = false
			game.computer.turns += 1
			return false
		}
	} else {
		// Smart targetting
		x := game.last_hit.x
		y := game.last_hit.y

		// Check if ship is vertical or horizontal
		if game.last_hit.direction == .None {
			// Try only one direction per turn
			if y > 0 && board.cells[y-1][x] != "X" && board.cells[y-1][x] != "o" {
				game.last_hit.direction = .North
				y -= 1
			} else if y < GRID_SIZE-1 && board.cells[y+1][x] != "X" && board.cells[y+1][x] != "o" {
				game.last_hit.direction = .South
				y += 1
			} else if x > 0 && board.cells[y][x-1] != "X" && board.cells[y][x-1] != "o" {
				game.last_hit.direction = .West
				x -= 1
			} else if x < GRID_SIZE-1 && board.cells[y][x+1] != "X" && board.cells[y][x+1] != "o" {
				game.last_hit.direction = .East
				x += 1
			} else {
				// No valid direction found, reset to random
				game.last_hit.has_hit = false
				return process_computer_shot(game, board)
			}
		}

		if board.cells[y][x] == "P" {
			board.cells[y][x] = "X"
			game.last_hit = LastHit {
				x       = x,
				y       = y,
				has_hit = true,
			}
			clear_console()
			display_board("Player's Board", &game.player.my_board)
			fmt.printf("\nComputer hit at %c%d\n", x + 'A', y + 1)
			game.computer.turns += 1
			return true
		} else {
			board.cells[y][x] = "o"
			clear_console()
			display_board("Player's Board", &game.player.my_board)
			fmt.println("\nComputer misses...\n")
			game.last_hit.has_hit = false
			game.computer.turns += 1
			return false
		}

		// Check if ship is vertical or horizontal
		if game.last_hit.direction == .North {
			y -= 1
		} else if game.last_hit.direction == .South {
			y += 1
		} else if game.last_hit.direction == .West {
			x -= 1
		} else if game.last_hit.direction == .East {
			x += 1
		}

		if board.cells[y][x] == "P" {
			board.cells[y][x] = "X"
			game.last_hit = LastHit{x = x, y = y, has_hit = true}
			clear_console()
			display_board("Player's Board", &game.player.my_board)
			fmt.printf("\nComputer hit at %c%d\n", x+'A', y+1)
			game.computer.turns += 1
			return true
		} else {
			board.cells[y][x] = "o"
			clear_console()
			display_board("Player's Board", &game.player.my_board)
			fmt.println("\nComputer misses...\n")
			game.last_hit.has_hit = false
			game.computer.turns += 1
			game.state = .TurnPlayer
			return false
		}
	}
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
	debug_print("\n%s placed ships in %v \n\n", who, delta)
	if who == "Player" {
		time.sleep(1 * time.Second)
		clear_console()
		display_board("Your Board", &game.player.my_board)
	}
}

parse_coordinates :: proc(input: string) -> (x: int, y: int, vertical: bool, ok: bool) {
	if len(input) < 3 || len(input) > 4 {
		return 0, 0, false, false
	}

	{
		// convert letters to x and y to coordinates
		x := int(input[0]) - 'a'

		y_str := input[1:len(input) - 1]
		y = strconv.atoi(y_str) - 1

		if y < 0 || y >= GRID_SIZE || y >= 10 {
			return 0, 0, false, false
		}

		vertical := input[len(input) - 1] == 'v'
		ok := x >= 0 && x < GRID_SIZE && y >= 0 && y < GRID_SIZE
		return x, y, vertical, ok
	}
}

place_player_ships :: proc(game: ^Game, board: ^Board) {
	buf: [256]byte

	for ship in game.player.ships {
		placed := false
		for !placed {
			clear_console()
			display_board("Your Board", board)
			fmt.printf("\nPlacing %v (size %d)\n\n", ship.name, ship.size)
			fmt.print(
				"Enter Start coordinates (e.g. a1v or f3h) where v is ",
				"vertical and h is horizontal: ",
			)

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

			if !ok {
				fmt.println("\nInvalid placement! Try again.\n")
				continue // TODO: check if this is correct
			}

			if is_valid_placement(board, x, y, ship.size, vertical) {
				// Place ship
				if vertical {
					for i in 0 ..< ship.size {
						board.cells[y + i][x] = "P"
					}
				} else {
					for i in 0 ..< ship.size {
						board.cells[y][x + i] = "P"
					}
				}
				placed = true
				clear_console()
				display_board("Your Board", &game.player.my_board)
			} else {
				fmt.println("\nInvalid placement! Try again.\n")
			}
		}
	}
	fmt.println("\nAll ships have been placed - let the Battle begin!\n\n")
	game.state = .TurnPlayer
}

check_ship_hit :: proc(board: ^Board, ships: []Ship, x, y: int) -> (hit: bool, sunk: bool) {
	for &ship in ships {
		for pos in ship.position {
			if pos.x == x && pos.y == y {
				ship.hits += 1
				ship.sunk = ship.hits >= ship.size
				debug_print("\nHit on %v! Hits: %d/%d\n", ship.name, ship.hits, ship.size)
				return true, ship.sunk
			}
		}
	}
	return false, false
}

is_valid_shot :: proc(board: ^Board, x, y: int) -> bool {
	if x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE {
		return false
	} else if board.cells[y][x] == "X" || board.cells[y][x] == "o" {
		return false
	} else {
		return true
	}
}

check_ships_sunk :: proc(ships: []Ship) -> bool {
	for &ship in ships {
		if !ship.sunk {
			return false
		}
	}
	return true
}

check_win_condition :: proc(game: ^Game, board: ^Board) -> bool {
	// Check if all computer ships are sunk
	if check_ships_sunk(game.computer.ships[:]) {
		game.state = .Win
		return true
	}

	if check_ships_sunk(game.player.ships[:]) {
		game.state = .Lost
		return true
	}
	return false
}

restart_or_quit :: proc(game: ^Game) -> bool {
	buf: [256]byte

	fmt.print("\nDo you want to play again? (y/n): ")
	num_bytes, _ := os.read(os.stdin, buf[:])
	defer os.flush(os.stdin)
	input := string(buf[:num_bytes])
	input = strings.to_lower(strings.trim_right(input, "\r\n"))

	if input == "y" {
		game.state = .Init
		game.is_running = true
		return true
	} else if input == "n" {
		game.is_running = false
		return false
	}

	fmt.println("\nInvalid input. Try again.\n")
	return true
}

clear_console :: proc() {
	when !ODIN_DEBUG {
		fmt.print(CLEAR)
	}
}

main :: proc() {
	game: Game
	game.state = .Init
	game.is_running = true

	for game.is_running {
		switch game.state {
		case .PlaceShips:
			place_ships(&game, &game.computer.my_board, true)
			when ODIN_DEBUG {
				display_board("Computer's Board", &game.computer.my_board)
			}
			fmt.println("Place your ships\n")
			place_player_ships(&game, &game.player.my_board)
		case .TurnPlayer:
			if !process_player_shot(&game, &game.player.target_board) {
				game.state = .TurnComputer
			}
			check_win_condition(&game, &game.player.target_board)
		case .TurnComputer:
			clear_console()
			fmt.println("Computer's turn\n")
			display_board("Player's Board", &game.player.my_board)
			if !process_computer_shot(&game, &game.player.my_board) {
				game.state = .TurnPlayer
			}
			check_win_condition(&game, &game.player.my_board)
		case .GameOver:
			fmt.println("\nGame over!\n")
			game.state = .Restart
		case .Restart:
			if !restart_or_quit(&game) {
				free_all()
				game.is_running = false
				break
			}
			game.state = .Init
		case .Init:
			game_init(&game)
		case .Win:
			fmt.printf("\n%s wins in %d turns!\n", game.player.name, game.player.turns)
			game.state = .GameOver
		case .Lost:
			fmt.printf("\n%s wins in %d turns!\n", game.computer.name, game.computer.turns)
			game.state = .GameOver
		}
	}
}
