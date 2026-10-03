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
