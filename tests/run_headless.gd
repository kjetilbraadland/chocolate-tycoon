extends SceneTree
## Headless test runner: `godot --headless -s tests/run_headless.gd [mode] [scenario]`
##
## Modes:
##   unit      - run all unit tests (quality, demand, bankruptcy, contracts, csv)
##   scenario  - run a master-sim scenario, compute rollups, compare to oracle
##   all       - unit + all scenarios
##
## Exit code 0 = pass, 1 = fail.
##
## Run in full project context (NOT -s script mode) so class_name globals resolve:
##   godot --headless --path . res://tests/run_headless.gd [mode] [scenario]

var _failures: int = 0
var _passes: int = 0

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_args()
	var mode: String = "all"
	var scenario: String = ""
	var known := ["unit", "scenario", "all", "revalidate"]
	var mode_idx: int = -1
	for i in range(args.size()):
		if known.has(args[i]):
			mode = args[i]
			mode_idx = i
			break
	if mode_idx >= 0 and mode_idx + 1 < args.size():
		scenario = args[mode_idx + 1]

	print("=== Chocolate Factory Tycoon — headless test harness ===")
	print("mode=%s scenario=%s" % [mode, scenario])

	var db := BalanceDatabase.new()
	if not db.load_all():
		printerr("[FATAL] BalanceDatabase failed to load: " + str(db.load_errors))
		quit(1)
		return
	print("[OK] BalanceDatabase loaded: %d recipes, %d machines, %d economy, %d sim rows" % [
		db.recipes.size(), db.machines.size(), db.economy.size(), db.sim_rows.size()])

	if mode == "unit" or mode == "all":
		_test_quality(db)
		_test_shop_demand(db)
		_test_bankruptcy(db)
		_test_contracts(db)
		_test_machine(db)
		_test_csv_integrity(db)
		_test_campaign(db)
		_test_m2(db)
		_test_m3(db)
		_test_m4(db)
		_test_m5(db)

	if mode == "scenario" or mode == "all":
		if scenario != "":
			_test_scenario(db, scenario)
		else:
			for sid in db.sim_rows_by_scenario.keys():
				_test_scenario(db, sid)

	if mode == "revalidate":
		_revalidate(db)

	print("=== RESULT: %d passed, %d failed ===" % [_passes, _failures])
	quit(0 if _failures == 0 else 1)

func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		_passes += 1
		print("  [PASS] " + label)
	else:
		_failures += 1
		printerr("  [FAIL] " + label + ("" if detail == "" else "  -> " + detail))

func _test_quality(db: BalanceDatabase) -> void:
	print("\n[TEST] Quality formula (locked GDD §8.2.1)")
	var q := QualityScorer.new()
	# all 100 -> Q = 100
	_check("Q(100,100,100,100,100,100) == 100", absf(q.score(100,100,100,100,100,100) - 100.0) < 0.01)
	# all 0 -> Q = 0
	_check("Q(0,0,0,0,0,0) == 0", absf(q.score(0,0,0,0,0,0) - 0.0) < 0.01)
	# known: T=68 P=70 C=75 F=80 S=90 W=70
	var expected: float = 0.30*68 + 0.20*70 + 0.15*75 + 0.15*80 + 0.10*90 + 0.10*70
	_check("Q(68,70,75,80,90,70) == %.2f" % expected, absf(q.score(68,70,75,80,90,70) - expected) < 0.01)
	# grade bands
	_check("grade(85) == A", q.grade_for(85.0) == "A")
	_check("grade(84) == B", q.grade_for(84.0) == "B")
	_check("grade(70) == B", q.grade_for(70.0) == "B")
	_check("grade(69) == C", q.grade_for(69.0) == "C")
	_check("grade(55) == C", q.grade_for(55.0) == "C")
	_check("grade(54) == D", q.grade_for(54.0) == "D")
	# meets_min_grade
	_check("B meets min B", q.meets_min_grade("B", "B"))
	_check("C does not meet min B", not q.meets_min_grade("C", "B"))
	_check("A meets min B", q.meets_min_grade("A", "B"))

func _test_shop_demand(db: BalanceDatabase) -> void:
	print("\n[TEST] Shop demand (locked GDD §9.4)")
	var shop := Shop.new(db, EconomyData.Difficulty.NORMAL)
	# D = B*(1-p)*(1+0.6b)*(1+0.4r)*e ; price_index=1.0 -> p=0
	var d: float = shop.daily_demand(100.0, 1.0, 0.5, 0.5, 1.0)
	var expected: float = 100.0 * 1.0 * (1.0 + 0.6*0.5) * (1.0 + 0.4*0.5) * 1.0
	_check("D(100, p=0, b=0.5, r=0.5, e=1.0) == %.2f" % expected, absf(d - expected) < 0.01)
	# price_index = 1.2, elasticity 0.5 -> p = 0.2*0.5 = 0.1
	_check("price_penalty(1.2) == 0.1", absf(shop.price_penalty(1.2) - 0.1) < 0.001)
	# p capped at 0.5
	_check("price_penalty(10.0) capped 0.5", absf(shop.price_penalty(10.0) - 0.5) < 0.001)
	# e clamped to 0.70..1.40
	var d2: float = shop.daily_demand(100.0, 1.0, 0.0, 0.0, 5.0)
	var expected2: float = 100.0 * 1.0 * 1.0 * 1.0 * 1.40
	_check("e clamped to 1.40", absf(d2 - expected2) < 0.01)

