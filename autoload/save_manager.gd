extends Node

## SaveManager: Handles persistent progression, settings, and high scores via JSON storage.

signal data_loaded
signal data_saved

const SAVE_PATH: String = "user://sky_adventure_save.json"

var high_wave: int = 1
var total_coins: int = 0
var high_score: int = 0
var unlocked_islands: Array = ["sector_1"]
var permanent_upgrades: Dictionary = {
	"bonus_health": 0,
	"bonus_damage": 0,
	"bonus_magnet": 0
}

var master_volume: float = 1.0
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var mouse_sensitivity: float = 1.0
var mobile_sensitivity: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: Unable to open save file for reading.")
		return

	var content: String = file.get_as_text()
	file.close()

	var test_json_conv = JSON.new()
	var parse_result = test_json_conv.parse(content)
	if parse_result != OK:
		push_warning("SaveManager: Save data corrupted, using default state.")
		return

	var data: Dictionary = test_json_conv.data
	if data.has("high_wave"):
		high_wave = int(data["high_wave"])
	if data.has("total_coins"):
		total_coins = int(data["total_coins"])
	if data.has("high_score"):
		high_score = int(data["high_score"])
	if data.has("unlocked_islands") and data["unlocked_islands"] is Array:
		unlocked_islands = data["unlocked_islands"]
	if data.has("permanent_upgrades") and data["permanent_upgrades"] is Dictionary:
		permanent_upgrades = data["permanent_upgrades"]
	if data.has("master_volume"):
		master_volume = float(data["master_volume"])
	if data.has("music_volume"):
		music_volume = float(data["music_volume"])
	if data.has("sfx_volume"):
		sfx_volume = float(data["sfx_volume"])
	if data.has("mouse_sensitivity"):
		mouse_sensitivity = float(data["mouse_sensitivity"])
	if data.has("mobile_sensitivity"):
		mobile_sensitivity = float(data["mobile_sensitivity"])

	data_loaded.emit()


func save_game() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Unable to open save file for writing.")
		return

	var data: Dictionary = {
		"high_wave": high_wave,
		"total_coins": total_coins,
		"high_score": high_score,
		"unlocked_islands": unlocked_islands,
		"permanent_upgrades": permanent_upgrades,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"mouse_sensitivity": mouse_sensitivity,
		"mobile_sensitivity": mobile_sensitivity
	}

	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()

	data_saved.emit()


func bank_run_results(wave_reached: int, coins_earned: int, score_earned: int) -> void:
	total_coins += coins_earned
	if wave_reached > high_wave:
		high_wave = wave_reached
	if score_earned > high_score:
		high_score = score_earned
	save_game()


func unlock_island(sector_id: String) -> void:
	if not sector_id in unlocked_islands:
		unlocked_islands.append(sector_id)
		save_game()


func reset_save_data() -> void:
	high_wave = 1
	total_coins = 0
	high_score = 0
	unlocked_islands = ["sector_1"]
	permanent_upgrades = {
		"bonus_health": 0,
		"bonus_damage": 0,
		"bonus_magnet": 0
	}
	mouse_sensitivity = 1.0
	mobile_sensitivity = 1.0
	save_game()
