class_name Diagnostics
extends RefCounted
## M5: UX clarity for bottlenecks + quality (GDD §14 milestone 5).
## Turns the raw per-machine counters (starved / blocked / breakdown /
## stoppage / throughput) into a player-readable report:
##   - per-machine classification (bottleneck / starved / blocked / healthy)
##   - the line's natural bottleneck (lowest throughput)
##   - a plain-English summary the UI can render directly
##
## This is the data layer behind the on-screen bottleneck/quality HUD; the
## visual panel is deferred for play-test, but the classification + summary
## is fully headless-testable.

# Per-machine status codes.
enum Status { HEALTHY, BOTTLENECK, STARVED, BLOCKED, BREAKING }

# Classify a single machine from its today-counters.
# Priority: breaking > starved > blocked > healthy (bottleneck set separately).
static func classify(m: MachineState) -> int:
	if m.repair_remaining > 0.0 or m.breakdowns_today >= 2:
		return Status.BREAKING
	if m.starved_ticks_today > 0.0:
		return Status.STARVED
	if m.blocked_ticks_today > 0.0:
		return Status.BLOCKED
	return Status.HEALTHY

# Build the full line report: per-machine status + the natural bottleneck
# (lowest throughput) + a plain-English summary.
static func line_report(line: ProductionLine) -> Dictionary:
	var per_machine: Dictionary = {}
	var lowest_rate: float = INF
	var bottleneck_id: String = ""
	for m in line.machines:
		per_machine[m.data.machine_id] = classify(m)
		if m.data.throughput_units_per_min < lowest_rate:
			lowest_rate = m.data.throughput_units_per_min
			bottleneck_id = m.data.machine_id
	# the lowest-throughput machine is the line's natural bottleneck
	if bottleneck_id != "":
		per_machine[bottleneck_id] = Status.BOTTLENECK
	return {
		"per_machine": per_machine,
		"bottleneck": bottleneck_id,
		"bottleneck_rate": lowest_rate,
		"summary": _summary(line, per_machine, bottleneck_id),
	}

static func _summary(line: ProductionLine, per_machine: Dictionary,
		bottleneck_id: String) -> String:
	var parts: Array = []
	for m in line.machines:
		var st: int = per_machine[m.data.machine_id]
		match st:
			Status.BOTTLENECK:
				parts.append("%s is the bottleneck (%.1f/min) — everything else waits on it" % [m.data.machine_id, m.data.throughput_units_per_min])
			Status.STARVED:
				parts.append("%s is starved (no input reaching it)" % m.data.machine_id)
			Status.BLOCKED:
				parts.append("%s is blocked (output buffer full)" % m.data.machine_id)
			Status.BREAKING:
				parts.append("%s is breaking down (needs repair)" % m.data.machine_id)
	if parts.is_empty():
		return "line running clean — no bottleneck, starvation, or blockage"
	return " | ".join(parts)

# Quality clarity: turn the quality components into a plain-English readout
# naming the weakest component (the one dragging Q down).
static func quality_summary(comps: Dictionary) -> String:
	var weakest_key: String = ""
	var weakest: float = INF
	for k in comps.keys():
		if k == "Q":
			continue
		var v: float = comps[k]
		if v < weakest:
			weakest = v
			weakest_key = k
	return "Q=%.1f — weakest component: %s (%.1f)" % [comps.Q, weakest_key, weakest]