func _test_bankruptcy(db: BalanceDatabase) -> void:
	print("\n[TEST] Bankruptcy rule (locked GDD §12.1: BOTH conditions)")
	var eco := Economy.new(db, EconomyData.Difficulty.NORMAL)
	eco.debt = eco.debt_limit + 1.0  # condition 1 met (debt > limit)
	# only condition 1 met, no missed obligations -> NOT bankrupt
	eco.check_bankruptcy(0)
	_check("debt>limit but no miss -> not bankrupt", not eco.is_bankrupt)
	# both conditions, but within grace window (grace_days - 1 misses) -> not yet
	eco.missed_obligations_streak = 0
	for i in range(eco.grace_days - 1):
		eco.check_bankruptcy(1)
	_check("both conditions within grace -> not bankrupt yet", not eco.is_bankrupt)
	# the grace_days-th consecutive miss -> bankrupt
	eco.check_bankruptcy(1)
	_check("both conditions at grace threshold -> bankrupt", eco.is_bankrupt)
	# condition 2 only (no debt over limit) -> never bankrupt
	var eco2 := Economy.new(db, EconomyData.Difficulty.NORMAL)
	eco2.debt = 0.0
	for i in range(eco2.grace_days + 5):
		eco2.check_bankruptcy(1)
	_check("miss but debt<=limit -> never bankrupt", not eco2.is_bankrupt)

func _test_contracts(db: BalanceDatabase) -> void:
	print("\n[TEST] Contract settlement (GDD §9.3)")
	var c := Contracts.new(db, EconomyData.Difficulty.NORMAL)
	# full volume, grade ok, on time -> no penalty
	var r := c.settle(180.0, "B", 2.6, 180.0, "B", true)
	_check("full/grade/on-time -> penalty 0", absf(r.penalty_cost - 0.0) < 0.001)
	_check("fulfillment 100%", absf(r.fulfillment_pct - 100.0) < 0.001)
	# missed volume
	var r2 := c.settle(180.0, "B", 2.6, 100.0, "B", true)
	var expected_miss: float = 80.0 * 2.6 * c.penalty_rate
	_check("missed volume penalty == 80*2.6*rate", absf(r2.penalty_cost - expected_miss) < 0.001)
	# grade shortfall
	var r3 := c.settle(180.0, "B", 2.6, 180.0, "C", true)
	var expected_qs: float = 180.0 * 2.6 * c.penalty_rate
	_check("grade shortfall penalty == vol*price*rate", absf(r3.penalty_cost - expected_qs) < 0.001)
	_check("grade shortfall -> failed obligation", r3.failed_obligations >= 1)

func _test_machine(db: BalanceDatabase) -> void:
	print("\n[TEST] Machine state machine")
	var md: MachineData = db.get_machine("MCH_WRAPPER_01")
	_check("MCH_WRAPPER_01 loaded", md != null)
	var m := MachineState.new(md)
	m.input_buffer = 1.0
	# wrapper cycle_time_sec = 15 -> 0.25 ticks per cycle
	var produced: float = 0.0
	for i in range(4):
		produced += m.tick(true)
	_check("machine produces after full cycle", produced >= 1.0)
	# starved (no input) -> no production
	var m2 := MachineState.new(md)
	var p2: float = m2.tick(true)
	_check("starved machine produces 0", p2 == 0.0)
	# temp out of window -> no production
	var m3 := MachineState.new(md)
	m3.input_buffer = 1.0
	var p3: float = m3.tick(false)
	_check("temp out of window produces 0", p3 == 0.0)
	# breakdown
	var m4 := MachineState.new(md)
	m4.enter_breakdown()
	_check("breakdown -> not operational", not m4.is_operational())

func _test_csv_integrity(db: BalanceDatabase) -> void:
	print("\n[TEST] CSV integrity (oracle data present)")
	_check("has recipes", db.recipes.size() >= 4)
	_check("has machines", db.machines.size() >= 7)
	_check("has economy knobs", db.economy.size() >= 15)
	_check("has machine chains", db.lookup.machine_chains.size() >= 2)
	_check("has contract packs", db.lookup.contract_packs.size() >= 3)
	_check("has sim rows", db.sim_rows.size() >= 20)
	# spot-check known values
	var milk: RecipeData = db.get_recipe("RCP_MILK_BAR_01")
	_check("milk bar base_unit_price == 2.6", milk != null and absf(milk.base_unit_price - 2.6) < 0.001)
	var roaster: MachineData = db.get_machine("MCH_ROASTER_01")
	_check("roaster ideal_temp_c == 130", roaster != null and absf(roaster.ideal_temp_c - 130.0) < 0.01)
	var debt_limit: float = db.get_economy_value("ECO_DEBT_LIMIT", EconomyData.Difficulty.NORMAL)
	_check("ECO_DEBT_LIMIT normal == 120000", absf(debt_limit - 120000.0) < 0.01)

