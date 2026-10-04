class_name RnD
extends RefCounted
## M3: R&D lottery (GDD §8.3.1, locked profile). The player invests budget +
## time into a new-recipe project; it resolves probabilistically into one of
## four outcomes. Odds are computed from the locked High-Risk baseline with
## investment + inspector shifts. Breakout Hit chance can ONLY be raised by
## special breakthroughs/events (exposed as a parameter), never raw spending.
##
## Baseline (High Risk): Flop 45 / Niche 30 / Stable 20 / Breakout 5.
## - Each investment level shifts 2% from Flop to Stable (max 5 levels).
## - Each inspector tier shifts 1% from Flop to Niche.
## - Breakout Hit is fixed at 5% (raised only by breakthroughs).

const BASE_FLOP := 45.0
const BASE_NICHE := 30.0
const BASE_STABLE := 20.0
const BASE_BREAKOUT := 5.0
const MAX_INVESTMENT_LEVELS := 5
const INVEST_SHIFT_PCT := 2.0
const INSPECTOR_SHIFT_PCT := 1.0

# Outcome effects (demand / margin multipliers). Breakout uses ECO_RND_BREAKOUT_MULT.
enum Outcome { FLOP, NICHE, STABLE, BREAKOUT }

var rng: RandomNumberGenerator

func _init(r: RandomNumberGenerator = null) -> void:
	rng = r if r != null else RandomNumberGenerator.new()

# Visible odds for the UI (GDD: "R&D lottery with visible odds").
func compute_odds(investment_level: int, inspector_tier: int,
		breakout_bonus_pct: float = 0.0) -> Dictionary:
	var inv: int = clampi(investment_level, 0, MAX_INVESTMENT_LEVELS)
	var flop: float = BASE_FLOP - float(inv) * INVEST_SHIFT_PCT \
		- float(inspector_tier) * INSPECTOR_SHIFT_PCT
	var niche: float = BASE_NICHE + float(inspector_tier) * INSPECTOR_SHIFT_PCT
	var stable: float = BASE_STABLE + float(inv) * INVEST_SHIFT_PCT
	var breakout: float = BASE_BREAKOUT + maxf(breakout_bonus_pct, 0.0)
	return {
		"flop": flop, "niche": niche, "stable": stable, "breakout": breakout,
	}

# Resolve a project. Returns { "outcome": Outcome, "label": String, "odds": Dictionary }.
func resolve(investment_level: int, inspector_tier: int,
		breakout_bonus_pct: float = 0.0) -> Dictionary:
	var odds: Dictionary = compute_odds(investment_level, inspector_tier, breakout_bonus_pct)
	var roll: float = rng.randf() * 100.0
	var acc: float = 0.0
	var outcome: Outcome = Outcome.FLOP
	acc += odds["flop"]
	if roll < acc:
		outcome = Outcome.FLOP
	else:
		acc += odds["niche"]
		if roll < acc:
			outcome = Outcome.NICHE
		else:
			acc += odds["stable"]
			if roll < acc:
				outcome = Outcome.STABLE
			else:
				outcome = Outcome.BREAKOUT
	return { "outcome": outcome, "label": outcome_label(outcome), "odds": odds }

func outcome_label(o: Outcome) -> String:
	match o:
		Outcome.FLOP: return "Flop"
		Outcome.NICHE: return "Niche"
		Outcome.STABLE: return "Stable Seller"
		Outcome.BREAKOUT: return "Breakout Hit"
		_: return "?"
