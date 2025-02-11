package main

import "core:fmt"
import "core:time"

INIT_GAME_DBG :: "Initializing game...\n"
INIT_BOARDS_DBG :: "Initializing game boards...\n"

TITLE_MSG :: "Welcome to Terminal-Battleships " + VERSION + "\n\n"

LONG_PAUSE :: 2
SHORT_PAUSE :: 500
NUM_SHIPS :: 5

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
	ships:        [NUM_SHIPS]Ship,
	my_board:     Board,
	target_board: Board,
	turns:        int,
}

Direction :: enum {
	None  = -1,
	North = 0,
	South = 1,
	East  = 2,
	West  = 3,
}

LastHit :: struct {
	x, y:             int,
	first_x, first_y: int,
	direction:        Direction,
	vertical:         bool,
	horizontal:       bool,
	has_hit:          bool,
	tried_directions: [4]bool,
}

Game :: struct {
	board:      Board,
	player:     Player,
	computer:   Player,
	state:      States,
	turns:      int,
	is_running: bool,
	last_hit:   LastHit,
	logger:     GameLogger,
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

game_init :: proc(game: ^Game) {
	debug_print(INIT_GAME_DBG)
	game.player.name = "Player"
	game.computer.name = "Computer"

	logger, ok := init_logger()
	if ok {
		game.logger = logger
		log_game_start(&game.logger)
	}

	ship_sizes := []int{5, 4, 3, 3, 2}
	for i in 0 ..< len(ship_sizes) {
		ship_type: Ships
		switch i {
		case 0:
			ship_type = .Carrier
		case 1:
			ship_type = .Battleship
		case 2:
			ship_type = .Cruiser
		case 3:
			ship_type = .Submarine
		case 4:
			ship_type = .Destroyer
		}
		game.computer.ships[i] = Ship {
			name = ship_type,
			size = ship_sizes[i],
		}
		game.player.ships[i] = Ship {
			name = ship_type,
			size = ship_sizes[i],
		}
	}

	debug_print(INIT_BOARDS_DBG)

	make_board(&game.player.my_board)
	make_board(&game.player.target_board)
	make_board(&game.computer.my_board)

	game.player.turns = 0
	game.computer.turns = 0
	game.last_hit = {}
	game.last_hit = LastHit {
		direction = .None,
	}
	game.state = .PlaceShips

	clear_console()
	fmt.println(TITLE_MSG)
	time.sleep(LONG_PAUSE * time.Second)
}
