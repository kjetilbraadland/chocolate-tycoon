class_name BeltVisual
extends RefCounted
## M6: belt + inserter visuals (Factorio-style). Belts render as thin strips
## between machines, colored by what they carry (raw / semi / finished) and
## showing their fill level; inserters render as small arm polygons at the
## belt-machine junction. Headless-testable (returns polygon data).

# Belt strip colors by kind.
const RAW := Color(0.85, 0.62, 0.35)      # raw material (cocoa / sugar)
const SEMI := Color(0.62, 0.55, 0.72)     # semi-finished (tempered paste)
const FINISHED := Color(0.55, 0.72, 0.55) # finished chocolate
const BELT_BASE := Color(0.34, 0.35, 0.42)  # conveyor (visible on the dark floor)
const ITEM := Color(0.95, 0.85, 0.55)
const INSERTER := Color(0.45, 0.85, 0.95)

# A belt strip between two points, with a fill overlay proportional to
# `fill` (0..1). Returns [base, fill] polygons.
static func belt(a: Vector2, b: Vector2, fill: float) -> Array:
	var out: Array = []
	out.append(_poly(_strip(a, b, 10.0), BELT_BASE))
	if fill > 0.0:
		var f: float = clampf(fill, 0.0, 1.0)
		var fa: Vector2 = a.lerp(b, 1.0 - f)  # fill grows from the source end
		out.append(_poly(_strip(fa, b, 6.0), _kind_color("semi")))
	return out

# An inserter arm at a junction point (a small triangle pointing at the
# machine).
static func inserter(at: Vector2) -> Array:
	var out: Array = []
	out.append(_poly(PackedVector2Array([
		at + Vector2(-8, 0), at + Vector2(8, 0), at + Vector2(0, -14)]), INSERTER))
	return out

# Items on a belt (a few small squares spaced along the strip, count scaled
# by fill).
static func items(a: Vector2, b: Vector2, fill: float) -> Array:
	var out: Array = []
	var n: int = int(clampf(fill, 0.0, 1.0) * 4.0)
	for i in range(n):
		var t: float = 0.2 + 0.6 * (float(i) / maxf(1.0, float(n - 1)))
		var c: Vector2 = a.lerp(b, t)
		out.append(_poly(_square(c, 4.0), ITEM))
	return out

# Belt kind color.
static func kind_color(kind: String) -> Color:
	match kind:
		"raw": return RAW
		"finished": return FINISHED
		_: return SEMI

static func _kind_color(k: String) -> Color:
	return kind_color(k)

static func _poly(p: PackedVector2Array, c: Color) -> Dictionary:
	return { "polygon": p, "color": c }

# A thin strip (rectangle) between two points.
static func _strip(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var dir: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(-dir.y, dir.x) * (w * 0.5)
	return PackedVector2Array([a + n, b + n, b - n, a - n])

static func _square(c: Vector2, s: float) -> PackedVector2Array:
	return PackedVector2Array([
		c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, s), c + Vector2(-s, s)])
