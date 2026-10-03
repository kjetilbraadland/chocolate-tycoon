class_name Campaign
extends RefCounted
## M1 playable loop: buy ingredients -> produce (production line) -> quality
## scoring -> sell (shop + contract) -> finance (wages/energy/opex/interest)
## -> bankruptcy check. Wraps Simulation + the core systems into a complete
## daily loop that runs headless at any speed.
##
## Production throughput here is a campaign-level simplification (batch attempts
## x per-day yield); the full per-machine buffer/bottleneck model is M2.

var sim: Simulation
var recipe: RecipeData
var chain_id: String = ""
var rng: RandomNumberGenerator

# player controls
var wage_policy: float = 1.0
var shop_price_index: float = 1.0
var daily_production_target: float = 0.0  # units to attempt per day (0 = auto: shop demand base)

# daily results
var day_results: Array = []

func _init(db: BalanceDatabase, d: EconomyData.Difficulty, s: int,
		r_id: String, c_id: String, p_id: String) -> void:
	sim = Simulation.new(db, d, s)
	recipe = db.get_recipe(r_id)
	chain_id = c_id
	rng = sim.rng
	sim.build_line(c_id)

# Run a full campaign of `days` days (headless). Returns a summary Dictionary.
func run(days: int, contract_pack_id: String = "") -> Dictionary:
	var contract: Dictionary = sim.balance_db.get_contract_pack(contract_pack_id)
	var contract_target: float = contract.get("target_units", 0.0)
	var contract_min_grade: String = contract.get("min_grade", "B")
	var contract_penalty_rate: float = contract.get("penalty_rate", 0.18)
	sim.contracts.set_penalty_rate(contract_penalty_rate)

	var weekly_units: float = 0.0
	for i in range(days):
		start_day()
		for t in range(1440):
			tick()
		var r: Dictionary = close_day()
		day_results.append(r)
		weekly_units += r.units_produced
		if (i + 1) % 7 == 0:
			_settle_week(weekly_units, contract, contract_target, contract_min_grade)
			weekly_units = 0.0

	var total_revenue: float = 0.0
	var total_cost: float = 0.0
	var bankrupt_day: int = -1
	for r in day_results:
		var rd: Dictionary = r
		total_revenue += rd.get("shop_revenue", 0.0)
		total_cost += rd.get("cost", 0.0)
		if rd.get("bankrupt", false) and bankrupt_day < 0:
			bankrupt_day = rd.get("day", 0)
	return {
		"days": days,
		"start_cash": sim.balance_db.get_economy_value("ECO_START_CASH", sim.diff),
		"final_cash": sim.economy.cash,
		"final_debt": sim.economy.debt,
		"total_revenue": total_revenue,
		"total_cost": total_cost,
		"total_profit": total_revenue - total_cost,
		"total_units_produced": sim.total_units_produced,
		"is_bankrupt": sim.economy.is_bankrupt,
		"bankrupt_day": bankrupt_day,
	}

# Begin a day: reset the line and feed raw material (bounded by the target).
func start_day() -> void:
	var target: float = daily_production_target
	if target <= 0.0:
		target = recipe.shop_demand_base  # auto: produce to expected shop demand
	sim.line.reset_day()
	sim.line.source_buffer = target

# Advance one in-game minute (1 tick). Drives the real machine loop.
func tick() -> void:
	sim.line.tick(true)

