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

SHOOTING_AT_DBG :: "Shooting at: %c%d\n"
COMPUTER_BOARD_DBG :: "Computer board cell: %s\n"
CHECK_HIT_DBG :: "Checking hit at: %c%d\n"
COMUTER_RANDOM_SHOT_DBG :: "Computer is shooting randomly\n"
INVALID_SHOT_DBG :: "Invalid shot at: %c%d\n"
SHIP_ON_CELL_DBG :: "Ship found on cell: %c%d\n"
HIT_CONFIRM_DBG :: "Hit confirmed on %v! Hits: %d/%d\n"
SHOT_MISS_DBG :: "Missed shot at: %c%d\n"

INPUT_ATTACK :: "Enter coordinates to attack (e.g. A1, C7): "
ALREADY_ATTACKED :: "\nYou've already attacked this position. Try again\n"
PLAYER_HIT :: "\nYou hit a ship!\n"
COMPUTER_HIT :: "\nComputer hit at %c%d\n"
PLAYER_SHIP_SUNK :: "\nOne of your Ships sunk!\n"
COMPUTER_SHIP_SUNK :: "\nComputer's ship sunk!\n"
PLAYER_MISS :: "\nMiss...it's Computer's turn\n"
COMPUTER_MISS :: "\nComputer missed at %c%d ...\n"

BOOM_SCREEN ::
	"\n ____   ___   ___  __  __   _\n" +
	"| __ ) / _ \\ / _ \\|  \\/  | | |\n" +
	"|  _ \\| | | | | | | |\\/| | | |\n" +
	"| |_) | |_| | |_| | |  | | |_|\n" +
	"|____/ \\___/ \\___/|_|  |_| (_)\n"


process_player_shot :: proc(game: ^Game, board: ^Board) -> bool {
	clear_console()
	display_board("Player's Board", &game.player.my_board)
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
			time.sleep((LONG_PAUSE + 1) * time.Second)
			return true
		}
	}

	if len(input) < 2 || len(input) > 4 {
		fmt.println(INVALID_INPUT)
		time.sleep(SHORT_PAUSE * time.Millisecond)
		clear_console()
		return true
	}

	x := int(input[0] - 'a')
	if x < 0 || x >= GRID_SIZE {
		fmt.println(INVALID_COLUMN)
		time.sleep(SHORT_PAUSE * time.Millisecond)
		return true
	}

	y_str := input[1:]
	y := strconv.atoi(y_str)
	y -= 1 // decrement by 1 because of 0-based indexing

	if y < 0 || y >= GRID_SIZE {
		fmt.println(INVALID_ROW)
		time.sleep(SHORT_PAUSE * time.Millisecond)
		return true
	}

	// Add debug prints
	debug_print(SHOOTING_AT_DBG, x + 'A', y + 1)
	debug_print(COMPUTER_BOARD_DBG, game.computer.my_board.cells[y][x])


	if board.cells[y][x] == "X" || board.cells[y][x] == "o" {
		fmt.println(ALREADY_ATTACKED)
		time.sleep(SHORT_PAUSE * time.Millisecond)
		return true
	}

	hit, sunk, invalid, ship := check_ship_hit(
		&game.computer.my_board,
		game.computer.ships[:],
		x,
		y,
	)

	if hit {
		log_shot(&game.logger, true, x, y, true)
		board.cells[y][x] = "X"
		clear_console()
		fmt.println(BOOM_SCREEN)
		fmt.printf(PLAYER_HIT)
		if sunk {
			//mark_sunken_ship(&game.computer.my_board, ship)
			mark_sunken_ship(&game.player.target_board, ship)
			log_ship_sunk(&game.logger, true, "Computer")
			fmt.println(COMPUTER_SHIP_SUNK)
			time.sleep(SHORT_PAUSE * time.Millisecond)
		}
		game.player.turns += 1
		time.sleep(LONG_PAUSE * time.Second)

		return true
	} else {
		log_shot(&game.logger, true, x, y, false)
		board.cells[y][x] = "o"
		fmt.println(PLAYER_MISS)
		time.sleep(SHORT_PAUSE * time.Millisecond)
		game.player.turns += 1
		return false
	}
}

