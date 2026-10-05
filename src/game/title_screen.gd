extends CanvasLayer
## M5: main title / start screen. Shown before the factory loads. The player
## picks a difficulty (Normal / Hard) and starts a new game (which then adds
## the factory view + HUD to the scene), or loads a save, or opens options /
## keybindings, or exits.
##
## Dark theme, full-screen dim. Headless-verifiable: build, assert visible,
## drive the action methods (new_game / load_game / options / keys), assert
## the GameState + scene state changes.

const BG := Color(0.05, 0.06, 0.09, 0.92)
const PANEL := Color(0.12, 0.14, 0.18, 0.98)
const TEXT := Color(0.92, 0.94, 0.98)
const DIM := Color(0.62, 0.66, 0.72)
const ACCENT := Color(0.45, 0.85, 0.95)
const GOOD := Color(0.45, 0.85, 0.55)

var _visible: bool = true
var _difficulty: int = EconomyData.Difficulty.NORMAL
var _buttons: Dictionary = {}
var _diff_label: Label
var _status: Label
var _title_label: Label

const KEYBINDINGS := {
	"pause / resume": "SPACE or ESC",
	"speed 1x / 2x / 4x": "1 / 2 / 3",
	"reset layout": "R",
	"save / load": "S / L",
	"toggle HUD panel": "B",
	"toggle management panel": "M",
}

func _ready() -> void:
	layer = 30
	_ensure_built()

func _ensure_built() -> void:
	if _title_label == null:
		_build()

func _build() -> void:
	# full-screen dim
	var dim := ColorRect.new()
	dim.color = BG
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	# centered panel
	var panel := Panel.new()
	var vp: Vector2 = Vector2(1280, 720)
	var v: Window = get_viewport()
	if v != null:
		vp = v.get_visible_rect().size
	panel.position = Vector2(vp.x / 2.0 - 220, vp.y / 2.0 - 260)
	panel.size = Vector2(440, 520)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	# title
	_title_label = Label.new()
	_title_label.position = Vector2(24, 24)
	_title_label.text = "CHOCOLATE FACTORY TYCOON"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", ACCENT)
	panel.add_child(_title_label)
	var sub := Label.new()
	sub.position = Vector2(24, 60)
	sub.text = "build the line. tune the batch. ship the chocolate."
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", DIM)
	panel.add_child(sub)
	# difficulty
	var y: float = 110
	var dl := Label.new()
	dl.position = Vector2(24, y)
	dl.text = "Difficulty"
	dl.add_theme_font_size_override("font_size", 14)
	dl.add_theme_color_override("font_color", DIM)
	panel.add_child(dl)
	_diff_label = Label.new()
	_diff_label.position = Vector2(24, y + 24)
	_diff_label.add_theme_font_size_override("font_size", 16)
	_diff_label.add_theme_color_override("font_color", GOOD)
	panel.add_child(_diff_label)
	_buttons["diff"] = _button(panel, y + 52, "Difficulty:  Normal")
	# main actions
	_buttons["new"] = _button(panel, y + 96, "New game")
	_buttons["load"] = _button(panel, y + 140, "Load game")
	_buttons["options"] = _button(panel, y + 184, "Options")
	_buttons["keys"] = _button(panel, y + 228, "Keybindings")
	_buttons["exit"] = _button(panel, y + 272, "Exit")
	_status = Label.new()
	_status.position = Vector2(24, y + 320)
	_status.custom_minimum_size = Vector2(392, 0)
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", DIM)
	panel.add_child(_status)
	_refresh_diff()

func _button(p: Node, y: float, text: String) -> Button:
	var b := Button.new()
	b.position = Vector2(24, y)
	b.size = Vector2(392, 36)
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	p.add_child(b)
	return b

func _refresh_diff() -> void:
	if _diff_label == null:
		return
	_diff_label.text = "Normal" if _difficulty == EconomyData.Difficulty.NORMAL else "Hard"
	_buttons["diff"].text = "Difficulty:  " + _diff_label.text

# --- Menu actions (driven by buttons; also called directly in tests) ---
func action_cycle_difficulty() -> void:
	_difficulty = EconomyData.Difficulty.HARD if _difficulty == EconomyData.Difficulty.NORMAL else EconomyData.Difficulty.NORMAL
	_refresh_diff()

# Start a new game: create the run + add the factory view + HUD to the scene.
func action_new_game() -> void:
	_ensure_built()
	GameState.new_run(_difficulty, 1, "RCP_MILK_BAR_01", "CHAIN_A", "CONTRACT_A")
	_enter_gameplay()
	hide_screen()

# Load a save: restore the run + add the factory view + HUD.
func action_load_game() -> void:
	_ensure_built()
	var data: Dictionary = SaveSystem.load("slot1")
	if data.is_empty():
		_status.text = "no save in slot1"
		return
	# create a run to host the restored state, then load into it
	GameState.new_run(int(data.get("difficulty", 0)) as EconomyData.Difficulty,
		int(data.get("seed", 0)), "RCP_MILK_BAR_01", "CHAIN_A", "CONTRACT_A")
	GameState.load_game(data)
	_enter_gameplay()
	hide_screen()

# Add the factory view + HUD + management + pause menu to the scene.
# Guarded so the core logic (new_run + hide) works headlessly (no tree /
# no BalanceDB autoload).
func _enter_gameplay() -> void:
	var t: SceneTree = get_tree()
	if t == null or t.root == null:
		return
	if not BalanceDB.is_ready():
		return
	var view: Node2D = load("res://src/game/factory_view.gd").new()
	t.root.add_child(view)
	var hud: CanvasLayer = load("res://src/game/hud_view.gd").new()
	t.root.add_child(hud)
	var mgmt: CanvasLayer = load("res://src/game/management_view.gd").new()
	t.root.add_child(mgmt)
	var menu: CanvasLayer = load("res://src/game/pause_menu.gd").new()
	t.root.add_child(menu)

func action_options() -> void:
	_ensure_built()
	# cycle the default speed for new games
	match GameState.speed:
		1: GameState.speed = 2
		2: GameState.speed = 4
		4: GameState.speed = 1
		_: GameState.speed = 1
	_status.text = "default speed now %dx" % GameState.speed

func action_keys() -> void:
	_ensure_built()
	var lines: Array = []
	for k in KEYBINDINGS:
		lines.append("%s: %s" % [k, KEYBINDINGS[k]])
	_status.text = "  |  ".join(lines)

func action_exit() -> void:
	get_tree().quit()

func is_shown() -> bool:
	return _visible

func hide_screen() -> void:
	_visible = false
	visible = false

func show_screen() -> void:
	_visible = true
	visible = true
