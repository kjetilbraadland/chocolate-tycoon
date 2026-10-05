extends Node2D
## M1 isometric factory view with a MACHINE PLACEMENT GRID. Renders the live
## Campaign's production line as an isometric grid of machine tiles. The player
## can DRAG any machine onto any free tile (the "build the factory" interaction);
## dragging empty ground pans the camera. Machine state colors (running/broken/
## idle) update live from the sim. Layout is persisted via GameState.
##
## Controls:
##   drag a machine  -> move it to a free tile
##   drag empty ground -> pan camera
##   wheel           -> zoom
##   SPACE           -> pause/play
##   1 / 2 / 3       -> speed 1x / 2x / 4x
##   R               -> reset layout to default

const TILE_W: float = 64.0
const TILE_H: float = 32.0
const GRID_SIZE: int = 8  # tiles 0..7 on each axis

var _camera: Camera2D
var _hud: CanvasLayer
var _grid_tiles: Array = []  # floor tile polygons (for rendering)
var _machine_nodes: Dictionary = {}  # machine_id -> { "block", "label", "tile" }
var _machine_layout: Dictionary = {}  # machine_id -> Vector2i (grid coords)
var _ghost: Polygon2D  # placement preview
var _drag_machine: String = ""
var _panning: bool = false

# cozy palette
const COL_FLOOR := Color(0.16, 0.14, 0.12)
const COL_TILE_A := Color(0.32, 0.26, 0.20)
const COL_TILE_B := Color(0.28, 0.23, 0.18)
const COL_TILE_GRID := Color(0.20, 0.18, 0.15)
const COL_MACH := Color(0.72, 0.55, 0.35)
const COL_MACH_RUN := Color(0.95, 0.80, 0.45)
const COL_MACH_STOP := Color(0.55, 0.45, 0.40)
const COL_TEXT := Color(0.92, 0.86, 0.75)
const COL_ACCENT := Color(0.85, 0.65, 0.35)
const COL_GHOST_OK := Color(0.45, 0.85, 0.45, 0.5)
const COL_GHOST_BAD := Color(0.85, 0.40, 0.40, 0.5)

func _ready() -> void:
	_build_camera()
	_build_grid()
	_build_machines()
	_build_ghost()
	_build_hud()
	_apply_saved_layout()
	GameState.start()

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.zoom = Vector2(1.0, 1.0)
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	# center on the grid
	_camera.position = _iso(3, 3)
	add_child(_camera)

func _iso(x: float, y: float) -> Vector2:
	return Vector2((x - y) * TILE_W / 2.0, (x + y) * TILE_H / 2.0)

# Inverse iso: world point -> grid coords (float).
func _world_to_grid(w: Vector2) -> Vector2:
	var dx: float = w.x / (TILE_W / 2.0)
	var dy: float = w.y / (TILE_H / 2.0)
	return Vector2((dx + dy) / 2.0, (dy - dx) / 2.0)

func _tile_polygon(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0, -TILE_H / 2.0),
		center + Vector2(TILE_W / 2.0, 0),
		center + Vector2(0, TILE_H / 2.0),
		center + Vector2(-TILE_W / 2.0, 0)])

func _machine_block_polygon(center: Vector2) -> PackedVector2Array:
	var h: float = 26.0
	return PackedVector2Array([
		center + Vector2(0, -TILE_H / 2.0 - h),
		center + Vector2(TILE_W / 2.0 - 8.0, -TILE_H / 4.0 - h),
		center + Vector2(TILE_W / 2.0 - 8.0, -TILE_H / 4.0),
		center + Vector2(0, 0),
		center + Vector2(-TILE_W / 2.0 + 8.0, -TILE_H / 4.0),
		center + Vector2(-TILE_W / 2.0 + 8.0, -TILE_H / 4.0 - h)])

func _build_grid() -> void:
	# ground
	var ground := Polygon2D.new()
	ground.color = COL_FLOOR
	ground.polygon = PackedVector2Array([
		_iso(-1, -1), _iso(GRID_SIZE, -1), _iso(GRID_SIZE, GRID_SIZE), _iso(-1, GRID_SIZE)])
	add_child(ground)
	# floor tiles
	for gx in range(GRID_SIZE):
		for gy in range(GRID_SIZE):
			var t := Polygon2D.new()
			t.color = COL_TILE_A if (gx + gy) % 2 == 0 else COL_TILE_B
			t.polygon = _tile_polygon(_iso(gx, gy))
			add_child(t)
			_grid_tiles.append(t)