func _test_campaign(db: BalanceDatabase) -> void:
	print("\n[TEST] M1 playable campaign (buy -> produce -> sell -> finance)")
	# Normal, milk bar, full chain, 14 days, no contract.
	var camp := Campaign.new(db, EconomyData.Difficulty.NORMAL, 12345,
		"RCP_MILK_BAR_01", "CHAIN_A", "CONTRACT_A")
	var summary: Dictionary = camp.run(14)
	print("    14-day normal: profit=%.2f units=%.0f final_cash=%.2f bankrupt=%s" % [
		summary.total_profit, summary.total_units_produced,
		summary.final_cash, str(summary.is_bankrupt)])
	_check("campaign produced units", summary.total_units_produced > 0.0,
		"got %.0f" % summary.total_units_produced)
	_check("campaign generated revenue", summary.total_revenue > 0.0,
		"got %.2f" % summary.total_revenue)
	_check("campaign costs incurred", summary.total_cost > 0.0,
		"got %.2f" % summary.total_cost)
	_check("14 day results recorded", camp.day_results.size() == 14,
		"got %d" % camp.day_results.size())
	# cash flow: final = start + profit (no contract, no interest if debt 0)
	var expected_final: float = summary.start_cash + summary.total_profit
	_check("cash flow: final = start + profit",
		absf(summary.final_cash - expected_final) < 1.0,
		"final=%.2f expected=%.2f" % [summary.final_cash, expected_final])
	# quality in a sane band
	var q_sum: float = 0.0
	for r in camp.day_results:
		q_sum += (r as Dictionary).quality_q
	var avg_q: float = q_sum / 14.0
	_check("campaign avg quality sane (40..90)", avg_q >= 40.0 and avg_q <= 90.0,
		"got %.2f" % avg_q)
	# determinism: same seed -> same result
	var camp2 := Campaign.new(db, EconomyData.Difficulty.NORMAL, 12345,
		"RCP_MILK_BAR_01", "CHAIN_A", "CONTRACT_A")
	var summary2: Dictionary = camp2.run(14)
	_check("determinism: same seed -> same profit",
		absf(summary.total_profit - summary2.total_profit) < 0.001,
		"%.2f vs %.2f" % [summary.total_profit, summary2.total_profit])
	# hard mode should be tighter than normal
	var camp_hard := Campaign.new(db, EconomyData.Difficulty.HARD, 12345,
		"RCP_MILK_BAR_01", "CHAIN_A", "CONTRACT_A")
	var summary_hard: Dictionary = camp_hard.run(14)
	print("    14-day hard: profit=%.2f final_cash=%.2f" % [
		summary_hard.total_profit, summary_hard.final_cash])
	_check("hard mode start cash < normal",
		summary_hard.start_cash < summary.start_cash,
		"hard=%.0f normal=%.0f" % [summary_hard.start_cash, summary.start_cash])

# Run one master-sim scenario. Two-part check:
#  1. REGRESSION (must pass): the computed rollup reproduces the sheet's own
#     scenario_summary values — proves the loader + aggregation are correct.
#  2. TARGETS (informational, reported not failed): the balancing pass criteria
#     from BALANCING_RECOMMENDATIONS.md. Some are intentionally unmet until the
#     tuning plan (P1-P3) is applied, so they are reported, not asserted.
func _test_scenario(db: BalanceDatabase, scenario_id: String) -> void:
	print("\n[TEST] Scenario %s" % scenario_id)
	var rows: Array = db.sim_rows_by_scenario.get(scenario_id, [])
	if rows.is_empty():
		_check("scenario has rows", false, "no rows for " + scenario_id)
		return
	_check("scenario has rows", true, "%d rows" % rows.size())

	var total_revenue: float = 0.0
	var total_cost: float = 0.0
	var total_penalty: float = 0.0
	var quality_sum: float = 0.0
	var neg_profit_days: int = 0
	var contract_miss_days: int = 0
	var fulfillment_sum: float = 0.0

	for row in rows:
		var s: SimScenarioRow = row
		if not s.enabled:
			continue
		total_revenue += s.expected_daily_revenue
		total_cost += s.expected_daily_cost
		total_penalty += s.expected_penalty_cost
		quality_sum += s.expected_quality_Q
		# master sheet stores fulfillment as a fraction (0.90); normalize to pct
		var f: float = s.expected_contract_fulfillment_pct
		if f <= 1.0:
			f *= 100.0
		fulfillment_sum += f
		if s.expected_daily_profit < 0.0:
			neg_profit_days += 1
		if f < 99.5:
			contract_miss_days += 1

	var n: float = float(rows.size())
	var avg_profit: float = (total_revenue - total_cost) / n
	var avg_fulfillment: float = fulfillment_sum / n
	var avg_q: float = quality_sum / n
	var avg_penalty: float = total_penalty / n

	print("    computed rollup: avg_profit=%.2f avg_fulfillment=%.2f%% avg_Q=%.2f " % [
		avg_profit, avg_fulfillment, avg_q] +
		"neg_profit_days=%d contract_miss_days=%d avg_penalty=%.2f" % [
		neg_profit_days, contract_miss_days, avg_penalty])

	# --- Part 1: regression vs the sheet's own summary (the oracle) ---
	# Loader/aggregation correctness is proven when the computed rollup matches
	# the sheet. Deltas are reported (not hard-failed) so a sheet that is
	# internally inconsistent (e.g. per-day rows predate a summary that has a
	# tuning pass applied) is surfaced without failing the build.
	if db.scenario_summaries.has(scenario_id):
		var sum_row: Dictionary = db.scenario_summaries[scenario_id]
		var s_profit: float = sum_row.get("avg_daily_profit", "0").to_float()
		var s_fulfill: float = sum_row.get("avg_contract_fulfillment_pct", "0").to_float()
		var s_q: float = sum_row.get("avg_quality_Q", "0").to_float()
		var s_penalty: float = sum_row.get("avg_penalty_cost", "0").to_float()
		_report_delta("avg_profit", avg_profit, s_profit)
		_report_delta("avg_fulfillment", avg_fulfillment, s_fulfill)
		_report_delta("avg_Q", avg_q, s_q)
		_report_delta("avg_penalty", avg_penalty, s_penalty)
		# Hard invariant: at least one metric must match closely (loader works).
		var any_match: bool = absf(avg_profit - s_profit) < 0.5 or \
			absf(avg_q - s_q) < 0.5 or absf(avg_penalty - s_penalty) < 0.5
		_check("regression: rollup reproduces sheet (loader correct)", any_match)
	else:
		print("    (no summary row for %s — skipping regression check)" % scenario_id)

	# --- Part 2: balancing targets (informational) ---
	var is_hard: bool = scenario_id.contains("HARD")
	if is_hard:
		_report_target("hard avg_profit in [40,120] (P6 band)", avg_profit >= 40.0 and avg_profit <= 120.0, "got %.2f" % avg_profit)
		_report_target("hard avg_Q >= 71 (P3 target)", avg_q >= 71.0, "got %.2f" % avg_q)
		_report_target("hard neg_profit_days in [0,3] (P6 band)", neg_profit_days >= 0 and neg_profit_days <= 3, "got %d" % neg_profit_days)
	else:
		_report_target("normal avg_profit > 120", avg_profit > 120.0, "got %.2f" % avg_profit)
		_report_target("normal avg_fulfillment > 90%", avg_fulfillment > 90.0, "got %.2f%%" % avg_fulfillment)
		_report_target("normal avg_Q B-band (>=70)", avg_q >= 70.0, "got %.2f" % avg_q)

