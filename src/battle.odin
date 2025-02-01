package main

import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:time"

INVALID_INPUT :: "\nInvalid input. Try again\n"
INVALID_COLUMN :: "\nInvalid column. Use A-J\n"
INVALID_ROW :: "\nInvalid row. Use 1-10\n"

INPUT_ATTACK :: "Enter coordinates to attack (e.g. A1, C7): "
ALREADY_ATTACKED :: "\nYou've already attacked this position. Try again\n"
PLAYER_HIT :: "\nBOOM!!! You hit a ship!\n"
COMPUTER_HIT :: "\nBOOM!!! Computer hit at %c%d\n"
PLAYER_SHIP_SUNK :: "\nOne of your Ships sunk!\n"
COMPUTER_SHIP_SUNK :: "\nComputer's ship sunk!\n"
PLAYER_MISS :: "\nMiss...it's Computer's turn\n"
COMPUTER_MISS :: "\nComputer missed at %c%d ...\n"

process_player_shot :: proc(game: ^Game, board: ^Board) -> bool {
	clear_console()
	display_board("Player's Board", &game.player.my_board)
	// fmt.println("Player's turn\n")
	// display_board("Player's Board", &game.player.my_board)
	display_board("Player's Target Board", &game.player.target_board)

	// Get player input
	buf: [256]byte
	fmt.print(INPUT_ATTACK)
	num_bytes, _ := os.read(os.stdin, buf[:])
	defer os.flush(os.stdin)
	input := strings.to_lower(strings.trim_right(string(buf[:num_bytes]), "\r\n"))

	if input == "q" {
		return restart_or_quit(game)
	}

	when ODIN_DEBUG {
		if input == "show" {
			fmt.println()
			display_board("Computer's Board", &game.computer.my_board)
			time.sleep(3 * time.Second)
			return true
		}
	}

	if len(input) < 2 || len(input) > 4 {
		fmt.println(INVALID_INPUT)
		time.sleep(1 * time.Second)
		clear_console()
		return true
	}

	x := int(input[0] - 'a')
	if x < 0 || x >= GRID_SIZE {
		fmt.println(INVALID_COLUMN)
		time.sleep(1 * time.Second)
		// clear_console()
		return true
	}

	y_str := input[1:]
	y := strconv.atoi(y_str)
	y -= 1 // decrement by 1 because of 0-based indexing

	if y < 0 || y >= GRID_SIZE {
		fmt.println(INVALID_ROW)
		time.sleep(1 * time.Second)
		// clear_console()
		return true
	}

	// Add debug prints
	debug_print("Shooting at: %c%d\n", x + 'A', y + 1)
	debug_print("Computer board at this position: %s\n", game.computer.my_board.cells[y][x])


	if board.cells[y][x] == "X" || board.cells[y][x] == "o" {
		fmt.println(ALREADY_ATTACKED)
		time.sleep(1 * time.Second)
		// clear_console()
		return true
	}

	hit, sunk, invalid := check_ship_hit(&game.computer.my_board, game.computer.ships[:], x, y)

	if hit {
		board.cells[y][x] = "X"
		fmt.println(PLAYER_HIT)
		if sunk {
			fmt.println(COMPUTER_SHIP_SUNK)
			time.sleep(1 * time.Second)
		}
		game.player.turns += 1
		time.sleep(1 * time.Second)
		// clear_console()
		// display_board("Player's Board", &game.player.my_board)
		// display_board("Player's Board", &game.player.my_board)

		return true
	} else {
		board.cells[y][x] = "o"
		fmt.println(PLAYER_MISS)
		time.sleep(2 * time.Second)
		game.player.turns += 1
		return false
	}
}

process_random_shot :: proc(board: ^Board) -> (x: int, y: int) {
	debug_print("Computer is random targetting...\n")
	tmp_x := rand.int_max(GRID_SIZE)
	tmp_y := rand.int_max(GRID_SIZE)

	// if already shot, try again
	if !is_valid_shot(board, tmp_x, tmp_y) {
		return process_random_shot(board)
	}
	return tmp_x, tmp_y
}