# Close the day: quality -> sell -> finance -> bankruptcy. Returns the day result.
func close_day() -> Dictionary:
	var finished: float = sim.line.machines[-1].units_produced_today \
		if sim.line.machines.size() > 0 else 0.0
	sim.total_units_produced += finished

	# 3. QUALITY scoring (locked formula, from real line state)
	var q: float = _compute_quality()
	var grade: String = sim.scorer.grade_for(q)

	# 4. SELL — shop channel
	var demand: float = sim.shop.daily_demand(recipe.shop_demand_base, shop_price_index,
		sim.brand_score, sim.category_reputation, 1.0)
	var sold: float = sim.shop.sell(demand, finished)
	var unit_price: float = recipe.base_unit_price * shop_price_index
	var shop_revenue: float = sold * unit_price

	# brand / category rep drift by grade
	var brand_delta: float = 0.0
	var rep_delta: float = 0.0
	match grade:
		"A":
			brand_delta = 0.02
			rep_delta = 0.02
		"B":
			brand_delta = 0.005
			rep_delta = 0.005
		"C":
			brand_delta = -0.01
			rep_delta = -0.005
		_:
			brand_delta = -0.02
			rep_delta = -0.01
	sim.brand_score = clampf(sim.brand_score + brand_delta, 0.0, 1.0)
	sim.category_reputation = clampf(sim.category_reputation + rep_delta, 0.0, 1.0)

	# 5. FINANCE — costs coupled to ACTUAL runtime
	var opex: float = 0.0
	var energy: float = 0.0
	for m in sim.line.machines:
		opex += m.data.opex_per_day
		energy += sim.economy.energy_cost(m.data.power_kw, m.run_ticks_today / 60.0)
	var staff: int = sim.line.machines.size()
	var wage_cost: float = sim.economy.wage_cost(staff, wage_policy)
	var input_cost: float = sim.line.raw_consumed_today * recipe.base_unit_cost
	var cost: float = wage_cost + opex + energy + input_cost
	var revenue: float = shop_revenue
	sim.economy.record_day(revenue, cost)
	sim.economy.accrue_interest()
	sim.total_revenue += revenue
	sim.total_cost += cost

	# 6. BANKRUPTCY check
	var missed: int = 0
	if sim.economy.cash < 0.0:
		missed += 1
	sim.economy.check_bankruptcy(missed)

	var result := {
		"day": sim.day,
		"units_produced": finished,
		"quality_q": q,
		"grade": grade,
		"sold": sold,
		"shop_revenue": shop_revenue,
		"cost": cost,
		"profit": sim.economy.last_profit,
		"cash": sim.economy.cash,
		"debt": sim.economy.debt,
		"bankrupt": sim.economy.is_bankrupt,
	}
	sim.day += 1
	sim.day_completed.emit(sim.day - 1, result)
	if sim.economy.is_bankrupt:
		sim.bankrupt.emit(sim.day - 1)
	return result

func _settle_week(weekly_units: float, contract: Dictionary,
		target: float, min_grade: String) -> void:
	if target <= 0.0:
		return
	# use the most recent day's grade as the delivered grade
	var last_grade: String = "B"
	if not day_results.is_empty():
		last_grade = (day_results[day_results.size() - 1] as Dictionary).grade
	var unit_price: float = recipe.base_unit_price
	var res: Dictionary = sim.contracts.settle(target, min_grade, unit_price,
		weekly_units, last_grade, true)
	# penalty is a cost; reputation hit reduces category rep
	var penalty: float = res.penalty_cost
	sim.economy.cash -= penalty
	sim.total_cost += penalty
	sim.category_reputation = clampf(
		sim.category_reputation - res.reputation_loss / 1000.0, 0.0, 1.0)

# Compute the locked quality score from this day's production state.
func _compute_quality() -> float:
	var stoppage_ratio: float = 0.0
	var max_stop: float = 1440.0
	var total_stop: float = sim.line.total_stoppages_today()
	stoppage_ratio = clampf(total_stop / max_stop, 0.0, 1.0)
	var breakdowns: int = 0
	for m in sim.line.machines:
		breakdowns += m.breakdowns_today

	# T: taste (recipe base, 0..100)
	var t: float = recipe.base_taste_score
	# P: process accuracy (assume in-window temp for campaign; decay w/ stoppages)
	var p: float = 100.0 - stoppage_ratio * 30.0
	# C: consistency (decay with stoppages + breakdowns)
	var c: float = 100.0 - stoppage_ratio * 40.0 - float(breakdowns) * 5.0
	# F: freshness (fresh, no storage age in M1)
	var f: float = 95.0
	# S: sanitation (decay with breakdowns)
	var s: float = 100.0 - float(breakdowns) * 8.0
	# W: wage quality bonus
	var w: float = sim.economy.wage_base * wage_policy * \
		sim.balance_db.get_economy_value("ECO_WAGE_QUALITY_MULT", sim.diff) * 2.0
	w = clampf(w, 0.0, 100.0)
	return sim.scorer.score(t, p, c, f, s, w)
