class_name ProductionLine
extends RefCounted
## An ordered machine chain (lookup_packs machine_chain). Models the end-to-end
## production flow: a source buffer feeds stage 1; each machine's output buffer
## feeds the next machine's input buffer; the last machine's output is finished
## goods. Bottlenecks emerge from buffer contention.

var machines: Array = []  # Array[MachineState], ordered stage 1..N
var source_buffer: float = 0.0
var finished_output: float = 0.0
var raw_consumed_today: float = 0.0  # raw material pulled into the line
var rng: RandomNumberGenerator
# M2: enable the real per-machine temperature model (default off so the
# regression baseline is preserved; the M2 slice / campaign opts in).
var temperature_model_enabled: bool = false
# M6: Factorio-style belt + inserter routing. Default off (legacy direct
# buffer flow, so the regression baseline is preserved). When enabled, flow
# routes through the belt network and belt capacity / inserter rate become
# real constraints.
var belt_network: BeltNetwork = null
var belt_enabled: bool = false

# M6: build + enable the default belt network for this chain.
func enable_belts(belt_capacity: float, belt_throughput: float,
		inserter_rate: float) -> void:
	belt_network = BeltNetwork.new()
	belt_network.build_default(machines.size(), belt_capacity,
		belt_throughput, inserter_rate)
	belt_enabled = true

func disable_belts() -> void:
	belt_enabled = false

func _init(r: RandomNumberGenerator = null) -> void:
	rng = r if r != null else RandomNumberGenerator.new()

func add_machine(d: MachineData) -> void:
	var m := MachineState.new(d, rng)
	m.temperature_model_enabled = temperature_model_enabled
	machines.append(m)

func reset_day() -> void:
	source_buffer = 0.0
	finished_output = 0.0
	raw_consumed_today = 0.0
	if belt_network != null:
		belt_network.reset_day()
	for m in machines:
		m.reset_day()

# Advance one tick. Returns units of finished goods produced this tick.
func tick(temp_in_window: bool) -> float:
	# M6: belt + inserter routing (when enabled). Flow goes through the belt
	# network: raw material loads onto belt 0, input inserters feed each
	# machine, machines run (input -> output), output inserters push onto the
	# next belt, and the finished-goods belt holds the result. Belt capacity
	# + inserter rate are real constraints (a slow belt blocks upstream and
	# starves downstream).
	if belt_enabled and belt_network != null:
		# draw raw material from the source reservoir onto belt 0 (up to the
		# belt's remaining capacity) — the reservoir is the day's raw supply,
		# so a slow raw belt starves the line (a real constraint).
		var raw_space: float = belt_network.belts[0].capacity \
			- belt_network.belts[0].held if belt_network.belts.size() > 0 else 0.0
		var drawn: float = minf(source_buffer, raw_space)
		belt_network.belts[0].held += drawn
		source_buffer -= drawn
		belt_network.feed_inputs(machines)
		for m in machines:
			m.tick(temp_in_window)
		belt_network.collect_outputs(machines)
		raw_consumed_today = machines[0].units_consumed_today if machines.size() > 0 else 0.0
		finished_output += belt_network.finished_held()
		belt_network.reset_finished()
		return 0.0
	# Legacy direct buffer flow (default; preserves the regression baseline).
	# Pass 1: flow upstream to downstream — feed each machine's input from the
	# previous machine's output buffer (or the source buffer for stage 1).
	for i in range(machines.size()):
		var m: MachineState = machines[i]
		var available: float = 0.0
		if i == 0:
			available = source_buffer
		else:
			available = machines[i - 1].output_buffer
		var space: float = float(m.data.input_buffer_units) - m.input_buffer
		var moved: float = minf(available, maxf(space, 0.0))
		m.input_buffer += moved
		if i == 0:
			source_buffer -= moved
		else:
			machines[i - 1].output_buffer -= moved
	# Pass 2: run each machine (order: stage 1 -> N, so a machine's fresh
	# output is available to the next stage within the same tick).
	for m in machines:
		m.tick(temp_in_window)
	# raw material consumed = stage 1's daily consumption total (assign, not +=)
	if machines.size() > 0:
		raw_consumed_today = machines[0].units_consumed_today
	# last machine's output becomes finished goods
	if machines.size() > 0:
		var last: MachineState = machines[machines.size() - 1]
		finished_output += last.output_buffer
		last.output_buffer = 0.0
	return 0.0

# Convenience: total units produced across the line today.
func total_units_today() -> float:
	var t := 0.0
	for m in machines:
		t += m.units_produced_today
	return t

func total_stoppages_today() -> float:
	var t := 0.0
	for m in machines:
		t += m.stoppage_ticks_today
	return t

func any_breakdown_today() -> bool:
	for m in machines:
		if m.breakdowns_today > 0:
			return true
	return false

# M2: bottleneck detection. Returns the machine that is the constraint:
# the lowest-throughput machine (the line's natural bottleneck), plus the
# machine that is most starved (upstream constraint) and most blocked
# (downstream constraint). Useful for UX ("your wrapper is the bottleneck").
func bottleneck_report() -> Dictionary:
	var lowest: String = ""
	var lowest_rate: float = INF
	var most_starved: String = ""
	var most_blocked: String = ""
	var max_starved: float = 0.0
	var max_blocked: float = 0.0
	for m in machines:
		if m.data.throughput_units_per_min < lowest_rate:
			lowest_rate = m.data.throughput_units_per_min
			lowest = m.data.machine_id
		if m.starved_ticks_today > max_starved:
			max_starved = m.starved_ticks_today
			most_starved = m.data.machine_id
		if m.blocked_ticks_today > max_blocked:
			max_blocked = m.blocked_ticks_today
			most_blocked = m.data.machine_id
	return {
		"lowest_throughput": lowest,
		"lowest_rate": lowest_rate if is_finite(lowest_rate) else 0.0,
		"most_starved": most_starved,
		"most_starved_ticks": max_starved,
		"most_blocked": most_blocked,
		"most_blocked_ticks": max_blocked,
	}
