class_name EconomyData
extends RefCounted
## One economy knob row from economy_balance_template.csv.
## Stores both normal and hard values; the active difficulty selects one.

enum Difficulty { NORMAL, HARD }

var economy_id: String = ""
var group_name: String = ""
var normal_value: float = 0.0
var hard_value: float = 0.0
var min_value: float = 0.0
var max_value: float = 0.0
var units: String = ""
var applies_to: String = ""
var formula_hint: String = ""
var notes: String = ""

func value_for(diff: Difficulty) -> float:
	return hard_value if diff == Difficulty.HARD else normal_value

static func from_row(row: Dictionary, _header: Array) -> EconomyData:
	var d := EconomyData.new()
	d.economy_id = row.get("economy_id", "")
	d.group_name = row.get("group_name", "")
	d.normal_value = _f(row, "normal_value")
	d.hard_value = _f(row, "hard_value")
	d.min_value = _f(row, "min_value")
	d.max_value = _f(row, "max_value")
	d.units = row.get("units", "")
	d.applies_to = row.get("applies_to", "")
	d.formula_hint = row.get("formula_hint", "")
	d.notes = row.get("notes", "")
	return d

static func _f(row: Dictionary, key: String) -> float:
	var v: String = row.get(key, "0")
	return v.to_float() if v != "" else 0.0
