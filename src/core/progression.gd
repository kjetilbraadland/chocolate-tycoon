class_name Progression
extends RefCounted
## M4: gradual unlock tree (GDD §6 — "a gradual unlock tree, not hard chapters").
## Two axes:
##   - Supply-chain expansion (stages 1..5): buy ingredients -> in-house sugar
##     -> in-house cocoa -> specialty inputs -> light farming modules.
##   - Tech branches (machinery, recipes, farming, logistics, branding).
##
## `current_stage` is the highest supply-stage index the player has reached
## (start = 0, i.e. only stage 1 "raw purchase" is active). A stage is
## unlockable when it is the next one (current_stage + 1), the player has
## enough cash, and enough days have passed (gradual pacing). Unlocks are
## idempotent.

# Supply-chain expansion stages (GDD §6.1).
enum SupplyStage {
	RAW_PURCHASE,      # Stage 1: buy pre-fabricated ingredients
	INHOUSE_SUGAR,     # Stage 2: produce sugar in-house
	INHOUSE_COCOA,     # Stage 3: produce cocoa in-house
	SPECIALTY_INPUTS,  # Stage 4: milk powder, flavorings, nuts, specialty
	FARMING_MODULES,   # Stage 5: light farming modules (cocoa + sugar)
}

# Tech branches (GDD §6.2).
enum TechBranch { MACHINERY, RECIPES, FARMING, LOGISTICS, BRANDING }

# Per-stage unlock cost + minimum day, indexed by stage (1..5) -> [stage-1].
const STAGE_COST := [0.0, 8000.0, 15000.0, 25000.0, 40000.0]
const STAGE_MIN_DAY := [0, 3, 7, 14, 21]

# Tech-branch unlock cost + minimum day (indexed by TechBranch).
const BRANCH_COST := [6000.0, 4000.0, 12000.0, 9000.0, 7000.0]
const BRANCH_MIN_DAY := [5, 2, 10, 4, 3]

var current_stage: int = 1  # highest supply-stage NUMBER reached (start = stage 1)
var unlocked_branches: Array = [false, false, false, false, false]

# --- Supply-chain expansion ---
# Is supply stage `stage` (1..5) available (already reached, or the next one)?
func stage_available(stage: int) -> bool:
	if stage < 1 or stage > 5:
		return false
	if stage <= current_stage:
		return true
	return stage == current_stage + 1

# Can the player unlock stage `stage` right now (next + cost + min day)?
func can_unlock_stage(stage: int, cash: float, day: int) -> bool:
	if stage < 2 or stage > 5:
		return false
	if not stage_available(stage):
		return false
	return cash >= STAGE_COST[stage - 1] and day >= STAGE_MIN_DAY[stage - 1]

# Unlock stage `stage`. Returns true on success.
func unlock_stage(stage: int, cash: float, day: int) -> bool:
	if not can_unlock_stage(stage, cash, day):
		return false
	if stage > current_stage:
		current_stage = stage
	return true

# --- Tech branches ---
func branch_available(branch: int) -> bool:
	if branch < 0 or branch > 4:
		return false
	return unlocked_branches[branch]

func can_unlock_branch(branch: int, cash: float, day: int) -> bool:
	if branch < 0 or branch > 4:
		return false
	if unlocked_branches[branch]:
		return false
	return cash >= BRANCH_COST[branch] and day >= BRANCH_MIN_DAY[branch]

func unlock_branch(branch: int, cash: float, day: int) -> bool:
	if not can_unlock_branch(branch, cash, day):
		return false
	unlocked_branches[branch] = true
	return true

# --- Convenience: is in-house sugar/cocoa / farming available? ---
# (stage numbers: 1 raw, 2 sugar, 3 cocoa, 4 specialty, 5 farming)
func inhouse_sugar() -> bool:
	return current_stage >= 2

func inhouse_cocoa() -> bool:
	return current_stage >= 3

func farming_available() -> bool:
	return current_stage >= 5 \
		or unlocked_branches[int(TechBranch.FARMING)]

# Snapshot for the save system / UI.
func snapshot() -> Dictionary:
	return {
		"current_stage": current_stage,
		"unlocked_branches": unlocked_branches.duplicate(),
	}

func restore(data: Dictionary) -> void:
	if data.has("current_stage"):
		current_stage = int(data["current_stage"])
	if data.has("unlocked_branches"):
		for i in range(5):
			unlocked_branches[i] = bool((data["unlocked_branches"] as Array)[i])
