# Balancing Recommendations (Pass 1)

Source data used:
- Scenario rollups from scenario_summary_template.csv
- Balance goals from GAME_DESIGN_DOCUMENT.md section 19

## Current Snapshot

### Baseline Normal 14-day
- Avg daily profit: 165.86
- Avg contract fulfillment: 92.71%
- Avg quality Q: 74.14 (mostly B)
- Avg debt delta: -10.79 per day
- Negative-profit days: 0 of 14

Assessment:
- Normal appears stable and forgiving.
- Contract pressure exists but not punishing.
- Quality profile aligns with B-grade mid-game target.

### Hard Stress 14-day
- Avg daily profit: 19.93
- Avg contract fulfillment: 84.71%
- Avg quality Q: 69.21 (split between B and C)
- Avg debt delta: +23.29 per day
- Negative-profit days: 6 of 14

Assessment:
- Hard mode pressure is present, but debt growth is likely too steep for a fair challenge curve.
- Penalty load is high enough to dominate recovery windows.
- Quality drift into C contributes to contract failures and returns.

## Gap-to-Target Analysis
1. Normal mode is on target.
2. Hard mode risk of snowball failure may exceed intended 40% to 50% failure target.
3. Contract misses every day in both scenarios indicate early target volumes may be slightly too aggressive for current throughput assumptions.

## Priority Tuning Plan

## P1 - Reduce Hard Debt Snowball Without Softening Pressure
Goal:
- Keep Hard difficult, but increase chance of late-run recovery.

Knobs to adjust:
1. economy_balance_template.csv
- ECO_CONTRACT_PENALTY_RATE
  - hard_value: 0.25 -> 0.22
2. economy_balance_template.csv
- ECO_DEBT_LIMIT
  - hard_value: 90000 -> 98000
3. economy_balance_template.csv
- ECO_BANKRUPTCY_GRACE_DAYS
  - hard_value: 2 -> 3

Expected impact:
- Lower debt acceleration after bad days.
- More opportunities to recover after one logistics shock.
- Hard remains punishing due to high costs and quality pressure.

## P2 - Improve Early Hard Fulfillment Reliability
Goal:
- Move hard fulfillment closer to 87% to 90% while maintaining challenge.

Knobs to adjust:
1. lookup_packs_template.csv (CONTRACT_C)
- target_units weekly: 150 -> 140
2. economy_balance_template.csv
- ECO_TRUCK_SLOT_COUNT
  - hard_value: 5 -> 6

Expected impact:
- Fewer automatic misses from dispatch constraints.
- Penalties better reflect planning errors instead of systemic under-capacity.

## P3 - Pull Hard Quality from C/B Split Toward Mostly B
Goal:
- Raise hard average quality from 69.21 to 71 to 73.

Knobs to adjust:
1. economy_balance_template.csv
- ECO_WAGE_QUALITY_MULT
  - hard_value: 0.10 -> 0.11
2. machines_balance_template.csv
- Tempering and conching precision support:
  - MCH_TEMPER_01 temp_tolerance_c: 2 -> 2.5
  - MCH_CONCHE_01 breakdown_chance_pct_day: 2.2 -> 2.0

Expected impact:
- Slightly more stable quality outcomes with the same routing complexity.
- Better contract compliance from fewer low-grade days.

## P4 - Keep Normal from Becoming Too Easy (Optional)
Goal:
- Preserve player agency and challenge in Normal without harming onboarding.

Optional changes:
1. economy_balance_template.csv
- ECO_ENERGY_PRICE normal_value: 0.22 -> 0.23
2. economy_balance_template.csv
- ECO_STORAGE_SPOIL_RATE normal_value: 0.004 -> 0.0045

Expected impact:
- Small strategic pressure on layout efficiency and inventory discipline.

## P5 - Harder Hard (tighten hard mode)

Context: after the per-hour cost model + demand cap + P2/P3, hard mode is too
easy (live re-validation: avg profit 201, 0 negative-profit days). This pass
tightens the HARD-mode economy knobs (hard_value column only; Normal untouched)
to push hard back into the target band (profit -10..+40, 4-7 negative days,
Q >= 71) while keeping the mechanics identical.

