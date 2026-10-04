extends CanvasLayer
## M5: on-screen HUD layer (GDD §14 milestone 5 — UX clarity for bottlenecks
## and quality + campaign pacing). Renders the data layers already built:
##   - Diagnostics.line_report()  -> per-machine status + bottleneck + summary
##   - Diagnostics.quality_summary() -> weakest quality component
##   - PacingReport (via campaign.pacing_report()) -> cash/break-even/neg-days
##   - campaign._quality_components() -> the T/P/C/F/S/W bars
##
## Layout: a top bar (day / cash / debt / speed / running) + a right-side
## collapsible panel (B / Q / P sections). Dark theme to match the isometric
## factory. Fully headless-verifiable: build, update, assert label text.

# Dark theme palette (matches factory_view COL_*).
const BG := Color(0.09, 0.10, 0.13, 0.92)
const PANEL := Color(0.12, 0.14, 0.18, 0.95)
const TEXT := Color(0.92, 0.94, 0.98)
const DIM := Color(0.62, 0.66, 0.72)
const ACCENT := Color(0.45, 0.85, 0.95)
const GOOD := Color(0.45, 0.85, 0.55)
const WARN := Color(0.95, 0.78, 0.40)
const BAD := Color(0.95, 0.45, 0.45)

var _top_bar: Label
var _panel: Panel
var _panel_open: bool = true
var _labels: Dictionary = {}  # key -> Label
var _bars: Dictionary = {}  # quality component key -> ProgressBar

func _ready() -> void:
	layer = 10
	_ensure_built()
	_update()

# Idempotent build (so a headless test can call _update() before _ready fires).
func _ensure_built() -> void:
	if _top_bar == null:
		_build_top_bar()
	if _panel == null:
		_build_panel()

func _build_top_bar() -> void:
	_top_bar = Label.new()
	_top_bar.position = Vector2(16, 8)
	_top_bar.add_theme_font_size_override("font_size", 18)
	_top_bar.add_theme_color_override("font_color", TEXT)
	_top_bar.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_top_bar.add_theme_constant_override("outline_size", 6)
	add_child(_top_bar)

func _build_panel() -> void:
	_panel = Panel.new()
	# right-side panel; width 360, anchored to the right edge
	var vp: Vector2 = Vector2(1280, 720)  # fallback (headless has no viewport)
	var v: Window = get_viewport()
	if v != null:
		vp = v.get_visible_rect().size
	_panel.position = Vector2(vp.x - 376, 64)
	_panel.size = Vector2(360, 560)
	# Panel has no default style; give it a dark background via a StyleBox
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	_build_sections()

func _build_sections() -> void:
	var y: float = 16
	# --- B: Bottleneck section ---
	y = _section_header(y, "BOTTLENECK")
	_labels["b_summary"] = _add_label(y, ACCENT, 14)
	y += 24
	_labels["b_bottleneck"] = _add_label(y, WARN, 13)
	y += 22
	_labels["b_machines"] = _add_label(y, DIM, 12)
	y += 60
	# --- Q: Quality section ---
	y = _section_header(y, "QUALITY")
	_labels["q_summary"] = _add_label(y, ACCENT, 14)
	y += 24
	# quality component bars (T/P/C/F/S/W)
	for k in ["T", "P", "C", "F", "S", "W"]:
		_bars[k] = _add_bar(y, k)
		y += 26
	y += 4
	_labels["q_grade"] = _add_label(y, TEXT, 14)
	y += 30
	# --- P: Pacing section ---
	y = _section_header(y, "PACING")
	_labels["p_summary"] = _add_label(y, ACCENT, 13)
	y += 22
	_labels["p_detail"] = _add_label(y, DIM, 12)

func _section_header(y: float, text: String) -> float:
	var l := Label.new()
	l.position = Vector2(12, y)
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", DIM)
	_panel.add_child(l)
	return y + 26

func _add_label(y: float, color: Color, size: int) -> Label:
	var l := Label.new()
	l.position = Vector2(12, y)
	l.custom_minimum_size = Vector2(336, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_panel.add_child(l)
	return l

func _add_bar(y: float, name: String) -> ProgressBar:
	var l := Label.new()
	l.position = Vector2(12, y)
	l.text = name
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", DIM)
	_panel.add_child(l)
	var bar := ProgressBar.new()
	bar.position = Vector2(40, y)
	bar.size = Vector2(300, 18)
	bar.max_value = 100.0
	bar.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.18, 0.22)
	sb.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", sb)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	_panel.add_child(bar)
	return bar

func _process(_delta: float) -> void:
	_update()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		toggle_panel()

# Recompute all HUD text from the live campaign. Headless-verifiable.
func _update() -> void:
	_ensure_built()
	var cam: Campaign = GameState.campaign
	if cam == null or cam.sim == null:
		return
	var eco: Economy = cam.sim.economy
	# top bar
	_top_bar.text = "Day %d  |  Cash: %.0f  |  Debt: %.0f  |  %dx  |  %s" % [
		cam.sim.day, eco.cash, eco.debt, GameState.speed,
		"RUNNING" if GameState.running else "PAUSED"]
	# B: bottleneck
	var rep: Dictionary = Diagnostics.line_report(cam.sim.line)
	_labels["b_summary"].text = rep.summary
	_labels["b_bottleneck"].text = "Natural bottleneck: %s (%.1f/min)" % [
		rep.bottleneck, rep.bottleneck_rate]
	# per-machine one-liner (id: status)
	var parts: Array = []
	for m in cam.sim.line.machines:
		var st: int = (rep.per_machine as Dictionary)[m.data.machine_id]
		parts.append("%s:%s" % [m.data.machine_id, _status_short(st)])
		_labels["b_machines"].text = "  ".join(parts)
	# Q: quality
	var comps: Dictionary = cam._quality_components()
	_labels["q_summary"].text = Diagnostics.quality_summary(comps)
	for k in _bars.keys():
		var v: float = comps.get(k, 0.0)
		_bars[k].value = clampf(v, 0.0, 100.0)
		# color the fill by value
		var fill: StyleBoxFlat = _bars[k].get_theme_stylebox("fill")
		if v >= 85.0:
			fill.bg_color = GOOD
		elif v >= 65.0:
			fill.bg_color = WARN
		else:
			fill.bg_color = BAD
	var last_grade: String = ""
	if not cam.day_results.is_empty():
		last_grade = (cam.day_results[cam.day_results.size() - 1] as Dictionary).grade
	_labels["q_grade"].text = "Grade: %s   Q: %.1f" % [last_grade, comps.Q]
	# P: pacing
	var pacing: Dictionary = cam.pacing_report()
	_labels["p_summary"].text = pacing.summary
	_labels["p_detail"].text = "min cash %.0f (day %d)  |  break-even day %d  |  %d neg days (run %d)" % [
		pacing.min_cash, pacing.min_cash_day, pacing.break_even_day,
		pacing.neg_profit_days, pacing.max_negative_run]

func _status_short(st: int) -> String:
	match st:
		Diagnostics.Status.BOTTLENECK: return "BN"
		Diagnostics.Status.STARVED: return "ST"
		Diagnostics.Status.BLOCKED: return "BL"
		Diagnostics.Status.BREAKING: return "BD"
		_: return "OK"

# Toggle the panel open/closed (keyboard B in factory_view).
func toggle_panel() -> void:
	_panel_open = not _panel_open
	_panel.visible = _panel_open
