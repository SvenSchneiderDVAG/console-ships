package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:time"

LOG_FILE :: "../game.log"

ERR_FILE :: "Error opening file: %v\n"

NEW_GAME_MSG :: "=== New Game Started at %v ===\n"
GAME_QUIT_MSG :: "Game quit by player.\n"
GAME_WON_MSG :: "Game won by %s!\n"
SHOT_AT_MSG :: "%s shot at %c%d: %s\n"
PLACED_AT_MSG :: "%s placed %s at: "
SHIP_SUNK_MSG :: "%s sunk %s's %s!\n"

GameLogger :: struct {
	file_handle: os.Handle,
}

init_logger :: proc() -> (logger: GameLogger, ok: bool) {
	when ODIN_OS == .Windows {
		handle, err := os.open(LOG_FILE, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0)
	} else {
		handle, err := os.open(LOG_FILE, os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o644)
	}
	if err != 0 {
		fmt.eprintln(ERR_FILE, err)
		return GameLogger{}, false
	}
	return GameLogger{file_handle = handle}, true
}

log_game_start :: proc(logger: ^GameLogger) {
	fmt.fprintf(logger.file_handle, NEW_GAME_MSG, time.now())
}

log_ship_placement :: proc(logger: ^GameLogger, is_player: bool, ship: Ship) {
	owner := is_player ? "Player" : "Computer"
	fmt.fprintf(logger.file_handle, PLACED_AT_MSG, owner, ship.name)
	for pos, i in ship.position {
		fmt.fprintf(logger.file_handle, "%c%d", pos.x + 'A', pos.y + 1)
		if i < len(ship.position) - 1 {
			fmt.fprintf(logger.file_handle, ", ")
		}
	}
	fmt.fprintf(logger.file_handle, "\n")
}

log_shot :: proc(logger: ^GameLogger, is_player: bool, x, y: int, hit: bool) {
	owner := is_player ? "Player" : "Computer"
	result := hit ? "HIT" : "MISS"
	fmt.fprintf(logger.file_handle, SHOT_AT_MSG, owner, x + 'A', y + 1, result)
}

log_ship_sunk :: proc(logger: ^GameLogger, is_player: bool, ship_name: string) {
	owner := is_player ? "Player" : "Computer"
	victim := is_player ? "Computer" : "Player"
	fmt.fprintf(logger.file_handle, SHIP_SUNK_MSG, owner, victim, "ship")
}

log_quit :: proc(logger: ^GameLogger) {
	fmt.fprintf(logger.file_handle, GAME_QUIT_MSG)
}

log_game_over :: proc(logger: ^GameLogger, is_player: bool) {
	owner := is_player ? "Player" : "Computer"
	fmt.fprintf(logger.file_handle, GAME_WON_MSG, owner)
}

close_logger :: proc(logger: ^GameLogger) {
	os.close(logger.file_handle)
}
