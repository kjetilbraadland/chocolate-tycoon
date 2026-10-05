extends Node
## M1 main scene: starts a live campaign and shows the isometric factory view.
## If a save exists, restore it (run state + machine layout) before starting.
## M5: also adds the HUD layer (bottleneck / quality / pacing panels).

var _hud: CanvasLayer = null
var _mgmt: CanvasLayer = null
var _menu: CanvasLayer = null

func _ready() -> void:
	if BalanceDB.is_ready():
		# start a live run (normal, milk bar, full chain)
		GameState.new_run(EconomyData.Difficulty.NORMAL, 1,
			"RCP_MILK_BAR_01", "CHAIN_A", "CONTRACT_A")
		# restore the last save if present (run state + machine layout)
		var data: Dictionary = SaveSystem.load("slot1")
		if not data.is_empty():
			GameState.load_game(data)
			print("[main] M1 restored from save: day %d" % int(data.get("day", 0)))
		print("[main] M1 live run started (normal, milk bar, CHAIN_A)")
	else:
		push_error("[main] DATA LOAD FAILED — check data/ CSVs")
	# add the isometric factory view (HUD + camera live in there)
	var view: Node2D = load("res://src/game/factory_view.gd").new()
	add_child(view)
	# add the M5 HUD layer (bottleneck / quality / pacing panels)
	var hud: CanvasLayer = load("res://src/game/hud_view.gd").new()
	add_child(hud)
	_hud = hud
	# add the M5 management layer (unlock tree / farming / R&D)
	var mgmt: CanvasLayer = load("res://src/game/management_view.gd").new()
	add_child(mgmt)
	_mgmt = mgmt
	# add the M5 ESC pause menu (resume / save / load / options / keys / exit)
	var menu: CanvasLayer = load("res://src/game/pause_menu.gd").new()
	add_child(menu)
	_menu = menu
