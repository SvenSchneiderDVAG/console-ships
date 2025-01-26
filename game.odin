package main

import "core:fmt"
import "core:math/rand"
import "core:time"
import "core:os"
import "core:strings"
import "core:strconv"

CLEAR : string = "\033c"
GRID_SIZE : int = 10
DEBUG : bool = false

Vector2 :: struct {
	x: i32,
	y: i32,
}

Board :: struct {
	row, column: int,
	cells:       [10][10]string,
}

Ship :: struct {
	name:     	Ships,
	size:     	int,
	position: 	[dynamic]Vector2,
	hits:	 	int,
	placed:   	bool,
	sunk:	 	bool,
}

Player :: struct {
	name:  			string,
	ships: 			[5]Ship,
	my_board: 		Board,
	target_board: 	Board,
}

LastHit :: struct {
	x: int,
	y: int,
	direction: enum {None, North, East, South, West},
	has_hit: bool
}

Game :: struct {
	board:    		Board,
	player:   		Player,
	computer: 		Player,
	state:   		States,
	current_turn: 	States,
	is_running: 	bool,
	last_hit: 		LastHit
}

Ships :: enum {
	Carrier = 5,
	Battleship = 4,
	Cruiser = 3,
	Submarine = 3,
	Destroyer = 2,
}

States :: enum {
	// Miss,
	// Hit,
	// Sunk,
	Win,
	Lost,
	GameOver,
	Running,
	TurnPlayer,
	TurnComputer,
	PlaceShips,
}

debug_print :: proc(message: string) {
	if DEBUG {
		fmt.printf(message)
		fmt.println("\n")
	}

}

game_init :: proc(game: ^Game) {
	game.player.name = "Human"
	game.computer.name = "Computer"
	game.is_running = true

	game.computer.ships[0] = Ship{name = .Carrier, size = 5}
	game.computer.ships[1] = Ship{name = .Battleship, size = 4}
	game.computer.ships[2] = Ship{name = .Cruiser, size = 3}
	game.computer.ships[3] = Ship{name = .Submarine, size = 3}
	game.computer.ships[4] = Ship{name = .Destroyer, size = 2}

	game.player.ships[0] = Ship{name = .Carrier, size = 5}
	game.player.ships[1] = Ship{name = .Battleship, size = 4}
	game.player.ships[2] = Ship{name = .Cruiser, size = 3}
	game.player.ships[3] = Ship{name = .Submarine, size = 3}
	game.player.ships[4] = Ship{name = .Destroyer, size = 2}


	game.board.row = GRID_SIZE
	game.board.column = GRID_SIZE

	// Initialize player boards
    game.player.my_board.row = GRID_SIZE
    game.player.my_board.column = GRID_SIZE
    game.player.target_board.row = GRID_SIZE
    game.player.target_board.column = GRID_SIZE

    // Initialize computer boards
    game.computer.my_board.row = GRID_SIZE
    game.computer.my_board.column = GRID_SIZE
    game.computer.target_board.row = GRID_SIZE
    game.computer.target_board.column = GRID_SIZE

	init_board(game, &game.player.my_board)
	init_board(game, &game.player.target_board)
	init_board(game, &game.computer.my_board)
	init_board(game, &game.computer.target_board)
}

init_board :: proc(game: ^Game, board: ^Board) {
	for i in 0 ..< GRID_SIZE {
		for j in 0 ..< GRID_SIZE {
			if board == &game.player.my_board {
				board.cells[i][j] = "."
				debug_print("initializing Player board...")
			} else if board == &game.player.target_board {
				board.cells[i][j] = "."
				debug_print("initializing Player target board...")
			} else if board == &game.computer.my_board {
				board.cells[i][j] = "."
				debug_print("initializing Computer board...")
			} else if board == &game.computer.target_board {
				debug_print("initializing Computer target board...")
				board.cells[i][j] = "."
			}
		}
	}
}

display_board :: proc(title: string, board: ^Board) {
	fmt.println(title, "\n")

	// Print column headers (A-H)
	fmt.print("     ") // Space for column numbers
	for j in 0..< GRID_SIZE {
		fmt.printf("%c ", 'A' + j)
		fmt.printf(" ")
	}
	fmt.println("\n")

	// Print rows with numbers and cells
	for i in 0..< board.row {
		fmt.printf("%d   ", i + 1)
		if i+1 != 10 { fmt.printf(" ") } // Space for single digit numbers
		for j in 0..< board.column {
			fmt.print(board.cells[i][j], " ")
		}
		fmt.println()
	}
	fmt.println()
}

is_valid_placement :: proc(board: ^Board, x, y, size:int, vertical: bool) -> bool {
	//Check bounds
	if vertical {
		if y + size > GRID_SIZE {
			debug_print("Vertical: Ship is out of bounds")
			return false
		}
	} else {
		if x + size > GRID_SIZE {
			debug_print("Horizontal: Ship is out of bounds")
			return false
		}
	}

	for i in -1..=size {
		for j in -1..=1 {
			check_x := vertical ? x + j : x + i
			check_y := vertical ? y + i : y + j

			// skip if outside board
			if check_x < 0 || check_x >= GRID_SIZE || check_y < 0 || check_y >= GRID_SIZE {
				debug_print("Outside board")
				continue
			}

			// if cells are not empty
			if board.cells[check_y][check_x] != "." {
				debug_print("Cells are not empty")
				return false
			}

			// if close to another ship
			if board.cells[check_y][check_x] == "C" {
				debug_print("Close to another ship")
				return false
			}
		}
	}
	return true
}

