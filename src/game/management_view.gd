extends CanvasLayer
## M5: management HUD layer (GDD §14 milestone 5). Left-side panel showing the
## three management systems and driving their real APIs:
##   - Unlock tree (M4 Progression): supply stages 1..5 + tech branches, with
##     unlock buttons (call campaign.unlock_supply_stage / unlock_tech_branch)
##   - Farming (M4 FarmingSystem): plot counts, place-plot buttons, the
##     input-cost multiplier + quality bonus
##   - R&D (M3 RnD): live odds (flop/niche/stable/breakout), investment level,
##     inspector tier, start-project button, last outcome
##
## Dark theme, left side (the bottleneck/quality/pacing HUD is on the right).
## Headless-verifiable: build, update, assert rendered text + call the action
## methods directly (buttons can't be clicked headlessly).

const BG := Color(0.09, 0.10, 0.13, 0.92)
const PANEL := Color(0.12, 0.14, 0.18, 0.95)
const TEXT := Color(0.92, 0.94, 0.98)
const DIM := Color(0.62, 0.66, 0.72)
const ACCENT := Color(0.45, 0.85, 0.95)
const GOOD := Color(0.45, 0.85, 0.55)
const WARN := Color(0.95, 0.78, 0.40)
const BAD := Color(0.95, 0.45, 0.45)

# Supply-stage display names (GDD §6.1).
const STAGE_NAMES := ["", "Raw purchase", "In-house sugar", "In-house cocoa",
	"Specialty inputs", "Farming modules"]
# Tech-branch display names (GDD §6.2).
const BRANCH_NAMES := ["Machinery", "Recipes", "Farming", "Logistics", "Branding"]

var _panel: Panel
var _panel_open: bool = true
var _labels: Dictionary = {}
var _buttons: Dictionary = {}

func _ready() -> void:
	layer = 10
	_ensure_built()
	_update()

func _ensure_built() -> void:
	if _panel == null:
		_build_panel()

func _build_panel() -> void:
	_panel = Panel.new()
	var vp: Vector2 = Vector2(1280, 720)
	var v: Window = get_viewport()
	if v != null:
		vp = v.get_visible_rect().size
	_panel.position = Vector2(8, 64)
	_panel.size = Vector2(360, 560)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_build_sections()

func _build_sections() -> void:
	var y: float = 16
	# --- Unlock tree ---
	y = _header(y, "UNLOCK TREE")
	_labels["stages"] = _label(y, DIM, 12); y += 20
	_labels["branches"] = _label(y, DIM, 12); y += 56
	# --- Farming ---
	y = _header(y, "FARMING")
	_labels["farm_plots"] = _label(y, DIM, 12); y += 20
	_labels["farm_effects"] = _label(y, ACCENT, 12); y += 20
	_buttons["farm_sugar"] = _button(y, "Place sugar plot"); _buttons["farm_sugar"].pressed.connect(_on_farm_sugar); y += 30
	_buttons["farm_cocoa"] = _button(y, "Place cocoa plot"); _buttons["farm_cocoa"].pressed.connect(_on_farm_cocoa); y += 36
	# --- R&D ---
	y = _header(y, "R&D")
	_labels["rnd_state"] = _label(y, DIM, 12); y += 20
	_labels["rnd_odds"] = _label(y, ACCENT, 12); y += 20
	_labels["rnd_last"] = _label(y, WARN, 12); y += 30
	_buttons["rnd_start"] = _button(y, "Start R&D project"); _buttons["rnd_start"].pressed.connect(action_start_rnd)

func _header(y: float, text: String) -> float:
	var l := Label.new()
	l.position = Vector2(12, y)
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", DIM)
	_panel.add_child(l)
	return y + 26

