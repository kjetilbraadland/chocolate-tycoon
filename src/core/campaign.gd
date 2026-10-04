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

# production is capped at demand (see start_day)
var day_demand: float = 0.0

# footfall base (ECO_SHOP_FOOTFALL_BASE): scales the demand event multiplier.
# 1.0 on Normal (no-op), <1.0 on Hard tightens demand.
var footfall_base: float = 1.0

# input cost base (ECO_INPUT_COST_MULT): per-difficulty raw material cost scale.
# 1.0 on Normal, >1.0 on Hard raises the per-unit cost floor (P6 lever #1).
var input_cost_base: float = 1.0

# scenario multipliers (from master_simulation_template.csv)
var input_cost_multiplier: float = 1.0
var energy_price_multiplier: float = 1.0
var storage_decay_multiplier: float = 1.0
var breakdown_multiplier: float = 1.0
var footfall_event_multiplier: float = 1.0
var transport_delay_multiplier: float = 1.0

# daily results
var day_results: Array = []

# M2: multi-product support. player_tier gates which recipes can be produced
# (a recipe is unlocked if recipe.unlock_tier <= player_tier). select_product
# switches the active recipe (and re-bounds the production target).
var player_tier: int = 1

func _init(db: BalanceDatabase, d: EconomyData.Difficulty, s: int,
		r_id: String, c_id: String, p_id: String) -> void:
	sim = Simulation.new(db, d, s)
	recipe = db.get_recipe(r_id)
	chain_id = c_id
	rng = sim.rng
	sim.build_line(c_id)
	footfall_base = db.get_economy_value("ECO_SHOP_FOOTFALL_BASE", d)
	input_cost_base = db.get_economy_value("ECO_INPUT_COST_MULT", d)

# M2: is this recipe unlocked at the current player tier?
func is_recipe_unlocked(r_id: String) -> bool:
	var r: RecipeData = sim.balance_db.get_recipe(r_id)
	return r != null and r.unlock_tier <= player_tier

# M2: switch the active product (only if unlocked). Returns true on success.
func select_product(r_id: String) -> bool:
	var r: RecipeData = sim.balance_db.get_recipe(r_id)
	if r == null or r.unlock_tier > player_tier:
		return false
	recipe = r
	daily_production_target = 0.0  # re-auto to the new recipe's demand base
	return true

# M2: list the recipe ids unlocked at the current tier.
func unlocked_recipes() -> Array:
	var out: Array = []
	for rid in sim.balance_db.recipes.keys():
		var rd: RecipeData = sim.balance_db.recipes[rid]
		if rd.unlock_tier <= player_tier:
			out.append(rid)
	return out

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

# Begin a day: reset the line and feed raw material.
# Production is CAPPED AT DEMAND: feed = min(target, demand). We only ever
# make what the shop (at the current price/brand/footfall) will actually buy,
# so there is no excess finished-goods cost. The day's demand is stored for
# the sell step so production and sales use the same figure.
func start_day() -> void:
	var target: float = daily_production_target
	if target <= 0.0:
		target = recipe.shop_demand_base  # auto: produce to expected shop demand
	day_demand = sim.shop.daily_demand(recipe.shop_demand_base, shop_price_index,
		sim.brand_score, sim.category_reputation, footfall_event_multiplier * footfall_base)
	var feed: float = minf(target, day_demand)  # cap production at demand
	sim.line.reset_day()
	sim.line.source_buffer = feed

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

	# 4. SELL — shop channel. Demand was computed in start_day (same inputs),
	# so reuse it: production was capped at this figure, so we sell what we made.
	var sold: float = sim.shop.sell(day_demand, finished)
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

	# 5. FINANCE — per-HOUR costs coupled to ACTUAL runtime (M1 pass 2)
	# opex and wages are per-day rates in the CSV; charge per active hour
	# (run_ticks = minutes actually running). Idle machines cost nothing.
	# Scenario multipliers (energy/input/decay) applied on top.
	var opex: float = 0.0
	var energy: float = 0.0
	var operator_hours: float = 0.0
	for m in sim.line.machines:
		var hours: float = m.run_ticks_today / 60.0
		opex += sim.economy.opex_cost_hours(m.data.opex_per_day, hours)
		energy += sim.economy.energy_cost(m.data.power_kw, hours) * energy_price_multiplier
		operator_hours += hours  # one operator per machine, charged per active hour
	var wage_cost: float = sim.economy.wage_cost_hours(operator_hours, wage_policy)
	var input_cost: float = sim.line.raw_consumed_today * recipe.base_unit_cost * input_cost_multiplier * input_cost_base
	# storage decay (spoilage) on finished goods
	var spoilage: float = sim.economy.spoilage(finished) * storage_decay_multiplier
	var cost: float = wage_cost + opex + energy + input_cost + spoilage
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