Proposed changes (all within min/max bounds):
1. ECO_START_CASH hard: 45000 -> 32000 (min 20000) — tighter runway
2. ECO_DEBT_LIMIT hard: 98000 -> 82000 (min 50000) — earlier bankruptcy trigger
3. ECO_BASE_LOAN_RATE hard: 0.06 -> 0.08 (max 0.12) — faster debt compounding
4. ECO_WAGE_BASE hard: 165 -> 210 (max 260) — labor pressure (largest cost lever)
5. ECO_ENERGY_PRICE hard: 0.28 -> 0.42 (max 0.60) — utility pressure
6. ECO_STORAGE_SPOIL_RATE hard: 0.007 -> 0.012 (max 0.03) — inventory discipline
7. ECO_SHOP_FOOTFALL_BASE hard: 0.9 -> 0.80 (min 0.5) — lower demand base
8. ECO_TRUCK_SLOT_COUNT hard: 6 -> 5 (min 2) — dispatch bottleneck (reverts P2 for hard only)
9. ECO_CONTRACT_REPUTATION_HIT hard: 9 -> 14 (max 20) — steeper reputation penalty

Rationale:
- Wages are the dominant per-hour cost (operator-hours x wage_base/24); raising
  wage_base is the single largest lever on hard profit.
- Energy + spoil raise the per-unit cost floor.
- Lower start cash + lower debt limit + higher loan rate + steeper rep hit
  convert bad days into debt growth / bankruptcy risk, which is what produces
  the 4-7 negative days the target band wants.
- Footfall base down shrinks the demand cap, cutting both revenue and cost but
  netting lower (margins are positive, so less volume = less profit).
- Truck slots back to 5 reintroduces the dispatch bottleneck on hard only.

## Pass 5 Results (Applied — measured)

Applied (hard_value column only; Normal untouched). Final hard values:
- ECO_START_CASH hard: 45000 -> 20000 (min)
- ECO_DEBT_LIMIT hard: 98000 -> 60000
- ECO_BASE_LOAN_RATE hard: 0.06 -> 0.10
- ECO_WAGE_BASE hard: 165 -> 260 (max)
- ECO_ENERGY_PRICE hard: 0.28 -> 0.55
- ECO_STORAGE_SPOIL_RATE hard: 0.007 -> 0.02
- ECO_TRUCK_SLOT_COUNT hard: 6 -> 4
- ECO_SHOP_FOOTFALL_BASE hard: 0.9 -> 0.65
- ECO_CONTRACT_REPUTATION_HIT hard: 9 -> 14

Live re-validation (per-hour model, HARD_STRESS_14D):
- avg profit: 201.14 (pre-P5) -> 121.84 (P5)
- avg revenue: 465.56 -> 335.43 (footfall base down)
- avg cost: 264.41 -> 213.60
- fulfillment: 94.49% -> 79.31%
- avg Q: 71.62 -> 73.63 (still B-band, P3 target met)
- neg-profit days: 0 -> 0

Structural finding (why hard cannot reach the old-model band via economy knobs):
- The per-hour model decouples costs from volume: machines only cost the hours
  they actually run. Lowering demand (footfall) shrinks runtime, which shrinks
  opex/wage/energy proportionally. So tightening cost knobs has diminishing
  returns — the line simply runs less.
- The per-unit margin is the real floor: revenue/unit (price x sold) vs
  cost/unit (input + proportional opex/wage/energy). With production capped at
  demand and the line running only the hours it needs, the cost floor is low,
  so every day stays profitable (0 neg days).
- All hard economy knobs are now at/near their min/max bounds; there is no
  further headroom in this CSV to push hard into -10..+40.

The real levers to make hard actually bite (candidate P6 — needs a decision):
1. Raise the per-unit cost floor: input_cost_multiplier / base_unit_cost up
   (the dominant cost component, currently ~1.0x in the hard-stress rows).
2. Add a fixed daily opex floor (a base charge even when machines are idle),
   re-coupling costs to the calendar rather than pure runtime.
3. Accept "hard = challenging but profitable" (current P5 state) rather than
   "hard = breakeven" — i.e. treat the per-hour model's profitability as the
   new baseline and re-anchor the target band to it.

## Pass 6 Results (Applied — user: "a little harder, not impossible")

