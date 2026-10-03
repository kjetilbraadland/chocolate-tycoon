class_name BalanceDatabase
extends RefCounted
## Loads all balancing CSVs into typed Resources and exposes typed getters.
## Single source of truth: game code reads balance values ONLY through this.

var recipes: Dictionary = {}      # recipe_id -> RecipeData
var machines: Dictionary = {}     # machine_id -> MachineData
var economy: Dictionary = {}      # economy_id -> EconomyData
var lookup: LookupPacks = null
var sim_rows: Array = []         # Array[SimScenarioRow]
var sim_rows_by_scenario: Dictionary = {}  # scenario_id -> Array[SimScenarioRow]
var scenario_summaries: Dictionary = {}  # scenario_id -> Dictionary (summary row)

var load_errors: Array = []

const DATA_DIR := "res://data/"

func load_all() -> bool:
	load_errors = []
	recipes.clear()
	machines.clear()
	economy.clear()
	sim_rows = []
	sim_rows_by_scenario = {}
	scenario_summaries = {}
	var ok := true
	ok = _load_recipes() and ok
	ok = _load_machines() and ok
	ok = _load_economy() and ok
	ok = _load_lookup() and ok
	ok = _load_sim() and ok
	_load_summaries()
	return ok

func _read_csv(file_name: String) -> String:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		load_errors.append("missing file: " + path)
		return ""
	return FileAccess.get_file_as_string(path)

func _load_recipes() -> bool:
	var parsed: Dictionary = CsvLoader.parse(_read_csv("recipes_balance_template.csv"))
	for row in parsed.rows:
		var r: RecipeData = RecipeData.from_row(row, parsed.header)
		if r.recipe_id != "":
			recipes[r.recipe_id] = r
	return parsed.rows.size() > 0

func _load_machines() -> bool:
	var parsed: Dictionary = CsvLoader.parse(_read_csv("machines_balance_template.csv"))
	for row in parsed.rows:
		var m: MachineData = MachineData.from_row(row, parsed.header)
		if m.machine_id != "":
			machines[m.machine_id] = m
	return parsed.rows.size() > 0

func _load_economy() -> bool:
	var parsed: Dictionary = CsvLoader.parse(_read_csv("economy_balance_template.csv"))
	for row in parsed.rows:
		var e: EconomyData = EconomyData.from_row(row, parsed.header)
		if e.economy_id != "":
			economy[e.economy_id] = e
	return parsed.rows.size() > 0

func _load_lookup() -> bool:
	lookup = LookupPacks.parse(_read_csv("lookup_packs_template.csv"))
	return lookup != null and not lookup.machine_chains.is_empty()

func _load_sim() -> bool:
	var parsed: Dictionary = CsvLoader.parse(_read_csv("master_simulation_template.csv"))
	for row in parsed.rows:
		var s: SimScenarioRow = SimScenarioRow.from_row(row, parsed.header)
		if s.sim_row_id != "":
			sim_rows.append(s)
			if not sim_rows_by_scenario.has(s.scenario_id):
				sim_rows_by_scenario[s.scenario_id] = []
			sim_rows_by_scenario[s.scenario_id].append(s)
	return parsed.rows.size() > 0

func _load_summaries() -> void:
	var parsed: Dictionary = CsvLoader.parse(_read_csv("scenario_summary_template.csv"))
	for row in parsed.rows:
		var sid: String = row.get("scenario_id", "")
		if sid != "":
			scenario_summaries[sid] = row

# --- typed getters ---

func get_recipe(id: String) -> RecipeData:
	return recipes.get(id, null)

func get_machine(id: String) -> MachineData:
	return machines.get(id, null)

func get_economy(id: String) -> EconomyData:
	return economy.get(id, null)

func get_economy_value(id: String, diff: EconomyData.Difficulty) -> float:
	var e: EconomyData = economy.get(id, null)
	return e.value_for(diff) if e != null else 0.0

func get_contract_pack(id: String) -> Dictionary:
	return lookup.contract_packs.get(id, {}) if lookup else {}
