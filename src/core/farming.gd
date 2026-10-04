class_name FarmingSystem
extends RefCounted
## M4: farming side-map (GDD §16, locked). A dedicated side-map where the
## player places farm plots + processing sheds + outbound depots. Farm outputs
## are shipped back to the factory via scheduled transport routes. Farming is
## intentionally lighter than factory gameplay and primarily improves:
##   - input cost stability (in-house sugar/cocoa lowers the input cost floor)
##   - quality control (in-house inputs raise the quality sanitation component)
##   - contract resilience (stable supply reduces input-cost volatility)
##
## Plots produce per day; outputs accumulate in the outbound depot and are
## shipped back on a transport schedule (every N days). The shipped amount
## feeds the factory's in-house input supply, reducing the input cost
## multiplier and adding a quality bonus.

enum Crop { SUGAR, COCOA }

# Per-plot daily production (units) and the transport schedule.
const PLOT_DAILY_OUTPUT := { "sugar": 40.0, "cocoa": 25.0 }
const TRANSPORT_INTERVAL_DAYS := 2  # outbound depots ship every 2 days

var plots: Dictionary = {}  # crop -> { "count": int, "daily_output": float }
var depot: float = 0.0  # accumulated output awaiting transport
var last_ship_day: int = 0
var shipped_total: float = 0.0  # total shipped back to the factory
var rng: RandomNumberGenerator

func _init(r: RandomNumberGenerator = null) -> void:
	rng = r if r != null else RandomNumberGenerator.new()

# Place a farm plot. Returns the new plot count for that crop.
func add_plot(crop: Crop) -> int:
	var key: String = _crop_key(crop)
	if not plots.has(key):
		plots[key] = { "count": 0, "daily_output": float(PLOT_DAILY_OUTPUT[key]) }
	var d: Dictionary = plots[key]
	d["count"] = int(d["count"]) + 1
	d["daily_output"] = float(PLOT_DAILY_OUTPUT[key])
	return int(d["count"])

func plot_count(crop: Crop) -> int:
	var key: String = _crop_key(crop)
	if not plots.has(key):
		return 0
	return int(plots[key].count)

# Advance one day: plots produce into the depot; if the transport schedule
# fires, ship the depot back to the factory. Returns units shipped this day.
func tick_day(day: int) -> float:
	var produced: float = 0.0
	for key in plots.keys():
		produced += float(plots[key].daily_output) * int(plots[key].count)
	depot += produced
	# scheduled transport
	if day - last_ship_day >= TRANSPORT_INTERVAL_DAYS:
		var shipped: float = depot
		depot = 0.0
		last_ship_day = day
		shipped_total += shipped
		return shipped
	return 0.0

# In-house supply reduces the input cost multiplier. More shipped input =
# lower cost floor. Returns a multiplier in (0.7 .. 1.0].
func input_cost_multiplier() -> float:
	# each 100 units shipped reduces the multiplier by 0.02, floor 0.7
	var reduction: float = minf(shipped_total / 100.0 * 0.02, 0.30)
	return 1.0 - reduction

# In-house inputs improve quality control (sanitation/consistency bonus).
# Returns a 0..100 quality bonus.
func quality_bonus() -> float:
	return minf(shipped_total / 50.0, 10.0)

func _crop_key(c: Crop) -> String:
	match c:
		Crop.SUGAR: return "sugar"
		Crop.COCOA: return "cocoa"
		_: return "sugar"
