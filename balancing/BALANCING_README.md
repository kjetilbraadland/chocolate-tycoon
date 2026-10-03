# Balancing Sheets

Use these CSV templates to tune the first playable build.

## Files
- `recipes_balance_template.csv`: Product-level recipe, quality, demand, and margin inputs.
- `machines_balance_template.csv`: Machine throughput, power, quality influence, and maintenance data.
- `economy_balance_template.csv`: Global economy knobs for normal and hard mode.
- `master_simulation_template.csv`: Single-row simulation scenarios with expected outputs for quick balance passes.
- `lookup_packs_template.csv`: Reusable packs for machine chains, contracts, and scenario metadata.
- `scenario_summary_template.csv`: Prefilled aggregate metrics for scenario-level Normal vs Hard comparison.
- `BALANCING_RECOMMENDATIONS.md`: Prioritized knob changes based on current scenario deltas.

## Recommended Workflow
1. Tune machine throughput first until one full line is stable.
2. Tune recipe costs/prices so starter products are profitable but tight.
3. Tune economy pressure (energy, wages, penalties, debt limit).
4. Run 3 simulation passes:
   - New player baseline
   - Optimized factory baseline
   - Hard mode stress test

## Master Simulation Sheet Workflow
1. In `lookup_packs_template.csv`, define reusable machine chains and contract packs.
2. In `master_simulation_template.csv`, create one row per simulated day or test case.
3. Point each row to:
  - `recipe_id` from `recipes_balance_template.csv`
  - `machine_chain_id` from `lookup_packs_template.csv`
  - `contract_pack_id` from `lookup_packs_template.csv`
4. Set multipliers (price, wages, energy, delays, breakdowns) to test edge cases.
5. Fill `expected_*` columns from your balancing model output and compare against targets.

Suggested scenario set:
- Baseline normal 14-day run
- Optimized normal 14-day run
- Hard stress 14-day run
- R&D jackpot variance run

Prefilled scenarios included now:
- `BASELINE_NORMAL_14D` in `master_simulation_template.csv` (rows `SIM_101` to `SIM_114`)
- `HARD_STRESS_14D` in `master_simulation_template.csv` (rows `SIM_201` to `SIM_214`)
- Scenario rollups in `scenario_summary_template.csv` (rows `SUM_001` and `SUM_002`)

## Quick Scenario Comparison
Use `scenario_summary_template.csv` to compare:
- Average profitability per day
- Average fulfillment and penalty pressure
- Quality grade mix and returns rate
- Debt direction (decreasing or increasing)

Interpretation tips:
- If Hard mode has positive average profit but rising debt, penalties or cashflow timing are likely too punishing.
- If grade C days exceed grade B days on Normal, reduce process pressure or increase starter tolerance.
- If contract miss days are always high in both scenarios, reduce contract targets or improve early throughput.

## First-Pass Target Ranges
- Starter gross margin per unit: 25% to 40%.
- Contract penalty events in healthy play: less than 1 per in-game week.
- Mid-game average quality grade: B.
- Bankruptcy rate (new players):
  - Normal: around 30% fail
  - Hard: around 50% to 60% fail

## Notes
- Keep one source of truth: do not duplicate values across files without a clear reason.
- Lock formulas in the GDD and tune coefficients in these CSVs.
