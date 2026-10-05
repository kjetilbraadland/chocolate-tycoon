extends Node
## M5 main scene: shows the TITLE SCREEN first. Starting a new game (or
## loading a save) from the title screen creates the live run and adds the
## isometric factory view + HUD + management panel + ESC pause menu.
## If a save exists it is available via "Load game" on the title screen.

var _title: CanvasLayer = null

func _ready() -> void:
	if not BalanceDB.is_ready():
		push_error("[main] DATA LOAD FAILED — check data/ CSVs")
		return
	# show the title screen first (the factory loads on New Game / Load)
	_title = load("res://src/game/title_screen.gd").new()
	add_child(_title)
	print("[main] M5 title screen shown — start a game from there")
