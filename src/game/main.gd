extends Node
## M1 main scene: starts a live campaign and shows the isometric factory view.

func _ready() -> void:
	if BalanceDB.is_ready():
		# start a live run (normal, milk bar, full chain)
		GameState.new_run(EconomyData.Difficulty.NORMAL, 1,
			"RCP_MILK_BAR_01", "CHAIN_A", "CONTRACT_A")
		print("[main] M1 live run started (normal, milk bar, CHAIN_A)")
	else:
		push_error("[main] DATA LOAD FAILED — check data/ CSVs")
	# add the isometric factory view (HUD + camera live in there)
	var view: Node2D = load("res://src/game/factory_view.gd").new()
	add_child(view)
