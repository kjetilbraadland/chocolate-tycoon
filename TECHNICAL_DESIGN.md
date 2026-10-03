# Technical Design — Chocolate Factory Tycoon

Engine: Godot 4.7.2, GDScript (typed). PC first.
Source of truth for all balance values: `balancing/*.csv` (one source of truth per `BALANCING_README.md` — game code never hardcodes balance numbers).

## 1. Architecture Overview

Three strict layers. The core simulation is pure GDScript with **no scene-tree dependency**, so it runs headless (for tests, balancing passes, and future AI/speed-up).

```
┌─────────────────────────────────────────────┐
│  Presentation Layer (game/, ui/)           │  scenes, isometric rendering,
│  Godot nodes, signals, input              │  camera, HUD, cozy visuals
├─────────────────────────────────────────────┤
│  Core Simulation Layer (src/core/)        │  pure GDScript, deterministic,
│  machines, routing, quality, economy,     │  fixed-timestep, no Node deps
│  contracts, shop, R&D, brand, bankruptcy  │  (RefCounted / Resource only)
├─────────────────────────────────────────────┤
│  Data Layer (src/core/data/)              │  CSV → typed Resources
│  loaders for balancing/*.csv              │  (single source of truth)
└─────────────────────────────────────────────┘
```

Rules:
- Presentation reads core state via polling + signals; it never mutates simulation state directly (all player actions go through core API calls, e.g. `sim.place_machine(...)`, `sim.set_wage_policy(...)`).
- Core is deterministic: seeded RNG (`RandomNumberGenerator` with a run seed stored in save files). Same seed + same inputs = same run.
- Core uses no `Node`, no `SceneTree`, no `await` on frames — so it can be driven in a headless test harness at any speed.

## 2. Time Model

- Fixed-timestep simulation: **1 tick = 1 in-game minute**.
- An in-game day = 24h = 1440 ticks. Player controls time: pause / 1x / 2x / 4x (multiplier = ticks processed per real frame, capped).
- Machines operate on `cycle_time_sec` from `machines_balance_template.csv` (in-game seconds = ticks/60... see below).
- **Unit of time in core = in-game minutes (ticks).** A machine with `cycle_time_sec = 30` needs 0.5 ticks per unit. Throughput `throughput_units_per_min` is the direct per-tick rate when the machine has input and its output buffer isn't full.
- Daily close (tick 1440) triggers the economy tick: wages, energy, opex, maintenance, spoilage, contract obligation checks, shop demand resolution, bankruptcy check, brand drift.
- Weekly close (every 7th day) triggers contract fulfillment settlement (volume, grade, truck slots, penalties, reputation).

## 3. Data Layer

At startup (or on save-load), `src/core/data/` parses the balancing CSVs into typed Resources:

| CSV | Resource type | Consumed by |
|---|---|---|
| `recipes_balance_template.csv` | `RecipeData` | recipe system, quality (T), shop/contract demand |
| `machines_balance_template.csv` | `MachineData` | machine state machines, buffers, quality (P, S), breakdowns |
| `economy_balance_template.csv` | `EconomyData` (normal/hard columns) | finance, bankruptcy, shop, contracts, R&D |
| `lookup_packs_template.csv` | `LookupPacks` (machine chains, contract packs, scenario metadata) | scenario runner, default line setup, contracts |
| `master_simulation_template.csv` | `SimScenarios` | **headless test oracle** (see §10) |
| `scenario_summary_template.csv` | `ScenarioSummaries` | balancing UI / test reports |

- A `BalanceDatabase` autoload (thin wrapper) holds all Resources and exposes typed getters.
- Difficulty mode (Normal / Hard) selects the `normal_value` / `hard_value` column at run start.
- CSV schema changes = versioned loader (each loader declares expected header; mismatch = clear error, never silent misparse).

## 4. Core Simulation

### 4.1 Factory Map
- 2D grid (cells), machines placed with footprint `footprint_w x footprint_h` from machine data.
- Two routing networks over the grid:
  - **Conveyor network**: directed graph of conveyor segments; item = a batch unit (kg of product at a stage). Items move cell-per-tick (speed configurable); machine input/output buffers are the source/sink.
  - **Pipe/temperature lanes**: separate network carrying temperature control to machines (roaster, grinder, conche, tempering). Each machine has `ideal_temp_c ± temp_tolerance_c`; the pipe network sets the delivered temperature. Deviation outside tolerance degrades the **P** quality component (process accuracy) proportionally, and beyond 2x tolerance the batch is marked defective (feeds **S** / defect rate).
- Machine buffers: `input_buffer_units` / `output_buffer_units` per machine. A machine runs only when input ≥ 1 unit AND output buffer has space — this is where bottlenecks emerge naturally.
- Storage: finite storage cells (capacity per cell, spoilage per day = `ECO_STORAGE_SPOIL_RATE` × `storage_decay_multiplier`). Finished goods age in storage → freshness decay feeds the **F** quality component.
- Loading bays + truck slots: `ECO_TRUCK_SLOT_COUNT` dispatch slots per day; contracts require shipment within a deadline window tied to a truck slot.