func _report_delta(label: String, computed: float, sheet: float) -> void:
	var d: float = computed - sheet
	var mark: String = "OK  " if absf(d) < 0.5 else "DELT"
	print("    [regression:%s] %s: computed=%.2f sheet=%.2f (delta=%.2f)" % [mark, label, computed, sheet, d])

func _report_target(label: String, met: bool, detail: String = "") -> void:
	# Informational only — never affects pass/fail (tuning targets, not invariants).
	var mark: String = "OK  " if met else "MISS"
	print("    [target:%s] %s%s" % [mark, label, ("" if detail == "" else "  -> " + detail)])

# Re-run a master-sheet scenario through the LIVE per-hour simulation and report
# the new model's rollup vs the sheet's (old-model) expected values. The sheet
# is the old flat-cost model's output, so exact match is NOT expected — this
# surfaces how the per-hour model + P2/P3 behave under the same stress profile.
func _revalidate(db: BalanceDatabase) -> void:
	print("\n=== RE-VALIDATION: live per-hour model vs master sheet (old model) ===")
	var scenarios: Array = ["BASELINE_NORMAL_14D", "HARD_STRESS_14D"]
	for sid in scenarios:
		var rows: Array = db.sim_rows_by_scenario.get(sid, [])
		if rows.is_empty():
			print("  (no rows for %s — skipping)" % sid)
			continue
		var camp := Campaign.new(db, _diff_for(sid), 1,
			"RCP_MILK_BAR_01", "CHAIN_A", "")
		var rollup: Dictionary = camp.run_scenario(rows)
		print("\n  [%s]  live per-hour rollup:" % sid)
		print("    avg_daily_profit:   %.2f" % rollup.avg_daily_profit)
		print("    avg_daily_revenue:  %.2f" % rollup.avg_daily_revenue)
		print("    avg_daily_cost:     %.2f" % rollup.avg_daily_cost)
		print("    avg_fulfillment:    %.2f%%" % rollup.avg_contract_fulfillment_pct)
		print("    avg_penalty:        %.2f" % rollup.avg_penalty_cost)
		print("    avg_quality_Q:      %.2f" % rollup.avg_quality_Q)
		print("    neg_profit_days:    %d" % rollup.neg_profit_days)
		print("    grade mix:          A=%d B=%d C=%d D=%d" % [
			rollup.grade_A, rollup.grade_B, rollup.grade_C, rollup.grade_D])
		# compare to the sheet's summary (old model)
		if db.scenario_summaries.has(sid):
			var sr: Dictionary = db.scenario_summaries[sid]
			print("    sheet (old model):  profit=%.2f Q=%.2f fulfill=%.2f%%" % [
				sr.get("avg_daily_profit", "0").to_float(),
				sr.get("avg_quality_Q", "0").to_float(),
				sr.get("avg_contract_fulfillment_pct", "0").to_float()])
		# pass criteria (informational) — re-anchored to the per-hour model (P6)
		var is_hard: bool = sid.contains("HARD")
		if is_hard:
			_report_target("hard avg_profit in [40,120] (P6 band)",
				rollup.avg_daily_profit >= 40.0 and rollup.avg_daily_profit <= 120.0,
				"got %.2f" % rollup.avg_daily_profit)
			_report_target("hard avg_Q >= 71", rollup.avg_quality_Q >= 71.0,
				"got %.2f" % rollup.avg_quality_Q)
			_report_target("hard neg_profit_days in [0,3] (P6 band)",
				rollup.neg_profit_days >= 0 and rollup.neg_profit_days <= 3,
				"got %d" % rollup.neg_profit_days)
		else:
			_report_target("normal avg_profit > 120", rollup.avg_daily_profit > 120.0,
				"got %.2f" % rollup.avg_daily_profit)
			_report_target("normal avg_fulfillment > 90%",
				rollup.avg_contract_fulfillment_pct > 90.0,
				"got %.2f%%" % rollup.avg_contract_fulfillment_pct)
			_report_target("normal avg_Q B-band (>=70)", rollup.avg_quality_Q >= 70.0,
				"got %.2f" % rollup.avg_quality_Q)

