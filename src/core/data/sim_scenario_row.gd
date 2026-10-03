class_name SimScenarioRow
extends RefCounted
## One row of master_simulation_template.csv — a single simulated day with expected outputs.
## These expected_* columns are the acceptance oracle for the headless test harness.

var sim_row_id: String = ""
var enabled: bool = true
var scenario_id: String = ""
var difficulty_mode: String = ""
var day_index: int = 0
var recipe_id: String = ""
var machine_chain_id: String = ""

# input multipliers / controls
var shop_price_multiplier: float = 1.0
var wage_policy_multiplier: float = 1.0
var rnd_investment_level: int = 0
var inspector_tier: int = 0
var contract_pack_id: String = ""
var contract_target_units: float = 0.0
var contract_min_grade: String = ""
var contract_penalty_rate: float = 0.0
var footfall_event_multiplier: float = 1.0
var input_cost_multiplier: float = 1.0
var energy_price_multiplier: float = 1.0
var storage_decay_multiplier: float = 1.0
var breakdown_multiplier: float = 1.0
var transport_delay_multiplier: float = 1.0
var batch_attempts_per_day: int = 0

# expected outputs (oracle)
var expected_units_output: float = 0.0
var expected_quality_Q: float = 0.0
var expected_grade: String = ""
var expected_unit_cost: float = 0.0
var expected_unit_price: float = 0.0
var expected_shop_demand: float = 0.0
var expected_contract_fulfillment_pct: float = 0.0
var expected_penalty_cost: float = 0.0
var expected_returns_pct: float = 0.0
var expected_daily_revenue: float = 0.0
var expected_daily_cost: float = 0.0
var expected_daily_profit: float = 0.0
var expected_brand_delta: float = 0.0
var expected_debt_delta: float = 0.0
var notes: String = ""

static func from_row(row: Dictionary, _header: Array) -> SimScenarioRow:
	var d := SimScenarioRow.new()
	d.sim_row_id = row.get("sim_row_id", "")
	d.enabled = row.get("enabled", "TRUE").to_upper() == "TRUE"
	d.scenario_id = row.get("scenario_id", "")
	d.difficulty_mode = row.get("difficulty_mode", "")
	d.day_index = _i(row, "day_index")
	d.recipe_id = row.get("recipe_id", "")
	d.machine_chain_id = row.get("machine_chain_id", "")
	d.shop_price_multiplier = _f(row, "shop_price_multiplier")
	d.wage_policy_multiplier = _f(row, "wage_policy_multiplier")
	d.rnd_investment_level = _i(row, "rnd_investment_level")
	d.inspector_tier = _i(row, "inspector_tier")
	d.contract_pack_id = row.get("contract_pack_id", "")
	d.contract_target_units = _f(row, "contract_target_units")
	d.contract_min_grade = row.get("contract_min_grade", "")
	d.contract_penalty_rate = _f(row, "contract_penalty_rate")
	d.footfall_event_multiplier = _f(row, "footfall_event_multiplier")
	d.input_cost_multiplier = _f(row, "input_cost_multiplier")
	d.energy_price_multiplier = _f(row, "energy_price_multiplier")
	d.storage_decay_multiplier = _f(row, "storage_decay_multiplier")
	d.breakdown_multiplier = _f(row, "breakdown_multiplier")
	d.transport_delay_multiplier = _f(row, "transport_delay_multiplier")
	d.batch_attempts_per_day = _i(row, "batch_attempts_per_day")
	d.expected_units_output = _f(row, "expected_units_output")
	d.expected_quality_Q = _f(row, "expected_quality_Q")
	d.expected_grade = row.get("expected_grade", "")
	d.expected_unit_cost = _f(row, "expected_unit_cost")
	d.expected_unit_price = _f(row, "expected_unit_price")
	d.expected_shop_demand = _f(row, "expected_shop_demand")
	d.expected_contract_fulfillment_pct = _f(row, "expected_contract_fulfillment_pct")
	d.expected_penalty_cost = _f(row, "expected_penalty_cost")
	d.expected_returns_pct = _f(row, "expected_returns_pct")
	d.expected_daily_revenue = _f(row, "expected_daily_revenue")
	d.expected_daily_cost = _f(row, "expected_daily_cost")
	d.expected_daily_profit = _f(row, "expected_daily_profit")
	d.expected_brand_delta = _f(row, "expected_brand_delta")
	d.expected_debt_delta = _f(row, "expected_debt_delta")
	d.notes = row.get("notes", "")
	return d

static func _f(row: Dictionary, key: String) -> float:
	var v: String = row.get(key, "0")
	return v.to_float() if v != "" else 0.0

static func _i(row: Dictionary, key: String) -> int:
	var v: String = row.get(key, "0")
	return v.to_int() if v != "" else 0
