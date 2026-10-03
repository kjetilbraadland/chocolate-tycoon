extends Node
## M0 placeholder main scene. The full isometric factory view, camera, and HUD
## land in M1. For now: verify the data layer loaded and show a status label.

@onready var _status: Label = $Status

func _ready() -> void:
	var lines: Array = []
	lines.append("Chocolate Factory Tycoon — M0 Foundation")
	if BalanceDB.is_ready():
		lines.append("Data OK: %d recipes, %d machines, %d economy, %d sim rows" % [
			BalanceDB.db.recipes.size(), BalanceDB.db.machines.size(),
			BalanceDB.db.economy.size(), BalanceDB.db.sim_rows.size()])
	else:
		lines.append("DATA LOAD FAILED — check data/ CSVs")
	lines.append("Core sim, quality/economy/contracts/shop, and headless tests are wired.")
	lines.append("Run tests: godot --headless -s tests/run_headless.gd all")
	_status.text = "\n".join(lines)
