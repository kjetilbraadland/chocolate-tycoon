extends CanvasLayer
## M5: ESC pause menu. Pressing ESC pauses the live run and shows a menu with:
##   - Resume (ESC again / R)
##   - Save game (slot1)
##   - Load game (slot1)
##   - Options (speed 1x/2x/4x)
##   - Keybindings (shows the current control map)
##   - Exit (quits the game)
##
## The menu owns the pause: opening it sets GameState.running = false, closing
## it (Resume) sets it back to true. Headless-verifiable: build, open, assert
## the menu is visible + the game is paused, then close + assert resumed.

const BG := Color(0.05, 0.06, 0.09, 0.85)
const PANEL := Color(0.12, 0.14, 0.18, 0.98)
const TEXT := Color(0.92, 0.94, 0.98)
const DIM := Color(0.62, 0.66, 0.72)
const ACCENT := Color(0.45, 0.85, 0.95)

var _open: bool = false
var _was_running: bool = false
var _dim: ColorRect
var _panel: Panel
var _buttons: Dictionary = {}
var _status: Label

# The current keybinding map (shown in the menu + testable).
const KEYBINDINGS := {
	"pause / resume": "SPACE or ESC",
	"speed 1x": "1",
	"speed 2x": "2",
	"speed 4x": "3",
	"reset layout": "R",
	"save game": "S (or menu)",
	"load game": "L (or menu)",
	"toggle HUD panel": "B",
	"toggle management panel": "M",
}

func _ready() -> void:
	layer = 20
	_ensure_built()

# Idempotent build (so a headless test can call open() before _ready fires).
func _ensure_built() -> void:
	if _panel == null:
		_build()

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = BG
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)
	_panel = Panel.new()
	var vp: Vector2 = Vector2(1280, 720)
	var v: Window = get_viewport()
	if v != null:
		vp = v.get_visible_rect().size
	_panel.position = Vector2(vp.x / 2.0 - 200, vp.y / 2.0 - 220)
	_panel.size = Vector2(400, 440)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(20)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.visible = false
	add_child(_panel)
	_build_buttons()

func _build_buttons() -> void:
	var y: float = 20
	var title := Label.new()
	title.position = Vector2(20, y)
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", ACCENT)
	_panel.add_child(title)
	y += 50
	_buttons["resume"] = _button(y, "Resume"); y += 40
	_buttons["save"] = _button(y, "Save game"); y += 40
	_buttons["load"] = _button(y, "Load game"); y += 40
	_buttons["options"] = _button(y, "Options"); y += 40
	_buttons["keys"] = _button(y, "Keybindings"); y += 40
	_buttons["exit"] = _button(y, "Exit"); y += 50
	_status = Label.new()
	_status.position = Vector2(20, y)
	_status.custom_minimum_size = Vector2(360, 0)
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", DIM)
	_panel.add_child(_status)

func _button(y: float, text: String) -> Button:
	var b := Button.new()
	b.position = Vector2(20, y)
	b.size = Vector2(360, 34)
	b.text = text
	b.add_theme_font_size_override("font_size", 15)
	_panel.add_child(b)
	return b

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _open:
			close()
		else:
			open()

# Open the menu: pause the run + show the panel.
func open() -> void:
	if _open:
		return
	_ensure_built()
	_was_running = GameState.running
	GameState.running = false
	_open = true
	_dim.visible = true
	_panel.visible = true
	_status.text = ""

# Close the menu: resume the run + hide the panel.
func close() -> void:
	if not _open:
		return
	_open = false
	_dim.visible = false
	_panel.visible = false
	if _was_running:
		GameState.running = true

func is_open() -> bool:
	return _open

# --- Menu actions (driven by buttons; also called directly in tests) ---
func action_resume() -> void:
	close()

func action_save() -> void:
	_ensure_built()
	if GameState.campaign != null:
		var ok: bool = SaveSystem.save("slot1", GameState.campaign.sim)
		_status.text = "saved to slot1" if ok else "save failed"

func action_load() -> void:
	_ensure_built()
	var data: Dictionary = SaveSystem.load("slot1")
	if not data.is_empty():
		GameState.load_game(data)
		_status.text = "loaded from slot1"
	else:
		_status.text = "no save in slot1"

func action_options() -> void:
	# cycle speed 1 -> 2 -> 4 -> 1
	match GameState.speed:
		1: GameState.speed = 2
		2: GameState.speed = 4
		4: GameState.speed = 1
		_: GameState.speed = 1
	_ensure_built()
	_status.text = "speed now %dx" % GameState.speed

func action_keys() -> void:
	_ensure_built()
	var lines: Array = []
	for k in KEYBINDINGS:
		lines.append("%s: %s" % [k, KEYBINDINGS[k]])
	_status.text = "  |  ".join(lines)

func action_exit() -> void:
	get_tree().quit()