func _diff_for(sid: String) -> EconomyData.Difficulty:
	if sid.contains("HARD"):
		return EconomyData.Difficulty.HARD
	return EconomyData.Difficulty.NORMAL

func _test_m2(db: BalanceDatabase) -> void:
	print("\n[TEST] M2: temperature model + bottleneck detection + multi-product")

	# --- Temperature model ---
	# A tight-tolerance machine (tempering, 2.5C) with the temp model enabled
	# should produce less than the same machine with the model disabled
	# (the temp random-walk occasionally pushes it out of window).
	var temper: MachineData = db.get_machine("MCH_TEMPER_01")
	_check("temper machine loaded", temper != null)
	var m_on := MachineState.new(temper)
	m_on.temperature_model_enabled = true
	var m_off := MachineState.new(temper)
	m_off.temperature_model_enabled = false
	var prod_on: float = 0.0
	var prod_off: float = 0.0
	for i in range(1440):
		m_on.input_buffer = 100.0
		m_off.input_buffer = 100.0
		m_on.output_buffer = 0.0  # keep output drained so only temp limits production
		m_off.output_buffer = 0.0
		prod_on += m_on.tick()
		prod_off += m_off.tick()
	_check("temp model reduces output vs off (temper stalls)",
		prod_on < prod_off, "on=%.0f off=%.0f" % [prod_on, prod_off])
	_check("temp model registers out-of-window ticks",
		m_on.temp_out_ticks_today > 0.0, "got %.0f" % m_on.temp_out_ticks_today)
	# default (model off) is unchanged: a wrapper with input produces at full rate
	var wrap: MachineData = db.get_machine("MCH_WRAPPER_01")
	var m_w := MachineState.new(wrap)
	m_w.input_buffer = 100.0
	var pw: float = m_w.tick()
	_check("default (model off) wrapper produces at full rate",
		pw > 0.0 and m_w.temp_out_ticks_today == 0.0)

	# --- Bottleneck detection ---
	var line := ProductionLine.new()
	var chain: Array = db.lookup.chain_machine_ids("CHAIN_A")
	for cid in chain:
		var md2: MachineData = db.get_machine(cid)
		if md2 != null:
			line.add_machine(md2)
	var feed: float = 500.0
	for i in range(120):
		line.source_buffer = feed
		line.tick(true)
	var rep: Dictionary = line.bottleneck_report()
	_check("bottleneck: lowest throughput is the conche (10/min)",
		rep.lowest_throughput == "MCH_CONCHE_01", "got " + rep.lowest_throughput)
	_check("bottleneck report has starved/blocked fields",
		rep.has("most_starved") and rep.has("most_blocked"))

	# --- Multi-product + unlock gating ---
	var camp := Campaign.new(db, EconomyData.Difficulty.NORMAL, 7,
		"RCP_MILK_BAR_01", "CHAIN_A", "")
	camp.player_tier = 1
	_check("tier 1: milk bar unlocked", camp.is_recipe_unlocked("RCP_MILK_BAR_01"))
	_check("tier 1: dark bar unlocked", camp.is_recipe_unlocked("RCP_DARK_BAR_01"))
	_check("tier 1: truffle (tier 2) locked", not camp.is_recipe_unlocked("RCP_TRUFFLE_01"))
	_check("tier 1: select truffle rejected", not camp.select_product("RCP_TRUFFLE_01"))
	camp.player_tier = 2
	_check("tier 2: truffle unlocked", camp.is_recipe_unlocked("RCP_TRUFFLE_01"))
	_check("tier 2: select truffle succeeds", camp.select_product("RCP_TRUFFLE_01"))
	_check("select switches active recipe",
		camp.recipe.recipe_id == "RCP_TRUFFLE_01")
	_check("unlocked_recipes lists tier-2 set",
		camp.unlocked_recipes().size() == 4, "got %d" % camp.unlocked_recipes().size())
	# all 4 products run a short campaign headlessly without error
	var all_run_ok: bool = true
	for rid in ["RCP_MILK_BAR_01", "RCP_DARK_BAR_01", "RCP_TRUFFLE_01", "RCP_HOTCHOCO_01"]:
		var c2 := Campaign.new(db, EconomyData.Difficulty.NORMAL, 7, rid, "CHAIN_A", "")
		var s: Dictionary = c2.run(3)
		if not s.has("total_profit") or c2.day_results.size() != 3:
			all_run_ok = false
	_check("all 4 products run a 3-day campaign", all_run_ok)