### 4.2 Machine State Machine
Per machine, per tick:
```
IDLE → (input available, output space, temp in window, no breakdown)
     → RUNNING (accumulate cycle progress)
     → (cycle complete) → output unit to output buffer → IDLE
BREAKDOWN (per-day chance = breakdown_chance_pct_day × breakdown_multiplier)
     → REPAIRING (repair_time_min) → IDLE
MAINTENANCE (due every maintenance_interval_days, costs maintenance_cost)
```
- Breakdowns stop the line → stoppage events feed the **C** (consistency) component.
- `queue_penalty_factor` penalizes quality when the machine idles waiting on a full input queue (starvation) or blocked output.

### 4.3 Batch Quality Scoring (locked formula, GDD §8.2.1)
Per batch, components 0–100:
- **T** (taste/flavor balance): recipe `base_taste_score` adjusted by input mix deviation from recipe targets and ingredient quality (farm-grown inputs score higher).
- **P** (process accuracy): starts at 100, decays with temperature deviation outside `temp_tolerance_c` and process-time deviation from `process_time_min` / `ideal_conche_min` windows.
- **C** (consistency): starts at 100, decays per stoppage/breakdown/queue-penalty event during the batch's line traversal.
- **F** (freshness): starts at 100, decays by storage age × spoil rate + routing delay.
- **S** (sanitation/defect prevention): starts at 100, decays with defects (temperature excursions, breakdowns), improved by inspector tiers.
- **W** (wage quality bonus): `ECO_WAGE_QUALITY_MULT` × wage policy level (wage policy is the single labor lever, GDD §10).

`Q = 0.30T + 0.20P + 0.15C + 0.15F + 0.10S + 0.10W` → grade A (85–100), B (70–84), C (55–69), D (<55).
Grade drives shop conversion, contract renewal, returns, brand delta.

### 4.4 Economy & Finance (daily tick)
- Revenue: shop sales (see §4.6) + contract settlements.
- Costs: wages (`ECO_WAGE_BASE` × staff × wage policy), energy (`ECO_ENERGY_PRICE` × kW × run time), machine opex, maintenance, ingredient purchases.
- Debt: loans at `ECO_BASE_LOAN_RATE` (daily interest).
- **Bankruptcy (locked, GDD §12.1)**: triggered when (1) debt > `ECO_DEBT_LIMIT` AND (2) ≥1 obligation missed at period close (wages / loan payment / contract penalty invoice). `ECO_BANKRUPTCY_GRACE_DAYS` grace window before fail confirmation — telegraphed with warnings (GDD §15).
- Hard vs Normal: all knobs from `economy_balance_template.csv` (start cash 60k/45k, debt limit 120k/98k, etc.).

### 4.5 Contracts (locked model, GDD §9.3)
- Recurring long-term agreements from `lookup_packs` (CONTRACT_A/B/C): weekly minimum volume, minimum grade, deadline windows by truck departure slot.
- Weekly settlement: missed volume / late shipment / quality shortfall → penalty at `ECO_CONTRACT_PENALTY_RATE` × value; reputation hit `ECO_CONTRACT_REPUTATION_HIT` per failed obligation; repeated failures terminate the contract.
- Contract channel = steady volume; shop channel = margin + brand control. Inventory allocation between them is the core decision.

### 4.6 Own Shop (locked demand model, GDD §9.4)
Daily: `D = B × (1 − p) × (1 + 0.6b) × (1 + 0.4r) × e`
- B = base category demand (per recipe `shop_demand_base`), p = price penalty (0–0.50, elasticity `ECO_SHOP_PRICE_ELASTICITY`), b = normalized global brand, r = normalized category reputation, e = footfall event multiplier (0.70–1.40, base `ECO_SHOP_FOOTFALL_BASE`, daily events: market day, festival, rainy day...).
- Sell up to min(D, stock); stockout days tracked (balance target < 20% mid-game).
- Brand model (GDD §18): global brand score + per-category reputation; A/B grades raise both, D grades drag; niche R&D outcomes boost category rep.

### 4.7 R&D (locked profile, GDD §8.3.1)
- Projects cost `ECO_RND_PROJECT_BASE_COST`, take in-game days.
- High Risk baseline: Flop 45% / Niche 30% / Stable 20% / Breakout 5%.
- Investment levels (max 5) shift 2% Flop→Stable each; inspector tiers shift 1% Flop→Niche each; Breakout only via special events/breakthroughs.
- Outcomes: Flop (small/negative margin), Niche (category rep gain, low volume), Stable (reliable volume+margin), Breakout (temporary footfall + contract demand spike, `ECO_RND_BREAKOUT_MULT`).
- Visible odds in UI (GDD §15 mitigation).