process_computer_shot :: proc(game: ^Game, board: ^Board) -> bool {
	clear_console()
	display_board("Player's Board", &game.player.my_board)
	display_board("Player's Target Board", &game.player.target_board)
	// fmt.println("Computer's turn\n")

	if !game.last_hit.has_hit {
		// Random shot until hit
		x, y := process_random_shot(board)
		hit, sunk, invalid := check_ship_hit(&game.player.my_board, game.player.ships[:], x, y)
		if invalid {
			return true
		}

		if hit {
			board.cells[y][x] = "X"
			game.last_hit = LastHit {
				x         = x,
				y         = y,
				first_x   = x,
				first_y   = y,
				has_hit   = true,
				direction = .None,
			}

			// display_board("Player's Board", &game.player.my_board)
			fmt.printf(COMPUTER_HIT, x + 'A', y + 1)
			if sunk {
				fmt.println(PLAYER_SHIP_SUNK)
				time.sleep(1 * time.Second)
				game.last_hit = LastHit{}
			}
			time.sleep(1 * time.Second)
			return true
		}
		board.cells[y][x] = "o"
		// display_board("Player's Board", &game.player.my_board)
		fmt.printf(COMPUTER_MISS, x + 'A', y + 1)
		time.sleep(1 * time.Second)
		return false
	}

	// Smart targeting mode
	x := game.last_hit.x
	y := game.last_hit.y

	// Try new direction if none set
	if game.last_hit.direction == .None {
		directions := []Direction{.East, .West, .South, .North}
		offsets := [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}

		for dir, i in directions {
			new_x := x + offsets[i][0]
			new_y := y + offsets[i][1]

			if is_valid_shot(board, new_x, new_y) && is_in_bounds(new_x, new_y, game) {
				x = new_x
				y = new_y
				game.last_hit.direction = dir
				break
			}
		}
	} else {
		// Continue in current direction
		#partial switch game.last_hit.direction {
		case .East:
			x += 1
		case .West:
			x -= 1
		case .South:
			y += 1
		case .North:
			y -= 1
		}
	}

	// Check bounds and previous shots
	if !is_in_bounds(x, y, game) || !is_valid_shot(board, x, y) {
		// Return to first hit and try new direction
		game.last_hit.x = game.last_hit.first_x
		game.last_hit.y = game.last_hit.first_y

		// Rotate direction
		#partial switch game.last_hit.direction {
		case .East:
			game.last_hit.direction = .South
		case .West:
			game.last_hit.direction = .North
		case .South:
			game.last_hit.direction = .West
		case .North:
			game.last_hit.direction = .East
		}

		board.cells[y][x] = "o" // Mark as miss
		return false // End turn instead of retrying
		// return true // Try again next turn
	}

	// Process shot
	hit, sunk, invalid := check_ship_hit(&game.player.my_board, game.player.ships[:], x, y)
	if invalid {
		return true
	}

	if hit {
		board.cells[y][x] = "X"
		game.last_hit.x = x
		game.last_hit.y = y
		// display_board("Player's Board", &game.player.my_board)
		fmt.printf("\nBOOM!!! Computer hit at %c%d\n", x + 'A', y + 1)
		if sunk {
			fmt.println("Ship sunk!")
			time.sleep(1 * time.Second)
			game.last_hit = LastHit{}
		}
		time.sleep(1 * time.Second)
		return true
	}

	board.cells[y][x] = "o"
	// display_board("Player's Board", &game.player.my_board)
	fmt.printf(COMPUTER_MISS, x + 'A', y + 1)

	// Return to first hit for next attempt
	game.last_hit.x = game.last_hit.first_x
	game.last_hit.y = game.last_hit.first_y

	// Change direction after miss
	#partial switch game.last_hit.direction {
	case .East:
		game.last_hit.direction = .West
	case .West:
		game.last_hit.direction = .South
	case .South:
		game.last_hit.direction = .North
	case .North:
		game.last_hit.direction = .None
	}
	time.sleep(1 * time.Second)
	return false
}

is_in_bounds :: proc(x, y: int, game: ^Game) -> bool {
	switch game.last_hit.direction {
	case .None:
		return x >= 0 && x < GRID_SIZE && y >= 0 && y < GRID_SIZE
	case .North:
		return y > 0 && y < GRID_SIZE && x >= 0 && x < GRID_SIZE
	case .South:
		return y >= 0 && y < GRID_SIZE - 1 && x >= 0 && x < GRID_SIZE
	case .West:
		return x > 0 && y >= 0 && y < GRID_SIZE
	case .East:
		return x >= 0 && x < GRID_SIZE - 1 && y >= 0 && y < GRID_SIZE
	}
	return false
}

has_cell_been_shot :: proc(board: ^Board, x, y: int) -> bool {
	// First check bounds
	if x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE {
		return true // Treat out-of-bounds as "shot" to prevent access
	}

	// Check for hits (X) or misses (o)
	cell := board.cells[y][x]
	return cell == "X" || cell == "o"
}

parse_coordinates :: proc(input: string) -> (x: int, y: int, vertical: bool, ok: bool) {
	if len(input) < 3 || len(input) > 4 {
		return 0, 0, false, false
	}

	{
		// convert letters to x and y to coordinates
		x := int(input[0] - 'a')
		if x < 0 || x >= GRID_SIZE {
			return 0, 0, false, false
		}

		y_str := input[1:len(input) - 1]
		y = strconv.atoi(y_str) - 1

		if y < 0 || y >= GRID_SIZE {
			return 0, 0, false, false
		}

		vertical := input[len(input) - 1] == 'v'
		ok := x >= 0 && x < GRID_SIZE && y >= 0 && y < GRID_SIZE
		return x, y, vertical, ok
	}
}

check_ship_hit :: proc(
	board: ^Board,
	ships: []Ship,
	x, y: int,
) -> (
	hit: bool,
	sunk: bool,
	invalid: bool,
) {
	debug_print("Checking hit at %c%d\n", x + 'A', y + 1)
	if !is_valid_shot(board, x, y) {
		debug_print("Invalid Shot%c%d\n", x + 'A', y + 1)
		return false, false, true
	}
	if board.cells[y][x] == "C" || board.cells[y][x] == "P" {
		debug_print("C or P at %c%d\n", x + 'A', y + 1)
		for &ship in ships {
			for pos in ship.position {
				if pos.x == x && pos.y == y {
					ship.hits += 1
					ship.sunk = ship.hits >= ship.size
					debug_print(
						"\nHit confirmed on %v! Ship hits: %d/%d\n",
						ship.name,
						ship.hits,
						ship.size,
					)
					return true, ship.sunk, false
				}
			}
		}
	}
	debug_print("Shot missed at %c%d\n", x + 'A', y + 1)
	return false, false, false
}

is_valid_shot :: proc(board: ^Board, x, y: int) -> bool {
	// if x >= 0 && x < GRID_SIZE && y >= 0 && y < GRID_SIZE {
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
