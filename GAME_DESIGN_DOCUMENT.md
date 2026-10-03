# Chocolate Factory Tycoon - Game Design Document (v1.0)

## 1. Vision
A cozy but demanding factory tycoon where players design and optimize chocolate production lines, build recipes through R&D, and scale from purchased ingredients to a vertically integrated supply chain. The game mixes relaxing presentation with strict economic consequences.

## 2. Experience Goals
- Feel like an industrial chocolate maker with meaningful process complexity.
- Solve automation and throughput puzzles similar to factory sims.
- Build a brand through recipes, quality, and limited artisan products.
- Balance comfort vibes with real business pressure and bankruptcy risk.

## 3. Target Platform and Audience
- Platform: PC first.
- Audience: Players who enjoy automation games and management sims.
- Session target: Medium-length runs (roughly 5 to 10 hours per campaign).
- Game modes at launch: Normal plus Hard Economy.

## 3.1 Locked Round 2 Decisions
- Camera/map: 2.5D isometric grid.
- Routing systems: conveyors plus pipe/temperature lanes.
- Quality model: simple weighted score.
- R&D risk profile: high risk, jackpot upside.
- Contract model: mostly long recurring contracts with penalties.
- Shop demand model: demand varies by price, brand, and daily footfall events.
- Bankruptcy rule: debt limit plus missed obligations.
- Employee depth: wage affects quality only.
- Farming integration: full side-map with transport back to factory.
- Campaign style: sandbox with optional goals.
- Brand model: global brand plus category reputation.
- Difficulty setup: Normal plus Hard Economy.

## 4. Core Pillars
1. Deep factory optimization.
2. Recipe innovation with risk and reward.
3. Gradual vertical integration of raw materials.
4. Dual market strategy (contracts plus own shop).

## 5. Core Gameplay Loop
1. Buy ingredients and accept selected orders.
2. Route inputs through production machines.
3. Create or improve recipes in R&D.
4. Package and allocate inventory to contracts or own shop.
5. Earn revenue, pay costs, and reinvest.
6. Unlock better machinery and in-house supply options.

## 6. Progression Structure
Progression uses a gradual unlock tree, not hard chapters.

### 6.1 Supply Chain Expansion
- Stage 1: Buy pre-fabricated ingredients.
- Stage 2: Produce sugar in-house.
- Stage 3: Produce cocoa in-house.
- Stage 4: Add milk powder, flavorings, nuts, and specialty inputs.
- Stage 5: Add light farming modules (cocoa and sugar) for quality control and margin gains.

### 6.2 Tech Branches
- Machinery
- Recipes
- Farming
- Logistics
- Branding

## 7. Factory Simulation Systems

### 7.1 Production Steps
Complex chocolate flow with realistic stations:
- Roasting
- Grinding
- Mixing
- Conching
- Tempering
- Molding
- Wrapping

### 7.2 Main Challenge Focus
- Primary: Factory bottlenecks.
- Primary: Product quality consistency.
- Secondary: Order timing, storage pressure, and labor allocation.

### 7.3 Logistics
- Finite storage limits.
- Loading bays for truck dispatch.
- Line routing and queue management.
- Premium artisan bars in limited batches for own shop brand boosts.

## 8. Recipe and R&D Systems

### 8.1 Product Set at Launch
- Milk chocolate bar
- Dark chocolate bar
- Truffles
- Hot chocolate mix

### 8.2 Recipe Variables
All variables are active and influence outcomes:
- Taste
- Quality grade
- Production speed
- Shelf life
- Cost
- Brand appeal

### 8.2.1 Quality Score Formula (Locked)
Per batch, final quality score is:

Q = 0.30T + 0.20P + 0.15C + 0.15F + 0.10S + 0.10W

Where:
- T: ingredient and flavor balance score (0 to 100).
- P: process accuracy score from temperature/time windows (0 to 100).
- C: consistency score from line stability and low stoppages (0 to 100).
- F: freshness score driven by storage age and routing delays (0 to 100).
- S: sanitation/defect-prevention score (0 to 100).
- W: wage quality bonus score (0 to 100), derived only from wage policy.

Grade bands:
- A: 85 to 100
- B: 70 to 84
- C: 55 to 69
- D: below 55

Sales effects:
- Higher grade raises direct shop conversion and contract renewal chance.
- Lower grade increases returns, penalties, and brand drag.

### 8.3 R&D Lottery Model
- Player invests budget and time into new recipe projects.
- Results are probabilistic: flop, niche, stable seller, breakout hit.
- Quality inspectors increase consistency and reduce bad-batch risk.
- Higher investment improves odds but does not guarantee success.

### 8.3.1 R&D Jackpot Profile (Locked)
R&D projects resolve into weighted outcomes by risk tier. Default tier is High Risk.

High Risk baseline odds:
- Flop: 45%
- Niche: 30%
- Stable Seller: 20%
- Breakout Hit: 5%

Investment shifts:
- Each R&D investment level shifts 2% from Flop to Stable Seller (max 5 levels).
- Inspector coverage shifts 1% from Flop to Niche per inspector tier.
- Breakout Hit chance can only be increased by special breakthroughs/events, not raw spending.

Outcome effects:
- Flop: small or negative margin, low demand.
- Niche: high category reputation gain, lower volume.
- Stable Seller: reliable volume and margin.
- Breakout Hit: major temporary footfall and contract demand spike.

## 9. Economy and Sales

### 9.1 Sales Channels
- Own chocolate shop at the factory (direct to customer).
- Contracts and orders (business channel).

