class_name QualityScorer
extends RefCounted
## Locked quality model (GDD §8.2.1). Pure function — no scene-tree dependency.
## Q = 0.30T + 0.20P + 0.15C + 0.15F + 0.10S + 0.10W, components in 0..100.

const W_TASTE := 0.30
const W_PROCESS := 0.20
const W_CONSISTENCY := 0.15
const W_FRESHNESS := 0.15
const W_SANITATION := 0.10
const W_WAGE := 0.10

# Grade bands (GDD §8.2.1)
const GRADE_A_MIN := 85.0
const GRADE_B_MIN := 70.0
const GRADE_C_MIN := 55.0

func clamp01(v: float) -> float:
	return clampf(v, 0.0, 100.0)

func score(t: float, p: float, c: float, f: float, s: float, w: float) -> float:
	return W_TASTE * clamp01(t) + W_PROCESS * clamp01(p) + W_CONSISTENCY * clamp01(c) \
		+ W_FRESHNESS * clamp01(f) + W_SANITATION * clamp01(s) + W_WAGE * clamp01(w)

func grade_for(q: float) -> String:
	if q >= GRADE_A_MIN:
		return "A"
	elif q >= GRADE_B_MIN:
		return "B"
	elif q >= GRADE_C_MIN:
		return "C"
	return "D"

# Grade as an ordinal for comparisons (A > B > C > D).
func grade_rank(g: String) -> int:
	match g:
		"A": return 4
		"B": return 3
		"C": return 2
		_: return 1

# Does grade g meet minimum grade min_g?
func meets_min_grade(g: String, min_g: String) -> bool:
	return grade_rank(g) >= grade_rank(min_g)
