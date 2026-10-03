class_name ProductionLine
extends RefCounted
## An ordered machine chain (lookup_packs machine_chain). Models the end-to-end
## production flow: a source buffer feeds stage 1; each machine's output buffer
## feeds the next machine's input buffer; the last machine's output is finished
## goods. Bottlenecks emerge from buffer contention.

var machines: Array = []  # Array[MachineState], ordered stage 1..N
var source_buffer: float = 0.0
var finished_output: float = 0.0
var rng: RandomNumberGenerator

func _init(r: RandomNumberGenerator = null) -> void:
	rng = r if r != null else RandomNumberGenerator.new()

func add_machine(d: MachineData) -> void:
	machines.append(MachineState.new(d, rng))

func reset_day() -> void:
	source_buffer = 0.0
	finished_output = 0.0
	for m in machines:
		m.reset_day()

# Advance one tick. Returns units of finished goods produced this tick.
func tick(temp_in_window: bool) -> float:
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