process_random_shot :: proc(board: ^Board) -> (x: int, y: int) {
	debug_print(COMUTER_RANDOM_SHOT_DBG)
	for { 	// Loop until a valid shot is found
		tmp_x := rand.int_max(GRID_SIZE)
		tmp_y := rand.int_max(GRID_SIZE)

		if is_valid_shot(board, tmp_x, tmp_y) {
			return tmp_x, tmp_y
		}
	}
	// return tmp_x, tmp_y
}

all_directions_tried :: proc(tried: [4]bool) -> bool {
	for tried_dir in tried {
		if !tried_dir do return false
	}
	return true
}

// --- Helper function to handle shot results ---
handle_shot_result :: proc(game: ^Game, board: ^Board, x, y: int, hit: bool, ship: ^Ship) -> bool {
	if hit {
		log_shot(&game.logger, false, x, y, true)
		board.cells[y][x] = "X"
		clear_console()
		fmt.println(BOOM_SCREEN)
		fmt.printf(COMPUTER_HIT, x + 'A', y + 1)
		if ship != nil && ship.sunk {
			mark_sunken_ship(&game.player.my_board, ship)
			log_ship_sunk(&game.logger, false, "Player")
			fmt.println(PLAYER_SHIP_SUNK)
			time.sleep(LONG_PAUSE * time.Second)
			game.last_hit = LastHit{}
		}
		time.sleep(LONG_PAUSE * time.Second)
		return true
	} else {
		log_shot(&game.logger, false, x, y, false)
		board.cells[y][x] = "o"
		fmt.printf(COMPUTER_MISS, x + 'A', y + 1)
		time.sleep(SHORT_PAUSE * time.Millisecond)
		return false
	}
}

