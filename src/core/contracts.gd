class_name Contracts
extends RefCounted
## Recurring long-term contract system (locked model, GDD §9.3).
## Weekly settlement: missed volume / late shipment / quality shortfall -> penalty
## at contract_penalty_rate * value; reputation hit per failed obligation.

var balance_db: BalanceDatabase
var diff: EconomyData.Difficulty
var penalty_rate: float = 0.18
var reputation_hit: float = 6.0

func _init(db: BalanceDatabase, d: EconomyData.Difficulty = EconomyData.Difficulty.NORMAL) -> void:
	balance_db = db
	diff = d
	penalty_rate = balance_db.get_economy_value("ECO_CONTRACT_PENALTY_RATE", diff)
	reputation_hit = balance_db.get_economy_value("ECO_CONTRACT_REPUTATION_HIT", diff)

func set_penalty_rate(r: float) -> void:
	penalty_rate = r

# Weekly settlement. Returns a Dictionary of results.
# target_units, min_grade, unit_price, delivered_units, delivered_grade, on_time.
func settle(target_units: float, min_grade: String, unit_price: float,
		delivered_units: float, delivered_grade: String, on_time: bool) -> Dictionary:
	var scorer := QualityScorer.new()
	var volume_miss: float = maxf(target_units - delivered_units, 0.0)
	var grade_ok: bool = scorer.meets_min_grade(delivered_grade, min_grade)
	var quality_shortfall: bool = not grade_ok
	var late: bool = not on_time

	var missed_volume_penalty: float = volume_miss * unit_price * penalty_rate
	var quality_penalty: float = 0.0
	if quality_shortfall:
		# penalty on the delivered value that failed grade
		quality_penalty = delivered_units * unit_price * penalty_rate
	var late_penalty: float = 0.0
	if late and delivered_units > 0.0:
		late_penalty = delivered_units * unit_price * penalty_rate * 0.5

	var total_penalty: float = missed_volume_penalty + quality_penalty + late_penalty
	var failed_obligations: int = 0
	if volume_miss > 0.0:
		failed_obligations += 1
	if quality_shortfall:
		failed_obligations += 1
	if late and delivered_units > 0.0:
		failed_obligations += 1

	return {
		"fulfillment_pct": (delivered_units / target_units * 100.0) if target_units > 0.0 else 0.0,
		"missed_volume": volume_miss,
		"grade_ok": grade_ok,
		"late": late,
		"penalty_cost": total_penalty,
		"failed_obligations": failed_obligations,
		"reputation_loss": reputation_hit * failed_obligations,
	}