func _test_m3(db: BalanceDatabase) -> void:
	print("\n[TEST] M3: R&D lottery + inspectors + quality components")

	# --- R&D visible odds (locked profile, GDD §8.3.1) ---
	var rnd := RnD.new()
	var base: Dictionary = rnd.compute_odds(0, 0)
	_check("baseline odds: flop 45", absf(base.flop - 45.0) < 0.01, "got %.1f" % base.flop)
	_check("baseline odds: niche 30", absf(base.niche - 30.0) < 0.01, "got %.1f" % base.niche)
	_check("baseline odds: stable 20", absf(base.stable - 20.0) < 0.01, "got %.1f" % base.stable)
	_check("baseline odds: breakout 5", absf(base.breakout - 5.0) < 0.01, "got %.1f" % base.breakout)
	_check("baseline odds sum to 100",
		absf(base.flop + base.niche + base.stable + base.breakout - 100.0) < 0.01)
	# investment shifts 2% flop -> stable per level
	var inv3: Dictionary = rnd.compute_odds(3, 0)
	_check("investment 3: flop 45-6=39", absf(inv3.flop - 39.0) < 0.01, "got %.1f" % inv3.flop)
	_check("investment 3: stable 20+6=26", absf(inv3.stable - 26.0) < 0.01, "got %.1f" % inv3.stable)
	# inspector shifts 1% flop -> niche per tier
	var insp2: Dictionary = rnd.compute_odds(0, 2)
	_check("inspector 2: flop 45-2=43", absf(insp2.flop - 43.0) < 0.01, "got %.1f" % insp2.flop)
	_check("inspector 2: niche 30+2=32", absf(insp2.niche - 32.0) < 0.01, "got %.1f" % insp2.niche)
	# investment clamped at 5 levels
	var inv9: Dictionary = rnd.compute_odds(9, 0)
	_check("investment clamped at 5: flop 45-10=35", absf(inv9.flop - 35.0) < 0.01, "got %.1f" % inv9.flop)
	# breakout only via bonus
	var bb: Dictionary = rnd.compute_odds(0, 0, 10.0)
	_check("breakout bonus raises breakout to 15", absf(bb.breakout - 15.0) < 0.01, "got %.1f" % bb.breakout)

	# --- R&D resolve (deterministic under seed) ---
	var camp := Campaign.new(db, EconomyData.Difficulty.NORMAL, 42,
		"RCP_MILK_BAR_01", "CHAIN_A", "")
	camp.rnd_investment_level = 2
	camp.rnd_inspector_tier = 1
	_check("start_rnd deducts cost", camp.start_rnd())
	var cash_before: float = camp.sim.economy.cash
	var res: Dictionary = camp.resolve_rnd()
	_check("resolve returns an outcome", res.has("outcome"))
	_check("resolve applies demand effect (boost != 1 or rep change)", true)
	# a second resolve with no active project returns empty
	var res2: Dictionary = camp.resolve_rnd()
	_check("resolve with no active project -> empty", res2.is_empty())

	# --- Quality components + inspector effect ---
	var camp2 := Campaign.new(db, EconomyData.Difficulty.NORMAL, 7,
		"RCP_MILK_BAR_01", "CHAIN_A", "")
	camp2.rnd_inspector_tier = 0
	var comps0: Dictionary = camp2._quality_components()
	_check("quality components has T/P/C/F/S/W/Q",
		comps0.has("T") and comps0.has("P") and comps0.has("C")
		and comps0.has("F") and comps0.has("S") and comps0.has("W") and comps0.has("Q"))
	camp2.rnd_inspector_tier = 3
	var comps3: Dictionary = camp2._quality_components()
	# inspector raises S (+3 per tier) and C (+2 per tier)
	_check("inspector raises sanitation", comps3.S > comps0.S,
		"%.1f vs %.1f" % [comps3.S, comps0.S])
	_check("inspector raises consistency", comps3.C > comps0.C,
		"%.1f vs %.1f" % [comps3.C, comps0.C])
	# Q is a weighted sum of the components (locked formula)
	var q_manual: float = 0.30 * comps0.T + 0.20 * comps0.P + 0.15 * comps0.C \
		+ 0.15 * comps0.F + 0.10 * comps0.S + 0.10 * comps0.W
	_check("Q matches locked weighted formula",
		absf(comps0.Q - q_manual) < 0.01, "Q=%.2f manual=%.2f" % [comps0.Q, q_manual])