# Drive the live per-hour simulation with a master-sheet scenario's per-day
# recipe + multipliers. Returns a rollup Dictionary matching the summary-sheet
# columns (avg profit/fulfillment/Q/penalty, grade mix, neg-profit days).
func run_scenario(rows: Array) -> Dictionary:
	var total_revenue: float = 0.0
	var total_cost: float = 0.0
	var total_penalty: float = 0.0
	var quality_sum: float = 0.0
	var fulfillment_sum: float = 0.0
	var neg_profit_days: int = 0
	var contract_miss_days: int = 0
	var grade_counts := { "A": 0, "B": 0, "C": 0, "D": 0 }
	var n: int = 0

	for row in rows:
		var s: SimScenarioRow = row
		if not s.enabled:
			continue
		# apply this day's recipe + multipliers
		var r: RecipeData = sim.balance_db.get_recipe(s.recipe_id)
		if r != null:
			recipe = r
		shop_price_index = s.shop_price_multiplier
		wage_policy = s.wage_policy_multiplier
		input_cost_multiplier = s.input_cost_multiplier
		energy_price_multiplier = s.energy_price_multiplier
		storage_decay_multiplier = s.storage_decay_multiplier
		footfall_event_multiplier = s.footfall_event_multiplier
		# production target = this day's expected output (what the plan aimed for)
		daily_production_target = s.expected_units_output

		# drive the live per-hour loop
		start_day()
		for t in range(1440):
			tick()
		var res: Dictionary = close_day()
		day_results.append(res)

		total_revenue += res.shop_revenue
		total_cost += res.cost
		quality_sum += res.quality_q
		grade_counts[res.grade] = grade_counts.get(res.grade, 0) + 1
		if res.profit < 0.0:
			neg_profit_days += 1
		# contract: compare produced vs the day's contract target
		if s.contract_target_units > 0.0:
			var fulfill: float = minf(res.units_produced / s.contract_target_units, 1.0) * 100.0
			fulfillment_sum += fulfill
			if fulfill < 99.5:
				contract_miss_days += 1
			# penalty on the missed volume (simplified; full settle is weekly)
			var missed: float = maxf(s.contract_target_units - res.units_produced, 0.0)
			total_penalty += missed * recipe.base_unit_price * s.contract_penalty_rate
		n += 1

	if n == 0:
		return { "days": 0 }
	var nf: float = float(n)
	return {
		"days": n,
		"avg_daily_profit": (total_revenue - total_cost) / nf,
		"avg_daily_revenue": total_revenue / nf,
		"avg_daily_cost": total_cost / nf,
		"avg_contract_fulfillment_pct": fulfillment_sum / nf,
		"avg_penalty_cost": total_penalty / nf,
		"avg_quality_Q": quality_sum / nf,
		"neg_profit_days": neg_profit_days,
		"contract_miss_days": contract_miss_days,
		"grade_A": grade_counts.get("A", 0),
		"grade_B": grade_counts.get("B", 0),
		"grade_C": grade_counts.get("C", 0),
		"grade_D": grade_counts.get("D", 0),
	}

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