process_computer_shot :: proc(game: ^Game, board: ^Board) -> bool {
	clear_console()
	display_board("Player's Board", &game.player.my_board)
	display_board("Player's Target Board", &game.player.target_board)

	if !game.last_hit.has_hit {
		// Random shot until hit
		x, y := process_random_shot(board)

		hit, sunk, invalid, ship := check_ship_hit(
			&game.player.my_board,
			game.player.ships[:],
			x,
			y,
		)

		if invalid {
			fmt.println(INVALID_INPUT)
			time.sleep(LONG_PAUSE * time.Second)
			// shoot random again
			return true
		}

		if hit {
			log_shot(&game.logger, false, x, y, true)
			game.last_hit = LastHit {
				x                = x,
				y                = y,
				first_x          = x,
				first_y          = y,
				has_hit          = true,
				direction        = .None,
				tried_directions = [4]bool{false, false, false, false}, // Explicitly reset
			}
		}

		return handle_shot_result(game, board, x, y, hit, ship)
	}

	// Smart targeting mode
	x := game.last_hit.x
	y := game.last_hit.y

	if game.last_hit.direction == .None {
		// Add boundary check before trying new direction
		directions := []Direction{.West, .East, .South, .North} // Try West first if at East edge
		offsets := [][2]int{{-1, 0}, {1, 0}, {0, 1}, {0, -1}}
		valid_direction_found := false

		for dir, i in directions {
			if game.last_hit.tried_directions[i] do continue

			new_x := game.last_hit.first_x + offsets[i][0] // Use first_x
			new_y := game.last_hit.first_y + offsets[i][1]

			// new_x := x + offsets[i][0]
			// new_y := y + offsets[i][1]

			// Check bounds before attempting shot
			if is_valid_shot(board, new_x, new_y) && is_in_bounds(new_x, new_y, game) {
				x = new_x
				y = new_y
				game.last_hit.direction = dir
				valid_direction_found = true
				debug_print("Trying direction %v from %c%d\n", dir, x + 'A', y + 1)
				break
			} else {
				game.last_hit.tried_directions[i] = true // Mark invalid direction as tried
			}
		}

		if !valid_direction_found {
			game.last_hit = LastHit{}
			debug_print("No valid directions, reverting to random\n")
			return true
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
		// Return to first hit
		game.last_hit.x = game.last_hit.first_x
		game.last_hit.y = game.last_hit.first_y

		// Change direction and potentially reset to random
		should_reset := change_direction(game)
		if should_reset {
			return true // Try random shot
		}
		return false // Try new direction
	}

	// Process shot
	hit, sunk, invalid, ship := check_ship_hit(&game.player.my_board, game.player.ships[:], x, y)
	if invalid {
		// TODO: this has potential to be an infinite loop
		fmt.println(INVALID_INPUT)
		time.sleep(LONG_PAUSE * time.Second)
		return true
	}

	if hit {
		game.last_hit.x = x
		game.last_hit.y = y
	} else {
		// Return to first hit for next attempt
		game.last_hit.x = game.last_hit.first_x
		game.last_hit.y = game.last_hit.first_y

		// Change direction after miss
		change_direction(game)
		time.sleep(SHORT_PAUSE * time.Millisecond)
	}

	return handle_shot_result(game, board, x, y, hit, ship)
}

is_in_bounds :: proc(x, y: int, game: ^Game) -> bool {
	// First check basic bounds for all cases
	if x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE {
		debug_print("Out of bounds at %c%d\n", x + 'A', y + 1)
		return false
	}
	return true
}

has_cell_been_shot :: proc(board: ^Board, x, y: int) -> bool {
	cell := board.cells[y][x]
	return cell == "X" || cell == "o" || cell == "*"
}

check_ship_hit :: proc(
	board: ^Board,
	ships: []Ship,
	x, y: int,
) -> (
	hit: bool,
	sunk: bool,
	invalid: bool,
	ship: ^Ship,
) {
	debug_print(CHECK_HIT_DBG, x + 'A', y + 1)
	if !is_valid_shot(board, x, y) {
		debug_print(INVALID_SHOT_DBG, x + 'A', y + 1)
		return false, false, true, nil
	}
	if board.cells[y][x] == "C" || board.cells[y][x] == "P" {
		debug_print(SHIP_ON_CELL_DBG, x + 'A', y + 1)
		for &ship in ships {
			for pos in ship.position {
				if pos.x == x && pos.y == y {
					ship.hits += 1
					ship.sunk = ship.hits >= ship.size
					debug_print(HIT_CONFIRM_DBG, ship.name, ship.hits, ship.size)
					return true, ship.sunk, false, &ship
				}
			}
		}
	}
	debug_print(SHOT_MISS_DBG, x + 'A', y + 1)
	return false, false, false, nil
}

mark_sunken_ship :: proc(board: ^Board, ship: ^Ship) {
	// Mark all positions of the sunken ship with '*'
	for pos in ship.position {
		board.cells[pos.y][pos.x] = "*"
	}
}

is_valid_shot :: proc(board: ^Board, x, y: int) -> bool {
	// if x >= 0 && x < GRID_SIZE && y >= 0 && y < GRID_SIZE {
	if x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE {
		return false
	} else if board.cells[y][x] == "X" || board.cells[y][x] == "o" || board.cells[y][x] == "*" {
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

change_direction :: proc(game: ^Game) -> bool {
	debug_print("Changing direction from %v\n", game.last_hit.direction)

	// Reset tried directions when starting in a new direction
	// if game.last_hit.direction == .None {
	// 	game.last_hit.tried_directions = [4]bool{false, false, false, false}
	// }

	// Only mark current direction as tried if we actually tried it
	if game.last_hit.direction != .None {
		dir_idx := int(game.last_hit.direction)
		game.last_hit.tried_directions[dir_idx] = true
	}

	debug_print(
		"Tried directions: E:%v W:%v N:%v S:%v\n",
		game.last_hit.tried_directions[int(Direction.East)],
		game.last_hit.tried_directions[int(Direction.West)],
		game.last_hit.tried_directions[int(Direction.North)],
		game.last_hit.tried_directions[int(Direction.South)],
	)

	directions := []Direction{.West, .East, .South, .North} // Try West first if at East edge
	// Try remaining untried directions in specific order
	for dir in directions {
		if !game.last_hit.tried_directions[int(dir)] {
			game.last_hit.direction = dir
			return false
		}
	}

	// All directions truly tried
	game.last_hit = LastHit{}
	debug_print("All directions tried, resetting to random\n")
	return true
}