process_player_shot :: proc(game: ^Game, board: ^Board) -> bool {
	// clear_console()
	fmt.println("Player's turn\n\n")
	display_board("Player's Target Board", &game.player.target_board)
	fmt.printf("Game state: %v\n", game.state)
    // Get player input
	buf: [256]byte

	fmt.print("Enter coordinates to attack (e.g. A1, C7): \n")
	num_bytes, _ := os.read(os.stdin, buf[:])
	defer os.flush(os.stdin)
	input := string(buf[:num_bytes])
	input = strings.to_lower(strings.trim_right(input, "\r\n"))

	// if input == "q" {
	// 	game.state = .GameOver
	// 	return
	// }

	if input == "" || len(input) < 2 || len(input) > 4 {
		fmt.println("Invalid input. Try again")
		process_player_shot(game, board)
	}

	x := int(input[0]) - 'a'

	y_str := input[1:]
	y := strconv.atoi(y_str) -1
	if y < 0 || y >= GRID_SIZE || y >= 11 {
		fmt.println("Invalid input. Try again")
		return true
	}
	// y := int(input[1]) - '1'

	if x < 0 || x >= GRID_SIZE || y < 0 || y >= GRID_SIZE || y >= 11 {
		fmt.println("Invalid input. Try again")
		return true
	}

	if board.cells[y][x] == "X" || board.cells[y][x] == "M" {
		fmt.println("You've already attacked this cell. Try again")
		return true
	}

	if game.computer.my_board.cells[y][x] == "C" {
		board.cells[y][x] = "X"
		fmt.println("Hit!")
		return true
	} else {
		board.cells[y][x] = "M"
		fmt.println("Miss...It's Computer's turn")
		game.state = .TurnComputer
		return false
	}
}

check_win_condition :: proc(game: ^Game, board: ^Board) -> bool {
	for i in 0..<board.row {
		for j in 0..<board.column {
			if board.cells[i][j] == "C" {
				if DEBUG {
					fmt.printf("Computer's ship at %d, %d\n", j, i)
				}
				return false
			}
		}
	}
	game.state = .Win
	return true
}

process_computer_shot :: proc(game: ^Game, board: ^Board) -> bool {
	// TODO: check targetting
	fmt.println("Computer's turn")

	if !game.last_hit.has_hit {
		for {
			x := rand.int_max(GRID_SIZE)
			y := rand.int_max(GRID_SIZE)

			// if game.player.my_board.cells[y][x] == "X" ||
			// 	game.player.my_board.cells[y][x] == "M" {
			// 		process_computer_shot(game, board)
			// 		return
			// }

			// Skip if already tried
			if board.cells[y][x] == "X" || board.cells[y][x] == "M" {
				continue
			}

			// Computer's turn - attack player's board while hitting
			if game.player.my_board.cells[y][x] == "P" {
				board.cells[y][x] = "X"
				game.last_hit = LastHit{x = x, y = y, has_hit = true}
				clear_console()
				display_board("Player's Board", &game.player.my_board)
				fmt.printf("Computer hit! at %d, %d\n", y, x)
				return true
			}

			board.cells[y][x] = "M"
			fmt.println("Computer missed...")
			game.state = .TurnPlayer
			return false
		}
	} else {
		// Smart targetting
		x := game.last_hit.x
		y := game.last_hit.y

		switch game.last_hit.direction {
			case .None:
				// Try North
				if y-1 >= 0 && board.cells[y-1][x] != "X" && board.cells[y-1][x] != "M" {
					y -= 1
					game.last_hit.direction = .North
				} else {
					// Try East
					if x+1 < GRID_SIZE && board.cells[y][x+1] != "X" && board.cells[y][x+1] != "M" {
						x += 1
						game.last_hit.direction = .East
					} else {
						// Try South
						if y+1 < GRID_SIZE && board.cells[y+1][x] != "X" && board.cells[y+1][x] != "M" {
							y += 1
							game.last_hit.direction = .South
						} else {
							// Try West
							if x-1 >= 0 && board.cells[y][x-1] != "X" && board.cells[y][x-1] != "M" {
								x -= 1
								game.last_hit.direction = .West
							}
						}
					}
				}
			case .North:
				if y-1 >= 0 && board.cells[y-1][x] != "X" && board.cells[y-1][x] != "M" {
					y -= 1
				} else {
					game.last_hit.direction = .South
				}
			case .East:
				if x+1 < GRID_SIZE && board.cells[y][x+1] != "X" && board.cells[y][x+1] != "M" {
					x += 1
				} else {
					game.last_hit.direction = .West
				}
			case .South:
				if y+1 < GRID_SIZE && board.cells[y+1][x] != "X" && board.cells[y+1][x] != "M" {
					y += 1
				} else {
					game.last_hit.direction = .North
				}
			case .West:
				if x-1 >= 0 && board.cells[y][x-1] != "X" && board.cells[y][x-1] != "M" {
					x -= 1
				} else {
					game.last_hit.direction = .East
			}
		}
		// Reset if no direction works
        game.last_hit.has_hit = false
        return false
	}

}

