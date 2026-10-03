extends Node
## Autoload: save/load. Save = JSON of run state (seed, difficulty, day/tick,
## core state). 3 slots + autosave at day close.

const SAVE_DIR := "user://saves/"

func _ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func _path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"

func save(slot: String, sim: Simulation) -> bool:
	_ensure_dir()
	var data := {
		"seed": sim.seed,
		"difficulty": int(sim.diff),
		"day": sim.day,
		"tick_in_day": sim.tick_in_day,
		"brand_score": sim.brand_score,
		"category_reputation": sim.category_reputation,
		"cash": sim.economy.cash,
		"debt": sim.economy.debt,
		"total_units_produced": sim.total_units_produced,
		"total_revenue": sim.total_revenue,
		"total_cost": sim.total_cost,
		"saved_at": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

func load(slot: String) -> Dictionary:
	if not FileAccess.file_exists(_path(slot)):
		return {}
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	return JSON.parse_string(text) if text != "" else {}

func list_saves() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fn: String = dir.next_file()
	while fn != "":
		if fn.ends_with(".json"):
			out.append(fn.get_file())
		fn = dir.next_file()
	return out