### 9.2 Strategic Tension
- Shop channel gives higher margin and stronger brand control.
- Contract channel gives steadier volume and predictability.
- Inventory allocation between channels is a central decision.

### 9.3 Contract Model (Locked)
- Contract type at launch is mostly recurring long-term agreements.
- Contracts specify:
  - minimum weekly volume
  - minimum quality grade
  - deadline windows by truck departure slot
- Penalties apply for:
  - missed volume
  - late shipment
  - quality shortfall
- Repeated failures can terminate a contract and apply reputation loss.

### 9.4 Own Shop Demand Model (Locked)
Shop demand updates daily and depends on:
- Price index (relative to category market average)
- Brand score (global)
- Category reputation score
- Footfall event multiplier

Daily demand model:

D = B * (1 - p) * (1 + 0.6b) * (1 + 0.4r) * e

Where:
- D: expected daily demand units.
- B: base category demand.
- p: price penalty factor (0.00 to 0.50).
- b: normalized brand score (0.00 to 1.00).
- r: normalized category reputation (0.00 to 1.00).
- e: footfall event multiplier (0.70 to 1.40).

## 10. Staff and Labor
- Employees are role-based and interchangeable.
- Higher wages improve product quality outcomes.
- Staffing and shift coverage affect throughput and defects.

Locked depth scope:
- No individual skill trees.
- No turnover simulation in v1.
- Wage policy is the single labor lever influencing quality consistency.

## 11. Tone and Presentation
- Cozy and relaxing mood.
- Realistic industrial operations.
- Quirky flavor in events, flavor text, and branding moments.

## 12. Difficulty and Failure
- Failure mode is strict: bankruptcy ends the run.
- Design target: fair but unforgiving financial management.

### 12.1 Bankruptcy Rule (Locked)
Bankruptcy triggers when both conditions are true:
1. Debt exceeds debt limit.
2. Player misses one or more obligations at period close (wages, loan payment, or contract penalty invoice).

This creates strict pressure while still allowing short-term recovery windows.

## 13. MVP Scope (Locked)
The minimum playable release must include:
1. Buy raw materials.
2. Produce chocolate in a multi-step factory flow.
3. Sell through own shop.
4. Recipe system with measurable quality outcomes.
5. Basic contracts or order fulfillment.
6. Bankruptcy game-over condition.

MVP map and presentation locks:
7. 2.5D isometric factory map.
8. Conveyor plus pipe/temperature routing.

## 14. Milestone Plan

### Milestone 1 - Playable Vertical Slice
- One end-to-end factory line.
- One product family.
- Shop sales and simple economy.
- Basic bankruptcy logic.

### Milestone 2 - Factory Depth
- Full bottleneck behavior.
- Storage limits and loading bay flow.
- Additional products and routing decisions.
- Pipe/temperature lane balancing in addition to conveyors.

### Milestone 3 - Recipe and Quality Layer
- Full recipe stats.
- R&D lottery outcomes.
- Quality inspector mechanics.

### Milestone 4 - Progression and Integration
- Unlock tree implementation.
- In-house sugar and cocoa.
- Full side-map farming with transport links back to factory.

### Milestone 5 - Balance and Polish
- Economy tuning.
- UX clarity for bottlenecks and quality.
- Campaign pacing pass.

## 15. Risks and Mitigations
- Risk: Too much complexity early.
  - Mitigation: Structured onboarding and staged unlocks.
- Risk: RNG frustration in R&D.
  - Mitigation: Visible odds, partial refunds, and progression safety rails.
- Risk: Bankruptcy feels unfair.
  - Mitigation: Telegraphed warnings, clearer forecasting, and tunable grace windows.

## 16. Farming Side-Map Design (Locked)
- Farming exists on a dedicated side-map.
- Player places farm plots, processing sheds, and outbound depots.
- Farm outputs are shipped back to the factory via scheduled transport routes.
- Farming is intentionally lighter than factory gameplay and primarily improves:
  - input cost stability
  - quality control
  - contract resilience

## 17. Optional Goals Structure (Locked)
Campaign is sandbox-first with optional goals:
- Throughput goals (units/day milestones)
- Quality goals (maintain grade bands for N days)
- Commerce goals (shop revenue and contract tenure)
- Integration goals (percentage of in-house ingredients)

Goals grant rewards but are not mandatory for core progression.

## 18. Brand Model (Locked)
Two active brand layers:
- Global brand score (all products)
- Category reputation (bars, truffles, hot chocolate, etc.)

Category wins can offset weak global brand early, while global brand improves baseline demand across categories later.

## 19. Balance Targets (Initial)
- New player survival target (Normal): at least 70% if they complete tutorial goals.
- New player survival target (Hard): about 40% to 50% without optimization.
- Average contract fill target after first optimization pass: 85%+ on Normal.
- Shop stockout target: less than 20% days by mid-game for a healthy factory.
- Breakout hit frequency target: about 1 major hit per 2 to 3 campaigns.

## 20. Production Backlog (Implementation Order)
1. Isometric map, placement grid, and camera controls.
2. Conveyor routing and machine IO.
3. Pipe/temperature system and process-window checks.
4. Batch quality scoring and grade outputs.
5. Shop demand simulation with footfall events.
6. Recurring contract system with penalties.
7. R&D lottery with high-risk profile.
8. Tech tree and unlock progression.
9. Farming side-map plus transport integration.
10. Normal/Hard mode tuning and final balancing.

---
Status: v1.0 finalized from Interview Round 1 and Round 2.
