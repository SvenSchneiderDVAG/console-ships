package main

import "core:fmt"

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
			// fmt.println("Computer's turn\n\n")
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
