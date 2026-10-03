class_name Economy
extends RefCounted
## Finance & economy (technical design §4.4). Daily-tick P&L, debt, and the
## locked bankruptcy rule (GDD §12.1): bankruptcy requires BOTH (1) debt > debt
## limit AND (2) >=1 missed obligation at period close. Grace window before fail.

var diff: EconomyData.Difficulty = EconomyData.Difficulty.NORMAL
var balance_db: BalanceDatabase

var cash: float = 0.0
var debt: float = 0.0
var loan_rate: float = 0.0
var debt_limit: float = 0.0
var wage_base: float = 0.0
var energy_price: float = 0.0
var spoil_rate: float = 0.0
var truck_slots: int = 0
var contract_penalty_rate: float = 0.0
var contract_reputation_hit: float = 0.0
var grace_days: int = 0

var day: int = 0
var missed_obligations_streak: int = 0
var is_bankrupt: bool = false
var bankruptcy_telegraphed: bool = false

# last day's P&L (for HUD / test harness)
var last_revenue: float = 0.0
var last_cost: float = 0.0
var last_profit: float = 0.0

func _init(db: BalanceDatabase, d: EconomyData.Difficulty = EconomyData.Difficulty.NORMAL) -> void:
	balance_db = db
	diff = d
	_reload_knobs()
	cash = balance_db.get_economy_value("ECO_START_CASH", diff)

func _reload_knobs() -> void:
	debt_limit = balance_db.get_economy_value("ECO_DEBT_LIMIT", diff)
	loan_rate = balance_db.get_economy_value("ECO_BASE_LOAN_RATE", diff)
	wage_base = balance_db.get_economy_value("ECO_WAGE_BASE", diff)
	energy_price = balance_db.get_economy_value("ECO_ENERGY_PRICE", diff)
	spoil_rate = balance_db.get_economy_value("ECO_STORAGE_SPOIL_RATE", diff)
	truck_slots = int(balance_db.get_economy_value("ECO_TRUCK_SLOT_COUNT", diff))
	contract_penalty_rate = balance_db.get_economy_value("ECO_CONTRACT_PENALTY_RATE", diff)
	contract_reputation_hit = balance_db.get_economy_value("ECO_CONTRACT_REPUTATION_HIT", diff)
	grace_days = int(balance_db.get_economy_value("ECO_BANKRUPTCY_GRACE_DAYS", diff))

func take_loan(amount: float) -> void:
	debt += amount
	cash += amount

func pay_down_loan(amount: float) -> void:
	var pay: float = minf(amount, debt)
	debt -= pay
	cash -= pay

# Daily interest accrual.
func accrue_interest() -> float:
	var interest: float = debt * loan_rate / 365.0
	cash -= interest
	return interest

# Record a day's costs and revenue; returns profit.
func record_day(revenue: float, cost: float) -> float:
	last_revenue = revenue
	last_cost = cost
	last_profit = revenue - cost
	cash += last_profit
	return last_profit

# Daily wage cost for `staff` workers at `wage_policy` multiplier.
func wage_cost(staff: int, wage_policy: float) -> float:
	return wage_base * staff * wage_policy

# Energy cost for `power_kw` running `hours`.
func energy_cost(power_kw: float, hours: float) -> float:
	return energy_price * power_kw * hours

# Daily spoilage on `stock_units` of perishables.
func spoilage(stock_units: float) -> float:
	return stock_units * spoil_rate

# Obligations due at period close: wages, loan payment, contract penalty invoice.
func obligations_due(wages: float, loan_payment: float, contract_penalty: float) -> Array:
	var due: Array = []
	if wages > 0.0:
		due.append({ "type": "wages", "amount": wages })
	if loan_payment > 0.0:
		due.append({ "type": "loan", "amount": loan_payment })
	if contract_penalty > 0.0:
		due.append({ "type": "contract_penalty", "amount": contract_penalty })
	return due

# Check the locked bankruptcy rule. `missed_obligations` = count missed this close.
func check_bankruptcy(missed_obligations: int) -> void:
	day += 1
	var condition_debt: bool = debt > debt_limit
	var condition_missed: bool = missed_obligations >= 1
	if condition_debt and condition_missed:
		missed_obligations_streak += 1
	else:
		missed_obligations_streak = 0
	# telegraph when one condition is already met (GDD §15)
	bankruptcy_telegraphed = condition_debt or condition_missed
	if missed_obligations_streak >= grace_days:
		is_bankrupt = true
