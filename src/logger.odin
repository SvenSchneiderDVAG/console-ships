package main

import "base:runtime"
import "core:fmt"
import "core:os"
import "core:time"

LOG_FILE :: "../game.log"

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
		fmt.eprintln("Failed to open log file:", err)
		return GameLogger{}, false
	}
	return GameLogger{file_handle = handle}, true
}

log_game_start :: proc(logger: ^GameLogger) {
	fmt.fprintf(logger.file_handle, "\n=== New Game Started at %v ===\n", time.now())
}

log_ship_placement :: proc(logger: ^GameLogger, is_player: bool, ship: Ship) {
	owner := is_player ? "Player" : "Computer"
	fmt.fprintf(logger.file_handle, "%s %s placed at: ", owner, ship.name)
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
	fmt.fprintf(logger.file_handle, "%s shot at %c%d: %s\n", owner, x + 'A', y + 1, result)
}

log_ship_sunk :: proc(logger: ^GameLogger, is_player: bool, ship_name: string) {
	owner := is_player ? "Player" : "Computer"
	victim := is_player ? "Computer" : "Player"
	fmt.fprintf(logger.file_handle, "%s sunk %s's %s!\n", owner, victim, "ship")
}

log_quit :: proc(logger: ^GameLogger) {
	fmt.fprintf(logger.file_handle, "Game quit by player\n")
}

log_game_over :: proc(logger: ^GameLogger, is_player: bool) {
	owner := is_player ? "Player" : "Computer"
	fmt.fprintf(logger.file_handle, "%s won the game!\n", owner)
}

close_logger :: proc(logger: ^GameLogger) {
	os.close(logger.file_handle)
}
