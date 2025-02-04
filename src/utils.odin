package main

import "core:fmt"
import "core:os"
import "core:strings"


CLEAR: string = "\033c"
GRID_SIZE :: 10
DEBUG :: #config(DEBUG, true)

// ANSI Colors
RED :: "\x1b[31m"
GREEN :: "\x1b[32m"
YELLOW :: "\x1b[33m"
BLUE :: "\x1b[34m"
RESET :: "\x1b[0m"

RESTART_INVALID_INPUT :: "\nInvalid input. Please enter 'y' or 'n'.\n"
RESTART_MSG :: "\nDo you want to play again? (y/n): "


clear_console :: proc() {
	when !ODIN_DEBUG {
		fmt.print(CLEAR)
	}
}

debug_print :: proc(message: string, args: ..any) {
	when ODIN_DEBUG {
		fmt.printf(message, ..args)
		fmt.println("\n")
	}
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

	fmt.print(RESTART_MSG)
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

	fmt.println(RESTART_INVALID_INPUT)
	return true
}
