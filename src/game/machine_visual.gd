class_name MachineVisual
extends RefCounted
## M5: procedural machine visuals (GDD §11 tone — cozy, readable).
## The four candidate repos had no chocolate-factory machine assets, so these
## are self-generated: each machine type gets a distinct isometric-style
## silhouette built from 2D polygons (base block + type-specific details).
## Fully headless-testable (returns polygon data, no rendering required).

# Per-type base tint (cozy palette).
const TYPE_COLORS := {
	"roasting": Color(0.78, 0.52, 0.30),
	"grinding": Color(0.62, 0.60, 0.55),
	"mixing": Color(0.72, 0.55, 0.45),
	"conching": Color(0.55, 0.42, 0.35),
	"tempering": Color(0.55, 0.62, 0.72),
	"molding": Color(0.72, 0.62, 0.40),
	"wrapping": Color(0.62, 0.55, 0.62),
}
const DETAIL := Color(0.92, 0.86, 0.75)
const DARK := Color(0.28, 0.22, 0.18)

# Return an array of { "polygon": PackedVector2Array, "color": Color } for the
# machine at `center` (isometric world coords). The base block is first.
static func build(type: String, center: Vector2) -> Array:
	var out: Array = []
	var base_col: Color = TYPE_COLORS.get(type, Color(0.72, 0.55, 0.35))
	# base block (the existing footprint)
	out.append(_poly(MachineVisual._base_polygon(center), base_col))
	match type:
		"roasting":
			out.append(_poly(_dome(center), DETAIL))
			out.append(_poly(_chimney(center), DARK))
			out.append(_poly(_drum_front(center), Color(0.35, 0.28, 0.22)))
		"grinding":
			out.append(_poly(_hopper(center), DETAIL))
			out.append(_poly(_chute(center), DARK))
		"mixing":
			out.append(_poly(_bowl(center), DETAIL))
			out.append(_poly(_spoon(center), Color(0.85, 0.72, 0.55)))
		"conching":
			out.append(_poly(_tank(center), DETAIL))
			out.append(_poly(_lid(center), DARK))
		"tempering":
			out.append(_poly(_belt(center), DETAIL))
			out.append(_poly(_roller(center), Color(0.40, 0.45, 0.55)))
		"molding":
			out.append(_poly(_press(center), DETAIL))
			out.append(_poly(_plunger(center), DARK))
		"wrapping":
			out.append(_poly(_conveyor(center), DETAIL))
			out.append(_poly(_box(center), Color(0.85, 0.62, 0.45)))
		_:
			out.append(_poly(_generic_detail(center), DETAIL))
	return out

static func _poly(p: PackedVector2Array, c: Color) -> Dictionary:
	return { "polygon": p, "color": c }

# --- base + type-specific silhouettes (isometric, centered on `center`) ---
static func _base_polygon(c: Vector2) -> PackedVector2Array:
	var h: float = 26.0
	return PackedVector2Array([
		c + Vector2(0, -16 - h), c + Vector2(24, -8 - h), c + Vector2(24, -8),
		c + Vector2(0, 0), c + Vector2(-24, -8), c + Vector2(-24, -8 - h)])

static func _dome(c: Vector2) -> PackedVector2Array:
	# half-ellipse on top of the base
	var t: Vector2 = c + Vector2(0, -16 - 26)
	return PackedVector2Array([
		t + Vector2(-18, 0), t + Vector2(-12, -14), t + Vector2(0, -20),
		t + Vector2(12, -14), t + Vector2(18, 0), t + Vector2(0, 6)])

static func _chimney(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(14, -16 - 26 - 18)
	return PackedVector2Array([
		t + Vector2(-3, 0), t + Vector2(3, 0), t + Vector2(3, -14), t + Vector2(-3, -14)])

static func _drum_front(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 13)
	return PackedVector2Array([
		t + Vector2(-10, 0), t + Vector2(10, 0), t + Vector2(10, 10), t + Vector2(-10, 10)])

static func _hopper(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26)
	return PackedVector2Array([
		t + Vector2(-16, 0), t + Vector2(16, 0), t + Vector2(8, -16), t + Vector2(-8, -16)])

static func _chute(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(20, -16 - 10)
	return PackedVector2Array([
		t + Vector2(0, 0), t + Vector2(10, 0), t + Vector2(10, 16), t + Vector2(0, 16)])

static func _bowl(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26)
	return PackedVector2Array([
		t + Vector2(-14, 0), t + Vector2(14, 0), t + Vector2(10, 12),
		t + Vector2(0, 16), t + Vector2(-10, 12)])

static func _spoon(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26 - 6)
	return PackedVector2Array([
		t + Vector2(-2, 0), t + Vector2(2, 0), t + Vector2(2, 20), t + Vector2(-2, 20)])

static func _tank(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26)
	return PackedVector2Array([
		t + Vector2(-16, 0), t + Vector2(16, 0), t + Vector2(16, 16), t + Vector2(-16, 16)])

static func _lid(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26 - 4)
	return PackedVector2Array([
		t + Vector2(-18, 0), t + Vector2(18, 0), t + Vector2(14, -8), t + Vector2(-14, -8)])

static func _belt(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26)
	return PackedVector2Array([
		t + Vector2(-20, 0), t + Vector2(20, 0), t + Vector2(20, 8), t + Vector2(-20, 8)])

static func _roller(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26 - 6)
	return PackedVector2Array([
		t + Vector2(-8, 0), t + Vector2(8, 0), t + Vector2(8, 8), t + Vector2(-8, 8)])

static func _press(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26)
	return PackedVector2Array([
		t + Vector2(-14, 0), t + Vector2(14, 0), t + Vector2(14, 14), t + Vector2(-14, 14)])

static func _plunger(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26 - 10)
	return PackedVector2Array([
		t + Vector2(-6, 0), t + Vector2(6, 0), t + Vector2(6, 16), t + Vector2(-6, 16)])

static func _conveyor(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26)
	return PackedVector2Array([
		t + Vector2(-22, 0), t + Vector2(22, 0), t + Vector2(22, 10), t + Vector2(-22, 10)])

static func _box(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26 - 8)
	return PackedVector2Array([
		t + Vector2(-8, 0), t + Vector2(8, 0), t + Vector2(8, 10), t + Vector2(-8, 10)])

static func _generic_detail(c: Vector2) -> PackedVector2Array:
	var t: Vector2 = c + Vector2(0, -16 - 26)
	return PackedVector2Array([
		t + Vector2(-12, 0), t + Vector2(12, 0), t + Vector2(12, 12), t + Vector2(-12, 12)])

# --- M5 polish: shading, shadow, glow and steam helpers ---

# Three isometric face tints for a base block: top (light), left (mid), right (dark).
static func face_shades(base: Color) -> Dictionary:
	return {
		"top": base.lightened(0.22),
		"left": base,
		"right": base.darkened(0.30),
	}

# Soft drop shadow: flat diamond under the machine (slightly smaller than a tile).
static func shadow(c: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(0, -13), c + Vector2(26, 0), c + Vector2(0, 13), c + Vector2(-26, 0)])

# Warm glow ring (same footprint as the shadow; alpha is animated in the view).
static func glow(c: Vector2) -> PackedVector2Array:
	return shadow(c)

# Where steam particles emit for a machine type (world offset from tile center).
static func steam_origin(type: String, c: Vector2) -> Vector2:
	match type:
		"roasting":
			return c + Vector2(14, -74)  # top of the chimney
		"conching":
			return c + Vector2(0, -54)  # top of the tank lid
		_:
			return c + Vector2(0, -60)