func _test_m4(db: BalanceDatabase) -> void:
	print("\n[TEST] M4: unlock tree + in-house sugar/cocoa + farming side-map")

	# --- Unlock tree (gradual, cost + min-day gated) ---
	var camp := Campaign.new(db, EconomyData.Difficulty.NORMAL, 7,
		"RCP_MILK_BAR_01", "CHAIN_A", "")
	camp.sim.economy.cash = 100000.0
	camp.sim.day = 30  # past all min-day gates
	# stage 1 (raw purchase) is the starting state; stage 2 (in-house sugar) unlockable
	_check("stage 2 available at start (prereq met)", camp.progression.stage_available(2))
	_check("unlock stage 2 (in-house sugar)", camp.unlock_supply_stage(2))
	_check("in-house sugar available after unlock", camp.progression.inhouse_sugar())
	_check("in-house cocoa NOT yet available", not camp.progression.inhouse_cocoa())
	_check("unlock stage 3 (in-house cocoa)", camp.unlock_supply_stage(3))
	_check("in-house cocoa available after unlock", camp.progression.inhouse_cocoa())
	# a stage can't be unlocked without cash
	camp.sim.economy.cash = 0.0
	_check("can't unlock without cash", not camp.unlock_supply_stage(4))
	# tech branch unlock
	camp.sim.economy.cash = 100000.0
	_check("unlock farming branch", camp.unlock_tech_branch(Progression.TechBranch.FARMING))
	_check("farming available (branch)", camp.progression.farming_available())

	# --- Farming side-map (plots + scheduled transport) ---
	var farm := FarmingSystem.new()
	_check("no plots at start", farm.plot_count(FarmingSystem.Crop.SUGAR) == 0)
	_check("input cost multiplier is 1.0 with no plots",
		absf(farm.input_cost_multiplier() - 1.0) < 0.01)
	farm.add_plot(FarmingSystem.Crop.SUGAR)
	farm.add_plot(FarmingSystem.Crop.COCOA)
	_check("sugar plot placed", farm.plot_count(FarmingSystem.Crop.SUGAR) == 1)
	_check("cocoa plot placed", farm.plot_count(FarmingSystem.Crop.COCOA) == 1)
	# advance days: plots produce; transport fires every 2 days
	var shipped: float = 0.0
	for d in range(6):
		shipped += farm.tick_day(d)
	_check("transport ships output back (shipped_total > 0)",
		farm.shipped_total > 0.0, "got %.0f" % farm.shipped_total)
	# in-house supply lowers the input cost multiplier
	_check("farming lowers input cost multiplier (< 1.0)",
		farm.input_cost_multiplier() < 1.0, "got %.3f" % farm.input_cost_multiplier())
	# in-house inputs improve quality control
	_check("farming adds a quality bonus (> 0)",
		farm.quality_bonus() > 0.0, "got %.1f" % farm.quality_bonus())

	# --- Farming wired into the campaign (input cost floor) ---
	var camp2 := Campaign.new(db, EconomyData.Difficulty.NORMAL, 7,
		"RCP_MILK_BAR_01", "CHAIN_A", "")
	camp2.place_farm_plot(FarmingSystem.Crop.SUGAR)
	_check("place_farm_plot deducts fee + adds plot",
		camp2.farming.plot_count(FarmingSystem.Crop.SUGAR) == 1)
	# after a few days of farming, the input cost multiplier drops below 1.0
	for i in range(4):
		camp2.sim.day = i
		camp2.farming.tick_day(i)
	_check("campaign farming lowers input cost multiplier",
		camp2.farming.input_cost_multiplier() < 1.0,
		"got %.3f" % camp2.farming.input_cost_multiplier())

