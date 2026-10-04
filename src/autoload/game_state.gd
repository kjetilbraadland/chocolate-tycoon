extends Node
## Autoload: run-level state shared across scenes. Owns the live Campaign and
## advances it tick-by-tick so the isometric view + HUD reflect the real sim.

var active_difficulty: EconomyData.Difficulty = EconomyData.Difficulty.NORMAL
var active_seed: int = 0
var campaign: Campaign = null
var running: bool = false
var speed: int = 1  # 1x / 2x / 4x (ticks per frame)
var recipe_id: String = "RCP_MILK_BAR_01"
var chain_id: String = "CHAIN_A"
var contract_pack_id: String = "CONTRACT_A"

# machine placement grid: machine_id -> [grid_x, grid_y]
var machine_layout: Dictionary = {}

var _day_started: bool = false

func new_run(diff: EconomyData.Difficulty, seed: int,
		r_id: String = "RCP_MILK_BAR_01", c_id: String = "CHAIN_A",
		p_id: String = "CONTRACT_A") -> Campaign:
	active_difficulty = diff
	active_seed = seed
	recipe_id = r_id
	chain_id = c_id
	contract_pack_id = p_id
	campaign = Campaign.new(BalanceDB.db, diff, seed, r_id, c_id, p_id)
	running = false
	_day_started = false
	return campaign

func start() -> void:
	if campaign != null:
		running = true

func pause() -> void:
	running = false

func toggle() -> void:
	running = not running

# Restore a run from a save dictionary (from SaveSystem.load).
func load_game(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	active_difficulty = int(data.get("difficulty", 0)) as EconomyData.Difficulty
	active_seed = int(data.get("seed", 0))
	var sim: Simulation = campaign.sim if campaign != null else null
	if sim != null:
		sim.day = int(data.get("day", 0))
		sim.tick_in_day = int(data.get("tick_in_day", 0))
		sim.brand_score = float(data.get("brand_score", 0.5))
		sim.category_reputation = float(data.get("category_reputation", 0.5))
		sim.economy.cash = float(data.get("cash", 0.0))
		sim.economy.debt = float(data.get("debt", 0.0))
		sim.total_units_produced = float(data.get("total_units_produced", 0.0))
		sim.total_revenue = float(data.get("total_revenue", 0.0))
		sim.total_cost = float(data.get("total_cost", 0.0))
	if data.has("machine_layout"):
		machine_layout = data["machine_layout"]
	return true

func _process(_delta: float) -> void:
	if not running or campaign == null:
		return
	for i in range(speed):
		if not _day_started:
			campaign.start_day()
			_day_started = true
		campaign.tick()
		# close the day after 1440 ticks
		if campaign.sim.tick_in_day >= 1440:
			campaign.sim.tick_in_day = 0
			var r: Dictionary = campaign.close_day()
			campaign.day_results.append(r)
			_day_started = false
