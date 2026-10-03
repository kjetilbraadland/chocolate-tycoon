class_name Shop
extends RefCounted
## Own-chocolate-shop demand (locked model, GDD §9.4).
## D = B * (1 - p) * (1 + 0.6b) * (1 + 0.4r) * e
## b = normalized global brand (0..1), r = normalized category reputation (0..1),
## e = footfall event multiplier (0.70..1.40), p = price penalty (0..0.50).

var balance_db: BalanceDatabase
var diff: EconomyData.Difficulty
var price_elasticity: float = 0.5

func _init(db: BalanceDatabase, d: EconomyData.Difficulty = EconomyData.Difficulty.NORMAL) -> void:
	balance_db = db
	diff = d
	price_elasticity = balance_db.get_economy_value("ECO_SHOP_PRICE_ELASTICITY", diff)

# price_index: relative price vs category market average (1.0 = market average).
# Returns the price penalty factor p in 0.0..0.50.
func price_penalty(price_index: float) -> float:
	var over: float = maxf(price_index - 1.0, 0.0)
	return minf(over * price_elasticity, 0.50)

# Expected daily demand in units.
func daily_demand(base_demand: float, price_index: float, brand_norm: float,
		category_reputation_norm: float, footfall_event: float) -> float:
	var p: float = price_penalty(price_index)
	var b: float = clampf(brand_norm, 0.0, 1.0)
	var r: float = clampf(category_reputation_norm, 0.0, 1.0)
	var e: float = clampf(footfall_event, 0.70, 1.40)
	return base_demand * (1.0 - p) * (1.0 + 0.6 * b) * (1.0 + 0.4 * r) * e

# Units actually sold given stock and demand.
func sell(demand: float, stock: float) -> float:
	return minf(demand, maxf(stock, 0.0))
