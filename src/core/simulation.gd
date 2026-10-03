class_name Simulation
extends RefCounted
## Top-level core simulation (technical design §4). Pure GDScript, deterministic,
## no scene-tree dependency — runs headless at any speed.
##
## Time model: 1 tick = 1 in-game minute; 1 day = 1440 ticks.
## Daily close (tick 1440) triggers the economy tick; weekly close (every 7th
## day) triggers contract settlement.

const TICKS_PER_DAY: int = 1440

var balance_db: BalanceDatabase
var diff: EconomyData.Difficulty
var rng: RandomNumberGenerator

var economy: Economy
var shop: Shop
var contracts: Contracts
var scorer := QualityScorer.new()
var line: ProductionLine

var day: int = 1
var tick_in_day: int = 0
var seed: int = 0

# run-level state
var brand_score: float = 0.5        # global brand 0..1
var category_reputation: float = 0.5 # category rep 0..1
var total_units_produced: float = 0.0
var total_revenue: float = 0.0
var total_cost: float = 0.0

signal day_completed(day: int, result: Dictionary)
signal bankrupt(day: int)

func _init(db: BalanceDatabase, d: EconomyData.Difficulty = EconomyData.Difficulty.NORMAL,
		s: int = 0) -> void:
	balance_db = db
	diff = d
	seed = s
	rng = RandomNumberGenerator.new()
	if s != 0:
		rng.seed = s
	economy = Economy.new(db, d)
	shop = Shop.new(db, d)
	contracts = Contracts.new(db, d)
	line = ProductionLine.new(rng)
	day = 1
	tick_in_day = 0

# Build the production line from a lookup chain.
func build_line(chain_id: String) -> bool:
	line = ProductionLine.new(rng)
	var ids: Array = balance_db.lookup.chain_machine_ids(chain_id)
	if ids.is_empty():
		return false
	for id in ids:
		var md: MachineData = balance_db.get_machine(id)
		if md != null:
			line.add_machine(md)
	return ids.size() > 0

# Advance one in-game minute.
func tick() -> void:
	line.tick(true)
	tick_in_day += 1
	if tick_in_day >= TICKS_PER_DAY:
		tick_in_day = 0
		_close_day()

# Advance an entire in-game day (for headless runs / tests).
func run_day() -> Dictionary:
	tick_in_day = 0
	for i in range(TICKS_PER_DAY):
		line.tick(true)
	return _close_day()

func _close_day() -> Dictionary:
	# daily economy: opex for the line's machines
	var opex: float = 0.0
	var power: float = 0.0
	for m in line.machines:
		opex += m.data.opex_per_day
		power += m.data.power_kw
	var energy: float = economy.energy_cost(power, 24.0)
	var cost: float = opex + energy
	var revenue: float = 0.0  # shop/contract revenue applied by caller in full runs
	economy.record_day(revenue, cost)
	economy.accrue_interest()
	var result := {
		"day": day,
		"units_produced": line.total_units_today(),
		"cost": cost,
		"revenue": revenue,
		"profit": economy.last_profit,
		"cash": economy.cash,
		"debt": economy.debt,
	}
	day += 1
	day_completed.emit(day - 1, result)
	if economy.is_bankrupt:
		bankrupt.emit(day - 1)
	return result
