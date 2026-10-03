extends Node
## Autoload: run-level state shared across scenes (difficulty, seed, active sim).

var active_difficulty: EconomyData.Difficulty = EconomyData.Difficulty.NORMAL
var active_seed: int = 0
var simulation: Simulation = null

func new_run(diff: EconomyData.Difficulty, seed: int) -> Simulation:
	active_difficulty = diff
	active_seed = seed
	simulation = Simulation.new(BalanceDB.db, diff, seed)
	return simulation