place_computer_ships :: proc(game: ^Game, board: ^Board) {
	start_time := time.now()
    for &ship in game.computer.ships {
        ship.placed = false
        for !ship.placed {
            x := rand.int_max(GRID_SIZE)
            y := rand.int_max(GRID_SIZE)
            vertical := rand.int_max(2) == 1

            if is_valid_placement(board, x, y, ship.size, vertical) {
                // Place ship
                if vertical {
                    for i in 0..<ship.size {
                        board.cells[y+i][x] = "C"
						append(&ship.position, Vector2{i32(x), i32(y+i)})
                    }
                } else {
                    for i in 0..<ship.size {
                        board.cells[y][x+i] = "C"
						append(&ship.position, Vector2{i32(x), i32(y+i)})
                    }
                }
                ship.placed = true
            }
        }
    }
	end_time := time.now()
	delta := time.diff(start_time, end_time)
	if DEBUG {
		fmt.printf("Computer placed ships in %v \n\n", delta)
	}
}

parse_coordinates :: proc(input: string) -> (x: int, y: int, vertical: bool, ok: bool) {
	if len(input) < 3  || len(input) > 4 {
		return 0, 0, false, false
	}

	{
		// convert letters to x and y to coordinates
		x := int(input[0]) - 'a'

		y_str := input[1:len(input)-1]
		// convert string to int and decrement by 1 because of 0-based indexing
		y = strconv.atoi(y_str) -1

		if y < 0 || y >= GRID_SIZE || y >= 10 {
			return 0, 0, false, false
		}

		vertical := input[len(input)-1] == 'v'

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
			fmt.print("Enter Start coordinates (e.g. A1v or C3h) where v is vertical and h is horizontal: \n")

			num_bytes, _ := os.read(os.stdin, buf[:])

			input := string(buf[:num_bytes])
			input = strings.to_lower(strings.trim_right(input, "\r\n"))

			x, y, vertical, ok := parse_coordinates(input)

			if !ok {
				fmt.println("Invalid input. Try again")
				continue // TODO: check if this is correct
			}

			if is_valid_placement(board, x, y, ship.size, vertical) {
				// Place ship
				if vertical {
					for i in 0..<ship.size {
						board.cells[y+i][x] = "P"
					}
				} else {
					for i in 0..<ship.size {
						board.cells[y][x+i] = "P"
					}
				}
				placed = true
				clear_console()
				display_board("Your Board", &game.player.my_board)
			} else {
				fmt.println("Invalid placement")
			}
		}
	}
	fmt.println("\nAll ships placed - the game is starting!\n\n")
	game.state = .TurnPlayer
}

// is_ship_sunk :: proc(board: ^Board, ship: Ship) -> bool {
// 	for i in 0..<board.row {
// 		for j in 0..<board.column {
// 			if board.cells[i][j] == "C" {
// 				return false
// 			}
// 		}
// 	}
// 	return true
// }

restart_or_quit :: proc(game: ^Game) {
	buf: [256]byte

	for {
		fmt.print("Do you want to play again? (y/n): ")
		num_bytes, _ := os.read(os.stdin, buf[:])
		input := string(buf[:num_bytes])
		input = strings.to_lower(strings.trim_right(input, "\r\n"))

		if input == "y" {
			game.state = .PlaceShips
			break
		} else if input == "n" {
			game.is_running = false
			break
		} else {
			fmt.println("Invalid input. Try again")
		}
	}
}


clear_console :: proc() {
    fmt.print(CLEAR)
}

main :: proc() {
	game: Game
	game_init(&game)

	clear_console()

	game.state = .PlaceShips

	for game.is_running {
		switch game.state {
			case .PlaceShips:
				place_computer_ships(&game, &game.computer.my_board)
				fmt.println("Place your ships\n")
				if DEBUG {
					display_board("Computer's Board", &game.computer.my_board)
				}
				place_player_ships(&game, &game.player.my_board)
			case .TurnPlayer:
				// clear_console()
				// fmt.println("Player's turn\n\n")
				// display_board("Player's Target Board", &game.player.target_board)
				if !process_player_shot(&game, &game.player.target_board) {
					game.state = .TurnComputer
				}
			case .TurnComputer:
				clear_console()
				fmt.println("Computer's turn")
				display_board("Player's Board", &game.player.my_board)
				process_computer_shot(&game, &game.player.my_board)
			case .GameOver:
				fmt.println("Game over")
				free_all()
				game_init(&game)
				restart_or_quit(&game)
			case .Running:
				fmt.println("Game is running")
			case .Win:
				fmt.println("Player wins")
				game.state = .GameOver
			case .Lost:
				fmt.println("Computer wins")
				game.state = .GameOver
		}
	}
}
