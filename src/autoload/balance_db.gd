extends Node
## Autoload: holds the loaded BalanceDatabase (single source of truth for balance).
## Game code reads balance values ONLY through this.

var db: BalanceDatabase

func _ready() -> void:
	db = BalanceDatabase.new()
	var ok: bool = db.load_all()
	if ok:
		print("[BalanceDB] loaded: %d recipes, %d machines, %d economy knobs, %d sim rows" % [
			db.recipes.size(), db.machines.size(), db.economy.size(), db.sim_rows.size()])
	else:
		push_error("[BalanceDB] FAILED to load: " + str(db.load_errors))

func is_ready() -> bool:
	return db != null and db.recipes.size() > 0 and db.machines.size() > 0
