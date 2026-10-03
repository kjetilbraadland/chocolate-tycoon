class_name LookupPacks
extends RefCounted
## Parsed lookup_packs_template.csv. Long-format (pack_id, pack_type, key, subkey, value).
## Provides typed accessors for machine chains, contract packs, and scenario metadata.

# pack_id -> { key/subkey -> value } (raw)
var raw: Dictionary = {}
# machine chains: chain_id -> Array[stage_name -> machine_id] ordered by stage_N
var machine_chains: Dictionary = {}
# contract packs: contract_id -> { target_units: float, min_grade: String, penalty_rate: float }
var contract_packs: Dictionary = {}
# scenario metadata: scenario_id -> { duration_days: int }
var scenario_meta: Dictionary = {}

static func parse(csv_text: String) -> LookupPacks:
	var parsed: Dictionary = CsvLoader.parse(csv_text)
	var packs := LookupPacks.new()
	for row in parsed.rows:
		var pack_id: String = row.get("pack_id", "")
		var pack_type: String = row.get("pack_type", "")
		var key: String = row.get("key", "")
		var subkey: String = row.get("subkey", "")
		var value: String = row.get("value", "")
		if not packs.raw.has(pack_id):
			packs.raw[pack_id] = {}
		packs.raw[pack_id][key + "|" + subkey] = value
		match pack_type:
			"machine_chain":
				var stage_num: int = key.replace("stage_", "").to_int()
				if not packs.machine_chains.has(pack_id):
					packs.machine_chains[pack_id] = {}
				packs.machine_chains[pack_id][stage_num] = value
			"contract_pack":
				if not packs.contract_packs.has(pack_id):
					packs.contract_packs[pack_id] = { "target_units": 0.0, "min_grade": "", "penalty_rate": 0.0 }
				if key == "target_units":
					packs.contract_packs[pack_id]["target_units"] = value.to_float()
				elif key == "min_grade":
					packs.contract_packs[pack_id]["min_grade"] = value
				elif key == "penalty_rate":
					packs.contract_packs[pack_id]["penalty_rate"] = value.to_float()
			"scenario":
				if key == "duration_days":
					packs.scenario_meta[pack_id] = { "duration_days": value.to_int() }
	return packs

# Ordered list of machine_ids for a chain (stage 1..N).
func chain_machine_ids(chain_id: String) -> Array:
	var out: Array = []
	if not machine_chains.has(chain_id):
		return out
	var stages: Dictionary = machine_chains[chain_id]
	for k in stages.keys():
		out.append(stages[k])
	return out