func _label(y: float, color: Color, size: int) -> Label:
	var l := Label.new()
	l.position = Vector2(12, y)
	l.custom_minimum_size = Vector2(336, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_panel.add_child(l)
	return l

func _button(y: float, text: String) -> Button:
	var b := Button.new()
	b.position = Vector2(12, y)
	b.size = Vector2(336, 26)
	b.text = text
	b.add_theme_font_size_override("font_size", 12)
	_panel.add_child(b)
	return b

func _process(_delta: float) -> void:
	_update()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_M:
		toggle_panel()

# Recompute all management-panel text from the live campaign.
func _update() -> void:
	_ensure_built()
	var cam: Campaign = GameState.campaign
	if cam == null or cam.sim == null:
		return
	var prog: Progression = cam.progression
	# --- Unlock tree ---
	var stage_lines: Array = []
	for s in range(1, 5):
		var unlocked: bool = prog.current_stage >= s
		var next: bool = prog.current_stage == s - 1
		var marker: String = "OK" if unlocked else ("->" if next else "  ")
		stage_lines.append("%s %s (day %d+)" % [marker, STAGE_NAMES[s], Progression.STAGE_MIN_DAY[s - 1]])
	_labels["stages"].text = "  ".join(stage_lines)
	var branch_lines: Array = []
	for b in range(5):
		branch_lines.append("%s%s" % ["[x] " if prog.unlocked_branches[b] else "[ ] ", BRANCH_NAMES[b]])
	_labels["branches"].text = "  ".join(branch_lines)
	# --- Farming ---
	var farm: FarmingSystem = cam.farming
	_labels["farm_plots"].text = "sugar: %d   cocoa: %d" % [
		farm.plot_count(FarmingSystem.Crop.SUGAR), farm.plot_count(FarmingSystem.Crop.COCOA)]
	_labels["farm_effects"].text = "input cost x%.2f   quality bonus +%.1f" % [
		farm.input_cost_multiplier(), farm.quality_bonus()]
	# --- R&D ---
	var active: String = "ACTIVE" if cam.rnd_active else "idle"
	_labels["rnd_state"].text = "investment L%d   inspector T%d   %s" % [
		cam.rnd_investment_level, cam.rnd_inspector_tier, active]
	var odds: Dictionary = cam.rnd_odds()
	_labels["rnd_odds"].text = "flop %.0f  niche %.0f  stable %.0f  breakout %.0f" % [
		odds.get("flop", 0.0), odds.get("niche", 0.0), odds.get("stable", 0.0), odds.get("breakout", 0.0)]
	_labels["rnd_last"].text = _rnd_last_text(cam)

func _rnd_last_text(cam: Campaign) -> String:
	if cam.rnd_last_outcome < 0:
		return "no project resolved yet"
	var o: int = cam.rnd_last_outcome
	match o:
		RnD.Outcome.FLOP: return "last: FLOP"
		RnD.Outcome.NICHE: return "last: NICHE"
		RnD.Outcome.STABLE: return "last: STABLE"
		RnD.Outcome.BREAKOUT: return "last: BREAKOUT"
		_: return "last: ?"

# --- Action methods (driven by the buttons; also called directly in tests) ---
func action_unlock_stage(stage: int) -> bool:
	var cam: Campaign = GameState.campaign
	if cam == null:
		return false
	return cam.unlock_supply_stage(stage)

func action_unlock_branch(branch: int) -> bool:
	var cam: Campaign = GameState.campaign
	if cam == null:
		return false
	return cam.unlock_tech_branch(branch)

func action_place_farm(crop: FarmingSystem.Crop) -> int:
	var cam: Campaign = GameState.campaign
	if cam == null:
		return -1
	return cam.place_farm_plot(crop)

# Button handlers (the `pressed` signal carries no args, so wrap the crop).
func _on_farm_sugar() -> void:
	action_place_farm(FarmingSystem.Crop.SUGAR)

func _on_farm_cocoa() -> void:
	action_place_farm(FarmingSystem.Crop.COCOA)

func action_start_rnd() -> bool:
	var cam: Campaign = GameState.campaign
	if cam == null:
		return false
	return cam.start_rnd()

func toggle_panel() -> void:
	_panel_open = not _panel_open
	_panel.visible = _panel_open