### 4.8 Progression
- Gradual unlock tree (not chapters): machinery / recipes / farming / logistics / branding branches.
- Supply chain stages: buy pre-fab → in-house sugar → in-house cocoa → milk powder/flavorings/nuts → light farming modules.
- Farming side-map (GDD §16): dedicated map, farm plots + processing sheds + outbound depots, scheduled transport routes back to factory. Lighter than factory; improves input cost stability, quality (higher T), contract resilience.

## 5. Presentation Layer (Godot)

- **2.5D isometric**: `GridMap`-style custom isometric renderer (isometric tile projection, machines as billboarded sprite groups with 3D-ish shading), placement ghost + footprint highlight, camera: drag-pan, wheel-zoom, clamped to map.
- Conveyor items and pipe flow rendered as animated sprites along the network; temperature lanes color-coded (cool→hot gradient).
- Cozy presentation (GDD §11): soft palette, machine idle animations, steam/heat puffs, quirky event flavor text.
- HUD: top bar (day, cash, debt, brand, category rep), bottom build bar (machine palette, conveyor, pipes, storage), machine detail panel (buffers, temp, state, quality components), economy panel (daily P&L breakdown — telegraphs bankruptcy per GDD §15), contract board, R&D panel with visible odds.
- **Build stamp** in HUD corner (version + git short hash) — self-diagnosis aid.

## 6. Save System
- Save = JSON: run seed, difficulty, day/tick, all core state (machines, buffers, inventory, finance, contracts, brand, R&D projects, unlocks).
- Autosave at day close; manual save/load; 3 slots.
- Load = rebuild core sim, apply state, verify checksum.

## 7. File Layout
```
project.godot
data/                    # copies of balancing/*.csv (single source of truth)
src/
  core/
    simulation.gd        # Simulation (RefCounted): owns time, map, economy
    machine.gd  conveyor.gd  pipe.gd  storage.gd  truck.gd
    quality.gd           # quality scoring (locked formula)
    economy.gd  finance.gd  contracts.gd  shop.gd  brand.gd
    rnd.gd  progression.gd  farming.gd
    data/                # CSV loaders + Resource types
  game/
    main.gd  factory_view.gd  farm_view.gd  camera.gd
    ui/                      # HUD, panels, build bar
  autoload/
    balance_db.gd  save_system.gd  game_state.gd
tests/
  run_headless.gd    # scenario runner + assertions
  test_*.gd          # unit tests per core system
export_presets.cfg
```

## 8. Testing & Balancing Workflow
- Headless test harness: `godot --headless -s tests/run_headless.gd --scenario <id>`
- **Oracle = `master_simulation_template.csv`**: the scenario rows (SIM_101–114, SIM_201–214) with their `expected_*` columns are the acceptance targets. The harness runs the scenario, computes the same aggregates as `scenario_summary_template.csv`, and reports deltas (pass criteria from `BALANCING_RECOMMENDATIONS.md` §Validation Plan).
- Unit tests: quality formula (known component values → expected Q/grade), demand formula, bankruptcy rule (both conditions required), contract penalty math, R&D odds shifting, machine state machine, buffer/bottleneck behavior.
- Balancing passes follow `BALANCING_README.md` workflow: tune CSV → rerun 3 scenarios (baseline normal / optimized normal / hard stress) → compare rollups.

## 9. Milestone Plan (maps to GDD §14)
- **M0 — Foundation**: project scaffold, autoloads, CSV loaders + Resources, headless sim skeleton (time, one machine chain, buffers), test harness wired to master sim sheet, save system. *Exit: headless 1-day sim runs and unit tests pass.*
- **M1 — Playable Vertical Slice (GDD M1)**: isometric map + placement + camera, one full end-to-end line (CHAIN_A), one product family (milk bar), shop sales + basic economy, bankruptcy logic, HUD. *Exit: buy → produce → sell loop playable 14 in-game days.*
- **M2 — Factory Depth (GDD M2)**: full bottleneck behavior, storage limits + loading bays, additional products (dark bar, hot choco, truffles), pipe/temperature lanes, routing decisions.
- **M3 — Recipe & Quality Layer (GDD M3)**: full recipe stats, R&D lottery with visible odds, quality inspectors, full quality component UI.
- **M4 — Progression & Integration (GDD M4)**: unlock tree, in-house sugar/cocoa, farming side-map + transport links.
- **M5 — Balance & Polish (GDD M5)**: economy tuning via balancing workflow, UX clarity for bottlenecks/quality, campaign pacing, Normal/Hard tuning to GDD §19 targets.

## 10. Open Decisions (defaults chosen, flag for approval)
1. **Time feel**: default = real-time with pause + 1x/2x/4x (matches cozy tone; factory sims like Factorio). Alternative: turn-based day steps.
2. **Isometric rendering**: default = custom 2D isometric sprite projection (cozy art, cheap, no 3D pipeline). Alternative: Godot 3D isometric camera over 2D sprites.
3. **RNG**: single seeded RNG in core; seed shown in save/HUD for reproducibility.
4. **Test framework**: custom minimal headless runner (no addon dependency) — GUT is an option if preferred.