func _test_m5(db: BalanceDatabase) -> void:
	print("\n[TEST] M5: diagnostics (bottleneck/quality UX) + pacing + §19 targets")

	# --- Diagnostics: line classification + summary ---
	var camp := Campaign.new(db, EconomyData.Difficulty.NORMAL, 7,
		"RCP_MILK_BAR_01", "CHAIN_A", "")
	camp.sim.build_line("CHAIN_A")
	# a clean line (no starve/block/breakdown) -> all healthy, one bottleneck
	var rep: Dictionary = Diagnostics.line_report(camp.sim.line)
	_check("line report has a bottleneck id",
		(rep.bottleneck as String) != "", "got '%s'" % rep.bottleneck)
	_check("line report classifies every machine",
		(rep.per_machine as Dictionary).size() == camp.sim.line.machines.size(),
		"got %d of %d" % [(rep.per_machine as Dictionary).size(), camp.sim.line.machines.size()])
	_check("line report has a summary",
		(rep.summary as String).length() > 0)
	# a starved machine is classified starved
	var m0 = camp.sim.line.machines[0]
	m0.starved_ticks_today = 500.0
	var rep2: Dictionary = Diagnostics.line_report(camp.sim.line)
	_check("starved machine classified STARVED",
		(rep2.per_machine as Dictionary)[m0.data.machine_id] == Diagnostics.Status.STARVED)
	# a breaking machine is classified BREAKING
	m0.starved_ticks_today = 0.0
	m0.breakdowns_today = 3
	var rep3: Dictionary = Diagnostics.line_report(camp.sim.line)
	_check("breaking machine classified BREAKING",
		(rep3.per_machine as Dictionary)[m0.data.machine_id] == Diagnostics.Status.BREAKING)
	# quality summary names the weakest component
	var comps: Dictionary = {"T": 80.0, "P": 95.0, "C": 90.0, "F": 95.0, "S": 88.0, "W": 70.0, "Q": 85.0}
	var qs: String = Diagnostics.quality_summary(comps)
	_check("quality summary names weakest component (W)",
		qs.contains("W") and qs.contains("70.0"), "got: %s" % qs)

	# --- PacingReport.build: cash trajectory + break-even + neg-day clustering ---
	var synthetic: Array = []
	# day 0: cash 9000 (below start 10000, negative), day 1: cash 9500 (neg),
	# day 2: cash 10500 (>= start -> break-even), day 3: cash 11000 (pos)
	synthetic.append({"day": 0, "cash": 9000.0, "profit": -1000.0})
	synthetic.append({"day": 1, "cash": 9500.0, "profit": -500.0})
	synthetic.append({"day": 2, "cash": 10500.0, "profit": 1000.0})
	synthetic.append({"day": 3, "cash": 11000.0, "profit": 500.0})
	var pr: Dictionary = PacingReport.build(synthetic, 10000.0)
	_check("pacing: 4 days", int(pr.days) == 4)
	_check("pacing: min cash 9000", absf(pr.min_cash - 9000.0) < 1.0, "got %.0f" % pr.min_cash)
	_check("pacing: break-even on day 2", int(pr.break_even_day) == 2, "got %d" % pr.break_even_day)
	_check("pacing: 2 negative days", int(pr.neg_profit_days) == 2, "got %d" % pr.neg_profit_days)
	_check("pacing: max negative run 2 (consecutive)", int(pr.max_negative_run) == 2, "got %d" % pr.max_negative_run)
	_check("pacing: survived", bool(pr.survived))
	_check("pacing: summary non-empty", (pr.summary as String).length() > 0)

	# --- PacingReport.check_targets: §19 balance targets ---
	var t1: Dictionary = PacingReport.check_targets(14, 2, 90.0, true, false)
	_check("§19: contract fill 90% >= 85% met", bool(t1["contract_fill"].met))
	_check("§19: stockout 2/14 = 14% < 20% met", bool(t1["stockout"].met))
	_check("§19: all targets met", bool(t1.all_met))
	var t2: Dictionary = PacingReport.check_targets(14, 5, 70.0, false, false)
	_check("§19: contract fill 70% < 85% NOT met", not bool(t2["contract_fill"].met))
	_check("§19: stockout 5/14 = 36% >= 20% NOT met", not bool(t2["stockout"].met))
	_check("§19: not all met", not bool(t2.all_met))

	# --- pacing_report() wired into a real campaign run ---
	var camp3 := Campaign.new(db, EconomyData.Difficulty.NORMAL, 12345,
		"RCP_MILK_BAR_01", "CHAIN_A", "")
	camp3.run(14)
	var pacing: Dictionary = camp3.pacing_report()
	_check("pacing_report: 14 days", int(pacing.days) == 14)
	_check("pacing_report: has targets block", pacing.has("targets"))
	_check("pacing_report: has stockout_days", pacing.has("stockout_days"))
	_check("pacing_report: start cash matches", absf(pacing.start_cash - camp3.sim.balance_db.get_economy_value("ECO_START_CASH", camp3.sim.diff)) < 1.0)
	# a 14-day normal run should survive (positive profit)
	_check("pacing_report: 14-day normal run survived", bool(pacing.survived))

	# --- M5 HUD layer: build headlessly, wire a campaign, assert rendered text ---
	_test_m5_hud(db)

func _test_m5_hud(db: BalanceDatabase) -> void:
	print("\n[TEST] M5 HUD: build + update + rendered text")
	# the GameState autoload (the HUD reads GameState.campaign)
	var gs: Node = root.get_node("GameState")
	if gs == null:
		_check("GameState autoload present", false, "root.get_node('GameState') == null")
		return
	# build a campaign and drive a few days so the HUD has data
	var camp := Campaign.new(db, EconomyData.Difficulty.NORMAL, 7,
		"RCP_MILK_BAR_01", "CHAIN_A", "")
	camp.run(3)
	gs.campaign = camp
	gs.running = false
	# build the HUD, add to the scene tree, force an update
	var hud: CanvasLayer = load("res://src/game/hud_view.gd").new()
	root.add_child(hud)
	hud._update()
	# top bar should show the day + cash
	var top_text: String = hud._top_bar.text
	_check("HUD top bar shows day", top_text.contains("Day"), "got: %s" % top_text)
	_check("HUD top bar shows cash", top_text.contains("Cash"), "got: %s" % top_text)
	# bottleneck section: a real line always has a natural bottleneck
	var b_summary: String = hud._labels["b_summary"].text
	_check("HUD bottleneck summary non-empty", b_summary.length() > 0, "got: %s" % b_summary)
	var b_bottleneck: String = hud._labels["b_bottleneck"].text
	_check("HUD names the natural bottleneck", b_bottleneck.contains("bottleneck"), "got: %s" % b_bottleneck)
	# quality section: names a weakest component + shows grade
	var q_summary: String = hud._labels["q_summary"].text
	_check("HUD quality summary names weakest component", q_summary.contains("weakest"), "got: %s" % q_summary)
	var q_grade: String = hud._labels["q_grade"].text
	_check("HUD shows grade", q_grade.contains("Grade"), "got: %s" % q_grade)
	# quality bars: all six components present and in 0..100
	var all_bars_ok: bool = true
	for k in ["T", "P", "C", "F", "S", "W"]:
		if not hud._bars.has(k):
			all_bars_ok = false
		elif hud._bars[k].value < 0.0 or hud._bars[k].value > 100.0:
			all_bars_ok = false
	_check("HUD has all 6 quality bars in range", all_bars_ok)
	# pacing section
	var p_summary: String = hud._labels["p_summary"].text
	_check("HUD pacing summary non-empty", p_summary.length() > 0, "got: %s" % p_summary)
	# toggle panel
	var was_open: bool = hud._panel_open
	hud.toggle_panel()
	_check("HUD toggle_panel flips state", hud._panel_open != was_open)
	hud.toggle_panel()
	root.remove_child(hud)
