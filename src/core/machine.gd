class_name MachineState
extends RefCounted
## Per-machine runtime state machine (GDD §7.1 / technical design §4.2).
## IDLE -> RUNNING -> (breakdown) -> REPAIRING -> IDLE, with maintenance.
## A machine produces only when input >= 1 and output buffer has space.

enum State { IDLE, RUNNING, BREAKDOWN, REPAIRING, MAINTENANCE }

var data: MachineData
var state: State = State.IDLE
var input_buffer: float = 0.0
var output_buffer: float = 0.0
var cycle_progress: float = 0.0   # ticks accumulated toward a cycle
var repair_remaining: float = 0.0 # ticks remaining in repair
var maintenance_due_day: int = 0
var breakdowns_today: int = 0
var units_produced_today: float = 0.0
var stoppage_ticks_today: float = 0.0

var rng: RandomNumberGenerator

func _init(d: MachineData, r: RandomNumberGenerator = null) -> void:
	data = d
	rng = r if r != null else RandomNumberGenerator.new()

func reset_day() -> void:
	input_buffer = 0.0
	output_buffer = 0.0
	cycle_progress = 0.0
	breakdowns_today = 0
	units_produced_today = 0.0
	stoppage_ticks_today = 0.0
	if state == State.BREAKDOWN or state == State.REPAIRING:
		state = State.IDLE

# Advance one tick. temp_in_window: delivered temperature within tolerance.
# Returns units produced this tick (0 or fractional per throughput).
func tick(temp_in_window: bool) -> float:
	if state == State.REPAIRING:
		repair_remaining -= 1.0
		if repair_remaining <= 0.0:
			state = State.IDLE
		stoppage_ticks_today += 1.0
		return 0.0

	if state == State.MAINTENANCE:
		stoppage_ticks_today += 1.0
		return 0.0

	# Can we start/continue a cycle?
	if input_buffer >= 1.0 and output_buffer < float(data.output_buffer_units) and temp_in_window:
		state = State.RUNNING
		cycle_progress += 1.0
		var cycle_ticks: float = data.cycle_time_sec / 60.0  # seconds -> minutes (ticks)
		if cycle_ticks <= 0.0:
			cycle_ticks = 1.0
		if cycle_progress >= cycle_ticks:
			# cycle complete: consume 1 input unit, emit output
			input_buffer -= 1.0
			var out_units: float = 1.0
			output_buffer = minf(output_buffer + out_units, float(data.output_buffer_units))
			units_produced_today += out_units
			cycle_progress = 0.0
			return out_units
		return 0.0
	else:
		# idle (starved or blocked or temp out of window)
		if state == State.RUNNING:
			cycle_progress = 0.0
		state = State.IDLE
		stoppage_ticks_today += 1.0
		return 0.0

# Enter breakdown (called by simulation when the daily roll triggers it).
func enter_breakdown() -> void:
	state = State.BREAKDOWN
	repair_remaining = data.repair_time_min  # minutes = ticks
	breakdowns_today += 1

func finish_breakdown() -> void:
	if state == State.BREAKDOWN:
		state = State.REPAIRING

func begin_maintenance() -> void:
	state = State.MAINTENANCE

func end_maintenance() -> void:
	if state == State.MAINTENANCE:
		state = State.IDLE

func is_operational() -> bool:
	return state == State.IDLE or state == State.RUNNING
