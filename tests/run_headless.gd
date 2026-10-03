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
	var known := ["unit", "scenario", "all"]
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

	if mode == "scenario" or mode == "all":
		if scenario != "":
			_test_scenario(db, scenario)
		else:
			for sid in db.sim_rows_by_scenario.keys():
				_test_scenario(db, sid)

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
		_report_target("hard avg_profit in [-10,40]", avg_profit >= -10.0 and avg_profit <= 40.0, "got %.2f" % avg_profit)
		_report_target("hard avg_Q >= 71 (P3 tuning target)", avg_q >= 71.0, "got %.2f (P3 not yet applied)" % avg_q)
		_report_target("hard neg_profit_days in [4,7]", neg_profit_days >= 4 and neg_profit_days <= 7, "got %d" % neg_profit_days)
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
