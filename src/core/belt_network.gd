class_name BeltNetwork
extends RefCounted
## M6: Factorio-style belt + inserter routing. Belts carry raw material and
## semi-finished products; inserters feed machines. When enabled, the
## ProductionLine routes flow through this network, so belt capacity +
## inserter rate become real constraints (a slow belt blocks upstream and
## starves downstream). When disabled (the default), the line uses the legacy
## direct buffer flow, so the regression baseline is preserved.
##
## Flow per tick (when enabled):
##   1. load_source(amount)  — raw material onto belt 0
##   2. feed_inputs(machines) — input inserters pull belt i -> machine i input
##   3. (ProductionLine runs each machine: input -> output)
##   4. collect_outputs(machines) — output inserters push machine i output -> belt i+1
##   5. finished_held() = belt N (the finished-goods belt)
##
## Belts have a one-tick pipeline latency (items sit on the belt a tick before
## the next inserter pulls them) — that is the Factorio feel, and it is the
## intended difference from the legacy same-tick flow.

class Belt:
	var id: int
	var kind: String  # "raw" / "semi" / "finished"
	var capacity: float  # max units held on the belt
	var throughput: float  # max units the belt can move per tick
	var held: float = 0.0

class Inserter:
	var belt_id: int
	var machine_index: int
	var is_input: bool  # true: belt -> machine input; false: machine output -> belt
	var rate: float  # max units the inserter moves per tick

var belts: Array = []  # Array[Belt]
var inserters: Array = []  # Array[Inserter]
var enabled: bool = false

# Build the default belt network for a chain of N machines:
#   belt 0 (raw) --inserter--> machine 0
#   machine i --inserter--> belt (i+1) --inserter--> machine (i+1)
#   belt N = finished goods
# belt_capacity / belt_throughput / inserter_rate are the raw + semi belt
# specs. The finished-goods belt gets a large capacity (it must hold the
# whole day's output without blocking the line).
func build_default(machine_count: int, belt_capacity: float,
		belt_throughput: float, inserter_rate: float) -> void:
	belts.clear()
	inserters.clear()
	belts.append(_make_belt(0, "raw", belt_capacity, belt_throughput))
	for i in range(machine_count):
		# input inserter: belt i -> machine i input
		inserters.append(_make_inserter(i, i, true, inserter_rate))
		# output inserter: machine i output -> belt (i+1)
		var out_belt: int = i + 1
		if out_belt >= belts.size():
			var is_finished: bool = out_belt == machine_count
			var kind: String = "finished" if is_finished else "semi"
			var cap: float = 100000.0 if is_finished else belt_capacity
			var thr: float = 100000.0 if is_finished else belt_throughput
			belts.append(_make_belt(out_belt, kind, cap, thr))
		inserters.append(_make_inserter(out_belt, i, false, inserter_rate))
	enabled = true

func _make_belt(id: int, kind: String, cap: float, thr: float) -> Belt:
	var b := Belt.new()
	b.id = id
	b.kind = kind
	b.capacity = cap
	b.throughput = thr
	b.held = 0.0
	return b

func _make_inserter(belt_id: int, machine_index: int,
		is_input: bool, rate: float) -> Inserter:
	var ins := Inserter.new()
	ins.belt_id = belt_id
	ins.machine_index = machine_index
	ins.is_input = is_input
	ins.rate = rate
	return ins

# Load raw material onto belt 0 (capped at the belt's capacity).
func load_source(amount: float) -> void:
	if belts.size() == 0:
		return
	belts[0].held = minf(belts[0].held + amount, belts[0].capacity)

# Input inserters: pull from belt i into machine i's input buffer, bounded by
# the inserter rate, the belt's held, the belt throughput, and the machine's
# input buffer space.
func feed_inputs(machines: Array) -> void:
	if not enabled:
		return
	for ins in inserters:
		if not ins.is_input:
			continue
		var m: MachineState = machines[ins.machine_index]
		var b: Belt = belts[ins.belt_id]
		var space: float = float(m.data.input_buffer_units) - m.input_buffer
		var movable: float = minf(ins.rate, minf(b.held, b.throughput))
		var moved: float = minf(movable, maxf(space, 0.0))
		m.input_buffer += moved
		b.held -= moved

# Output inserters: push from machine i's output buffer onto belt (i+1),
# bounded by the inserter rate, the machine's output buffer, the belt's
# remaining capacity, and the belt throughput.
func collect_outputs(machines: Array) -> void:
	if not enabled:
		return
	for ins in inserters:
		if ins.is_input:
			continue
		var m: MachineState = machines[ins.machine_index]
		var b: Belt = belts[ins.belt_id]
		var space: float = b.capacity - b.held
		var movable: float = minf(ins.rate, minf(m.output_buffer, b.throughput))
		var moved: float = minf(movable, maxf(space, 0.0))
		m.output_buffer -= moved
		b.held += moved

# The finished-goods belt's held units (belt N).
func finished_held() -> float:
	if belts.size() == 0:
		return 0.0
	return belts[belts.size() - 1].held

# Clear the finished-goods belt after it is collected as finished goods.
func reset_finished() -> void:
	if belts.size() > 0:
		belts[belts.size() - 1].held = 0.0

# Reset all belts to empty (start of a new day).
func reset_day() -> void:
	for b in belts:
		b.held = 0.0

# Diagnostic: the belt that is the constraint (most full relative to capacity).
func bottleneck_belt() -> Dictionary:
	var worst: int = -1
	var worst_ratio: float = 0.0
	for b in belts:
		if b.capacity > 0.0:
			var ratio: float = b.held / b.capacity
			if ratio > worst_ratio:
				worst_ratio = ratio
				worst = b.id
	return { "belt_id": worst, "ratio": worst_ratio }