Decision: lever #1 (modest hard-only per-unit cost increase) + lever #3
(re-anchor the target band to the per-hour model's profitability). No fixed
opex floor (would distort the runtime-coupled cost structure the user asked for).

Change:
- New knob ECO_INPUT_COST_MULT (normal 1.0, hard 1.3, bounds 0.5..2.0) —
  scales raw material cost per difficulty. Wired into Campaign.close_day().
- Hard 1.3x input cost raises the per-unit cost floor directly.

Live re-validation (per-hour model):
- Hard avg profit: 121.84 (P5) -> 74.23 (P6)
- Hard revenue 335.43, cost 261.20, fulfillment 79.31%, Q 73.63 (B-band)
- Hard neg-profit days: 0
- Normal unchanged: 246.09 (lever is hard-only)

Result: hard is now a meaningful step below normal (74 vs 246, ~30% of
normal's profit) but clearly profitable — "a little harder, not impossible."

Re-anchored target band (per-hour model; replaces the obsolete old-model
-10..+40 / 4-7 neg days band):
- Hard: avg profit in [40, 120] (clearly below normal, still profitable),
  neg-profit days in [0, 3] (a few rough days, not constant losses), Q >= 71.
- Normal: avg profit > 120, fulfillment > 90%, Q B-band (unchanged).

## Validation Plan (Next Pass)
Run these three scenarios after P1 to P3 only:
1. BASELINE_NORMAL_14D (unchanged baseline check)
2. HARD_STRESS_14D (same stress script)
3. HARD_STRESS_14D_VARIANT_B (same rows, +5% random footfall volatility)

Pass criteria:
- Normal:
  - Avg daily profit remains above 120
  - Avg fulfillment remains above 90%
  - Avg quality remains B-band
- Hard:
  - Avg daily profit between -10 and +40
  - Avg debt delta between -5 and +10
  - Negative-profit days at 4 to 7 out of 14
  - Avg quality Q at least 71

## Quick Recommendation Order
1. Apply P1 only and rerun.
2. Apply P2 and rerun.
3. Apply P3 and rerun.
4. Consider P4 only if Normal continues to overperform.

This sequence isolates cause and effect so you can tune with confidence.

## Pass 1 Results (Applied)

Applied knobs:
- ECO_CONTRACT_PENALTY_RATE hard: 0.25 -> 0.22
- ECO_DEBT_LIMIT hard: 90000 -> 98000
- ECO_BANKRUPTCY_GRACE_DAYS hard: 2 -> 3
- CONTRACT_C penalty_rate synced to 0.22

Observed outcome on HARD_STRESS_14D:
- Avg daily profit: 19.93 -> 24.65
- Avg penalty cost: 39.36 -> 34.63
- Avg debt delta: 23.29 -> 18.56
- Negative-profit days: 6 -> 5

Interpretation:
- Direction is correct, but Hard mode still trends into debt growth too often.
- Next highest-leverage move is P2 (reduce contract target pressure and ease dispatch bottleneck).

## Pass 2 Results (Applied)

Applied knobs (P2 + P3; P1 already applied in Pass 1):
- P2: ECO_TRUCK_SLOT_COUNT hard: 5 -> 6
- P2: CONTRACT_C target_units weekly: 150 -> 140
- P3: ECO_WAGE_QUALITY_MULT hard: 0.10 -> 0.11
- P3: MCH_TEMPER_01 temp_tolerance_c: 2 -> 2.5
- P3: MCH_CONCHE_01 breakdown_chance_pct_day: 2.2 -> 2.0

Companion mechanic change (M1 pass 2):
- Cost model moved from flat per-day to per-HOUR, charged on actual machine
  runtime (run_ticks). Idle machines cost nothing; opex + wages + energy are
  all proportional to active hours. This was the root cause of the starter
  run being deeply unprofitable under the old flat model.

Observed outcome (live Campaign, 14-day, milk bar, CHAIN_A):
- Normal: profit -24,689 -> +1,999 (now profitable)
- Hard: profit -27,183 -> +1,938 (now profitable)
- 53 headless tests pass; BASELINE_NORMAL_14D rollup still reproduces the
  sheet exactly (delta 0.00).

Interpretation:
- The per-hour cost model + P2/P3 bring the starter run to a sane,
  roughly-breakeven-to-profitable state. Both difficulty modes are now
  positive over 14 days, which is the intended Normal target.
- Hard mode is still close to breakeven; if it should be tighter, the next
  lever is P4 (energy price / spoil rate) or a lower Hard start cash.
- The master sim sheet (HARD_STRESS_14D) still reflects pre-P3 values
  (avg_Q 69.21); re-run the sheet after Pass 2 to refresh expected_* columns.
