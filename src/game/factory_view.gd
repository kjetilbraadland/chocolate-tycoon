extends Node2D
## M1 isometric factory view. Renders the production line (from the live
## Campaign) as an isometric grid of machine tiles, with a camera (pan/zoom)
## and a HUD. Cozy palette per GDD §11.

const TILE_W: float = 64.0
const TILE_H: float = 32.0

var _camera: Camera2D
var _line_nodes: Array = []
var _hud: CanvasLayer
var _labels: Dictionary = {}

# cozy palette
const COL_FLOOR := Color(0.16, 0.14, 0.12)
const COL_TILE_A := Color(0.32, 0.26, 0.20)
const COL_TILE_B := Color(0.28, 0.23, 0.18)
const COL_MACH := Color(0.72, 0.55, 0.35)
const COL_MACH_RUN := Color(0.95, 0.80, 0.45)
const COL_MACH_STOP := Color(0.55, 0.45, 0.40)
const COL_TEXT := Color(0.92, 0.86, 0.75)
const COL_ACCENT := Color(0.85, 0.65, 0.35)

func _ready() -> void:
	_build_camera()
	_build_grid()
	_build_hud()
	GameState.start()

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.0, 1.0)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)

func _iso(x: int, y: int) -> Vector2:
	# isometric projection
	return Vector2((x - y) * TILE_W / 2.0, (x + y) * TILE_H / 2.0)

func _build_grid() -> void:
	# ground
	var ground := Polygon2D.new()
	ground.color = COL_FLOOR
	ground.polygon = PackedVector2Array([
		_iso(-1, -1), _iso(9, -1), _iso(9, 9), _iso(-1, 9)])
	add_child(ground)

	# one tile row for the 7-stage chain
	var cam := GameState.campaign
	if cam == null:
		return
	var chain: Array = BalanceDB.db.lookup.chain_machine_ids(cam.chain_id)
	for i in range(chain.size()):
		var md: MachineData = BalanceDB.db.get_machine(chain[i])
		if md == null:
			continue
		_place_machine(md, i)

func _place_machine(md: MachineData, idx: int) -> void:
	var pos: Vector2 = _iso(idx, 0)
	# tile
	var tile := Polygon2D.new()
	tile.color = COL_TILE_A if idx % 2 == 0 else COL_TILE_B
	tile.polygon = PackedVector2Array([
		pos + Vector2(0, -TILE_H / 2.0),
		pos + Vector2(TILE_W / 2.0, 0),
		pos + Vector2(0, TILE_H / 2.0),
		pos + Vector2(-TILE_W / 2.0, 0)])
	add_child(tile)
	# machine block
	var block := Polygon2D.new()
	block.color = COL_MACH
	block.polygon = PackedVector2Array([
		pos + Vector2(0, -TILE_H / 2.0 - 26.0),
		pos + Vector2(TILE_W / 2.0 - 8.0, -13.0 - 26.0),
		pos + Vector2(TILE_W / 2.0 - 8.0, -13.0),
		pos + Vector2(0, 0),
		pos + Vector2(-TILE_W / 2.0 + 8.0, -13.0),
		pos + Vector2(-TILE_W / 2.0 + 8.0, -13.0 - 26.0)])
	add_child(block)
	# label
	var label := Label.new()
	label.text = md.machine_name
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COL_TEXT)
	label.position = pos + Vector2(-60, 12)
	label.custom_minimum_size = Vector2(120, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	_line_nodes.append({ "block": block, "label": label, "idx": idx })

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var top := Label.new()
	top.name = "TopBar"
	top.position = Vector2(20, 16)
	top.add_theme_font_size_override("font_size", 18)
	top.add_theme_color_override("font_color", COL_ACCENT)
	_hud.add_child(top)
	var build := Label.new()
	build.name = "BuildStamp"
	build.position = Vector2(20, 44)
	build.add_theme_font_size_override("font_size", 12)
	build.add_theme_color_override("font_color", COL_TEXT)
	build.text = "Chocolate Factory Tycoon — M1 build"
	_hud.add_child(build)
	var status := Label.new()
	status.name = "StatusLine"
	status.position = Vector2(20, 68)
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", COL_TEXT)
	_hud.add_child(status)
	# control hint
	var hint := Label.new()
	hint.position = Vector2(20, 872)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", COL_TEXT)
	hint.text = "SPACE: pause/play   1/2/3: speed 1x/2x/4x   drag: pan   wheel: zoom"
	_hud.add_child(hint)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_SPACE:
				GameState.toggle()
			KEY_1:
				GameState.speed = 1
			KEY_2:
				GameState.speed = 2
			KEY_3:
				GameState.speed = 4
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_camera.zoom = _camera.zoom * 1.1
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_camera.zoom = _camera.zoom / 1.1
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_camera.position -= mm.relative / _camera.zoom

func _process(_delta: float) -> void:
	var cam := GameState.campaign
	if cam == null:
		return
	# update machine block colors by state
	for ln in _line_nodes:
		var idx: int = ln.idx
		var block: Polygon2D = ln.block
		if idx < cam.sim.line.machines.size():
			var m: MachineState = cam.sim.line.machines[idx]
			match m.state:
				MachineState.State.RUNNING:
					block.color = COL_MACH_RUN
				MachineState.State.BREAKDOWN, MachineState.State.REPAIRING:
					block.color = COL_MACH_STOP
				_:
					block.color = COL_MACH
	# HUD
	var top: Label = _hud.get_node("TopBar")
	var status: Label = _hud.get_node("StatusLine")
	var eco: Economy = cam.sim.economy
	var running_str: String = "RUNNING" if GameState.running else "PAUSED"
	top.text = "Day %d  |  Cash: %.0f  |  Debt: %.0f  |  %dx" % [
		cam.sim.day, eco.cash, eco.debt, GameState.speed]
	var last_q: String = ""
	var last_grade: String = ""
	var last_sold: float = 0.0
	if not cam.day_results.is_empty():
		var lr: Dictionary = cam.day_results[cam.day_results.size() - 1]
		last_q = "Q=%.0f" % lr.quality_q
		last_grade = lr.grade
		last_sold = lr.sold
	status.text = "%s  |  produced: %.0f  |  sold: %.0f  |  %s %s  |  %s" % [
		running_str, cam.sim.total_units_produced,
		last_sold, last_q, last_grade,
		"BANKRUPT" if eco.is_bankrupt else "OK"]
