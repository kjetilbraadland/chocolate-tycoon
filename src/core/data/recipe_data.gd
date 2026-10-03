class_name RecipeData
extends RefCounted
## One row of recipes_balance_template.csv. Pure data, no scene-tree dependency.

var recipe_id: String = ""
var recipe_name: String = ""
var category: String = ""
var unlock_tier: int = 1

var input_cocoa_pct: float = 0.0
var input_sugar_pct: float = 0.0
var input_milk_pct: float = 0.0
var input_fat_pct: float = 0.0
var input_flavor_pct: float = 0.0
var input_nut_pct: float = 0.0

var base_batch_size_kg: float = 0.0
var process_time_min: float = 0.0
var ideal_temp_c: float = 0.0
var ideal_conche_min: float = 0.0
var yield_pct: float = 100.0

var base_taste_score: float = 0.0
var base_quality_score: float = 0.0
var base_shelf_life_days: int = 0
var base_unit_cost: float = 0.0
var base_unit_price: float = 0.0
var brand_appeal: float = 0.0
var shop_demand_base: float = 0.0
var contract_demand_base: float = 0.0
var defect_rate_pct: float = 0.0
var returns_rate_pct: float = 0.0
var notes: String = ""

static func from_row(row: Dictionary, header: Array) -> RecipeData:
	var d := RecipeData.new()
	d.recipe_id = _s(row, header, "recipe_id")
	d.recipe_name = _s(row, header, "recipe_name")
	d.category = _s(row, header, "category")
	d.unlock_tier = _i(row, header, "unlock_tier")
	d.input_cocoa_pct = _f(row, header, "input_cocoa_pct")
	d.input_sugar_pct = _f(row, header, "input_sugar_pct")
	d.input_milk_pct = _f(row, header, "input_milk_pct")
	d.input_fat_pct = _f(row, header, "input_fat_pct")
	d.input_flavor_pct = _f(row, header, "input_flavor_pct")
	d.input_nut_pct = _f(row, header, "input_nut_pct")
	d.base_batch_size_kg = _f(row, header, "base_batch_size_kg")
	d.process_time_min = _f(row, header, "process_time_min")
	d.ideal_temp_c = _f(row, header, "ideal_temp_c")
	d.ideal_conche_min = _f(row, header, "ideal_conche_min")
	d.yield_pct = _f(row, header, "yield_pct")
	d.base_taste_score = _f(row, header, "base_taste_score")
	d.base_quality_score = _f(row, header, "base_quality_score")
	d.base_shelf_life_days = _i(row, header, "base_shelf_life_days")
	d.base_unit_cost = _f(row, header, "base_unit_cost")
	d.base_unit_price = _f(row, header, "base_unit_price")
	d.brand_appeal = _f(row, header, "brand_appeal")
	d.shop_demand_base = _f(row, header, "shop_demand_base")
	d.contract_demand_base = _f(row, header, "contract_demand_base")
	d.defect_rate_pct = _f(row, header, "defect_rate_pct")
	d.returns_rate_pct = _f(row, header, "returns_rate_pct")
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