func _build_machines() -> void:
	var cam := GameState.campaign
	if cam == null:
		return
	var chain: Array = BalanceDB.db.lookup.chain_machine_ids(cam.chain_id)
	for i in range(chain.size()):
		var mid: String = chain[i]
		var md: MachineData = BalanceDB.db.get_machine(mid)
		if md == null:
			continue
		# default layout: a row along y=0
		_machine_layout[mid] = Vector2i(i, 0)
		var tile := Polygon2D.new()
		tile.color = COL_TILE_GRID
		var block := Polygon2D.new()
		block.color = COL_MACH
		var label := Label.new()
		label.text = md.machine_name
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", COL_TEXT)
		label.custom_minimum_size = Vector2(120, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(tile)
		add_child(block)
		add_child(label)
		# M5: procedural machine visual (type-specific details on top of the base)
		var details: Array = []
		var vis: Array = MachineVisual.build(md.stage, _iso(0, 0))
		for v in vis:
			if v.polygon == vis[0].polygon:
				continue  # the base is the block itself
			var p := Polygon2D.new()
			p.color = v.color
			add_child(p)
			details.append(p)
		_machine_nodes[mid] = { "block": block, "label": label, "tile": tile, "details": details }
		_place_machine(mid)

func _place_machine(mid: String) -> void:
	var node: Dictionary = _machine_nodes[mid]
	var pos: Vector2 = _iso(_machine_layout[mid].x, _machine_layout[mid].y)
	(node.tile as Polygon2D).polygon = _tile_polygon(pos)
	(node.block as Polygon2D).polygon = _machine_block_polygon(pos)
	(node.label as Label).position = pos + Vector2(-60, 12)
	# reposition the type-specific detail polygons onto this tile
	var vis: Array = MachineVisual.build(_machine_stage(mid), pos)
	var details: Array = node.details
	var di: int = 0
	for v in vis:
		if v.polygon == vis[0].polygon:
			continue
		if di < details.size():
			(details[di] as Polygon2D).polygon = v.polygon
		di += 1

func _build_ghost() -> void:
	_ghost = Polygon2D.new()
	_ghost.color = COL_GHOST_OK
	_ghost.visible = false
	add_child(_ghost)

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
	build.text = "Chocolate Factory Tycoon — M1 build (placement grid)"
	_hud.add_child(build)
	var status := Label.new()
	status.name = "StatusLine"
	status.position = Vector2(20, 68)
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", COL_TEXT)
	_hud.add_child(status)
	var hint := Label.new()
	hint.position = Vector2(20, 872)
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", COL_TEXT)
	hint.text = "drag machine: move   drag ground: pan   wheel: zoom   SPACE: pause   1/2/3: speed   R: reset   S: save   L: load"
	_hud.add_child(hint)

func _apply_saved_layout() -> void:
	var saved: Dictionary = GameState.machine_layout
	if saved.is_empty():
		return
	for mid in _machine_nodes.keys():
		if saved.has(mid):
			_machine_layout[mid] = Vector2i(
				int((saved[mid] as Array)[0]), int((saved[mid] as Array)[1]))
			_place_machine(mid)

# Reset all machines to the default row.
func _reset_layout() -> void:
	var cam := GameState.campaign
	if cam == null:
		return
	var chain: Array = BalanceDB.db.lookup.chain_machine_ids(cam.chain_id)
	for i in range(chain.size()):
		var mid: String = chain[i]
		if _machine_nodes.has(mid):
			_machine_layout[mid] = Vector2i(i, 0)
			_place_machine(mid)
	_sync_layout_to_state()

func _sync_layout_to_state() -> void:
	var out: Dictionary = {}
	for mid in _machine_layout.keys():
		var g: Vector2i = _machine_layout[mid]
		out[mid] = [g.x, g.y]
	GameState.machine_layout = out

# Hit test: which machine is under the world point (nearest within threshold)?
func _machine_at(w: Vector2) -> String:
	var best: String = ""
	var best_d: float = TILE_W * 0.5
	for mid in _machine_nodes.keys():
		var c: Vector2 = _iso(_machine_layout[mid].x, _machine_layout[mid].y)
		var d: float = w.distance_to(c)
		if d < best_d:
			best_d = d
			best = mid
	return best

# Is this grid cell free (in bounds and not occupied by another machine)?
func _tile_free(g: Vector2i, ignore_mid: String) -> bool:
	if g.x < 0 or g.x >= GRID_SIZE or g.y < 0 or g.y >= GRID_SIZE:
		return false
	for mid in _machine_layout.keys():
		if mid != ignore_mid and _machine_layout[mid] == g:
			return false
	return true

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
			KEY_R:
				_reset_layout()
			KEY_S:
				SaveSystem.save("slot1", GameState.campaign.sim)
			KEY_L:
				var data: Dictionary = SaveSystem.load("slot1")
				if not data.is_empty():
					GameState.load_game(data)
					_apply_saved_layout()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera.zoom = _camera.zoom * 1.1
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera.zoom = _camera.zoom / 1.1
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			var w: Vector2 = get_local_mouse_position()
			if mb.pressed:
				var hit: String = _machine_at(w)
				if hit != "":
					_drag_machine = hit
				else:
					_panning = true
			else:
				if _drag_machine != "":
					var g: Vector2i = Vector2i(
						int(round(_world_to_grid(w).x)),
						int(round(_world_to_grid(w).y)))
					if _tile_free(g, _drag_machine):
						_machine_layout[_drag_machine] = g
						_place_machine(_drag_machine)
						_sync_layout_to_state()
				_drag_machine = ""
				_panning = false
				_ghost.visible = false
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if _panning:
			_camera.position -= mm.relative / _camera.zoom
		if _drag_machine != "":
			var w: Vector2 = get_local_mouse_position()
			var g: Vector2i = Vector2i(
				int(round(_world_to_grid(w).x)),
				int(round(_world_to_grid(w).y)))
			var ok: bool = _tile_free(g, _drag_machine)
			_ghost.polygon = _tile_polygon(_iso(g.x, g.y))
			_ghost.color = COL_GHOST_OK if ok else COL_GHOST_BAD
			_ghost.visible = true

func _process(_delta: float) -> void:
	var cam := GameState.campaign
	if cam == null:
		return
	# update machine block colors by state
	for mid in _machine_nodes.keys():
		var idx: int = _chain_index(mid)
		if idx >= 0 and idx < cam.sim.line.machines.size():
			var m: MachineState = cam.sim.line.machines[idx]
			var block: Polygon2D = _machine_nodes[mid].block
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

func _chain_index(mid: String) -> int:
	var cam := GameState.campaign
	if cam == null:
		return -1
	var chain: Array = BalanceDB.db.lookup.chain_machine_ids(cam.chain_id)
	return chain.find(mid)

# The machine's stage type (for the procedural visual).
func _machine_stage(mid: String) -> String:
	var md: MachineData = BalanceDB.db.get_machine(mid)
	if md == null:
		return ""
	return md.stage
