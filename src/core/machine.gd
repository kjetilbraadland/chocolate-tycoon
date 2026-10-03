class_name MachineState
extends RefCounted
## Per-machine runtime state machine (GDD §7.1 / technical design §4.2).
## IDLE -> RUNNING -> (breakdown) -> REPAIRING -> IDLE, with maintenance.
## A machine produces only when input >= 1 and output buffer has space.
##
## Throughput model (M1 fix): the CSV `throughput_units_per_min` is the
## authoritative per-tick rate (1 tick = 1 in-game minute). A running machine
## consumes input and emits output proportionally at that rate, so production
## is coupled to runtime — which is what makes per-machine energy/wage costs
## meaningful (a machine only "costs" when it actually runs).

enum State { IDLE, RUNNING, BREAKDOWN, REPAIRING, MAINTENANCE }

var data: MachineData
var state: State = State.IDLE
var input_buffer: float = 0.0
var output_buffer: float = 0.0
var repair_remaining: float = 0.0 # ticks remaining in repair
var maintenance_due_day: int = 0
var breakdowns_today: int = 0
var units_produced_today: float = 0.0
var stoppage_ticks_today: float = 0.0
var run_ticks_today: float = 0.0 # ticks actually running (for energy cost)
var units_consumed_today: float = 0.0

var rng: RandomNumberGenerator

func _init(d: MachineData, r: RandomNumberGenerator = null) -> void:
	data = d
	rng = r if r != null else RandomNumberGenerator.new()

func reset_day() -> void:
	input_buffer = 0.0
	output_buffer = 0.0
	repair_remaining = 0.0
	breakdowns_today = 0
	units_produced_today = 0.0
	stoppage_ticks_today = 0.0
	run_ticks_today = 0.0
	units_consumed_today = 0.0
	if state == State.BREAKDOWN or state == State.REPAIRING:
		state = State.IDLE

# Per-tick production rate (1 tick = 1 minute).
func rate_per_tick() -> float:
	return data.throughput_units_per_min

# Advance one tick. temp_in_window: delivered temperature within tolerance.
# Returns units produced this tick.
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

	var rate: float = rate_per_tick()
	# Can we run? Need input, output space, temp in window.
	if input_buffer >= 1.0 and output_buffer < float(data.output_buffer_units) and temp_in_window and rate > 0.0:
		state = State.RUNNING
		run_ticks_today += 1.0
		# proportional consumption/production, bounded by available input and
		# output buffer space
		var can_make: float = minf(rate, input_buffer)
		var out_space: float = float(data.output_buffer_units) - output_buffer
		can_make = minf(can_make, out_space)
		if can_make > 0.0:
			input_buffer -= can_make
			output_buffer += can_make
			units_produced_today += can_make
			units_consumed_today += can_make
		return can_make
	else:
		# idle (starved, blocked, or temp out of window)
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
