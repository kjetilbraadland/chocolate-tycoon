class_name MachineData
extends RefCounted
## One row of machines_balance_template.csv. Pure data.

var machine_id: String = ""
var machine_name: String = ""
var stage: String = ""
var unlock_tier: int = 1
var footprint_w: int = 1
var footprint_h: int = 1
var capex_cost: float = 0.0
var opex_per_day: float = 0.0
var power_kw: float = 0.0
var input_buffer_units: int = 0
var output_buffer_units: int = 0
var cycle_time_sec: float = 0.0
var throughput_units_per_min: float = 0.0
var ideal_temp_c: float = 0.0
var temp_tolerance_c: float = 0.0
var breakdown_chance_pct_day: float = 0.0
var repair_time_min: float = 0.0
var operator_required: int = 1
var wage_quality_sensitivity: float = 0.0
var base_quality_impact: float = 0.0
var queue_penalty_factor: float = 0.0
var maintenance_interval_days: int = 7
var maintenance_cost: float = 0.0
var notes: String = ""

static func from_row(row: Dictionary, header: Array) -> MachineData:
	var d := MachineData.new()
	d.machine_id = _s(row, header, "machine_id")
	d.machine_name = _s(row, header, "machine_name")
	d.stage = _s(row, header, "stage")
	d.unlock_tier = _i(row, header, "unlock_tier")
	d.footprint_w = _i(row, header, "footprint_w")
	d.footprint_h = _i(row, header, "footprint_h")
	d.capex_cost = _f(row, header, "capex_cost")
	d.opex_per_day = _f(row, header, "opex_per_day")
	d.power_kw = _f(row, header, "power_kw")
	d.input_buffer_units = _i(row, header, "input_buffer_units")
	d.output_buffer_units = _i(row, header, "output_buffer_units")
	d.cycle_time_sec = _f(row, header, "cycle_time_sec")
	d.throughput_units_per_min = _f(row, header, "throughput_units_per_min")
	d.ideal_temp_c = _f(row, header, "ideal_temp_c")
	d.temp_tolerance_c = _f(row, header, "temp_tolerance_c")
	d.breakdown_chance_pct_day = _f(row, header, "breakdown_chance_pct_day")
	d.repair_time_min = _f(row, header, "repair_time_min")
	d.operator_required = _i(row, header, "operator_required")
	d.wage_quality_sensitivity = _f(row, header, "wage_quality_sensitivity")
	d.base_quality_impact = _f(row, header, "base_quality_impact")
	d.queue_penalty_factor = _f(row, header, "queue_penalty_factor")
	d.maintenance_interval_days = _i(row, header, "maintenance_interval_days")
	d.maintenance_cost = _f(row, header, "maintenance_cost")
	d.notes = _s(row, header, "notes")
	return d

static func _s(row: Dictionary, _header: Array, key: String) -> String:
	return row.get(key, "")

static func _f(row: Dictionary, _header: Array, key: String) -> float:
	var v: String = row.get(key, "0")
	return v.to_float() if v != "" else 0.0

static func _i(row: Dictionary, _header: Array, key: String) -> int:
	var v: String = row.get(key, "0")
	return v.to_int() if v != "" else 0
