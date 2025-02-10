package main

import "core:fmt"

VERSION :: "0.1.0"

PLACE_SHIPS_MSG :: "\nPlace your ships on the board\n"
GAME_OVER_MSG :: "\nGame Over.\n"
WIN_MSG :: "\nCongratulations! %s wins in %d turns!\n"

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
			fmt.println(PLACE_SHIPS_MSG)
			place_player_ships(&game, &game.player.my_board)
		case .TurnPlayer:
			if !process_player_shot(&game, &game.player.target_board) {
				game.state = .TurnComputer
			}
			check_win_condition(&game, &game.player.target_board)
		case .TurnComputer:
			// fmt.println("Computer's turn\n\n")
			display_board("Player's Board", &game.player.my_board)
			if !process_computer_shot(&game, &game.player.my_board) {
				game.state = .TurnPlayer
			}
			check_win_condition(&game, &game.player.my_board)
		case .GameOver:
			fmt.println(GAME_OVER_MSG)
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
			fmt.printf(WIN_MSG, game.player.name, game.player.turns)
			game.state = .GameOver
		case .Lost:
			fmt.printf(WIN_MSG, game.computer.name, game.computer.turns)
			game.state = .GameOver
		}
	}
}
