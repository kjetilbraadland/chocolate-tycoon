class_name PacingReport
extends RefCounted
## M5: campaign pacing pass + §19 balance-targets check (GDD §14 milestone 5).
## Consumes the per-day results from a Campaign run and produces:
##   - a pacing report (cash trajectory, days-to-break-even, negative-day
##     clustering, survival) — the data behind the pacing HUD / campaign
##     summary screen
##   - a §19 balance-targets check (contract fill ≥85%, stockout <20% days,
##     survival targets) so a balance pass can be validated headlessly
##
## Fully headless-testable; the visual pacing HUD is deferred for play-test.

# Build a pacing report from the per-day result dicts.
static func build(day_results: Array, start_cash: float) -> Dictionary:
	var n: int = day_results.size()
	if n == 0:
		# No days run yet: return the full key set with neutral defaults so
		# callers (campaign.gd, hud_view.gd) can read every field safely.
		return {
			"days": 0,
			"start_cash": start_cash,
			"end_cash": start_cash,
			"min_cash": start_cash,
			"min_cash_day": -1,
			"break_even_day": -1,
			"total_profit": 0.0,
			"neg_profit_days": 0,
			"neg_days": [],
			"max_negative_run": 0,
			"survived": true,
			"summary": "no days run yet",
		}
	var end_cash: float = float((day_results[n - 1] as Dictionary).cash)
	var min_cash: float = INF
	var min_cash_day: int = -1
	var break_even_day: int = -1
	var neg_days: Array = []  # day indices with profit < 0
	var total_profit: float = 0.0
	for i in range(n):
		var r: Dictionary = day_results[i]
		var cash: float = r.cash
		var profit: float = r.profit
		total_profit += profit
		if cash < min_cash:
			min_cash = cash
			min_cash_day = int(r.day)
		if break_even_day < 0 and cash >= start_cash:
			break_even_day = int(r.day)
		if profit < 0.0:
			neg_days.append(int(r.day))
	# negative-day clustering: longest run of consecutive negative days
	var max_run: int = 0
	var run: int = 0
	var prev_day: int = -1
	for d in neg_days:
		if prev_day >= 0 and d == prev_day + 1:
			run += 1
		else:
			run = 1
		prev_day = d
		if run > max_run:
			max_run = run
	return {
		"days": n,
		"start_cash": start_cash,
		"end_cash": end_cash,
		"min_cash": min_cash,
		"min_cash_day": min_cash_day,
		"break_even_day": break_even_day,
		"total_profit": total_profit,
		"neg_profit_days": neg_days.size(),
		"neg_days": neg_days,
		"max_negative_run": max_run,
		"survived": end_cash >= 0.0 and min_cash > -1.0,  # never deeply negative
		"summary": _summary(n, start_cash, end_cash, break_even_day,
			neg_days.size(), max_run),
	}

static func _summary(n: int, start_cash: float, end_cash: float,
		break_even_day: int, neg: int, max_run: int) -> String:
	var parts: Array = []
	parts.append("cash %.0f -> %.0f over %d days" % [start_cash, end_cash, n])
	if break_even_day >= 0:
		parts.append("break-even on day %d" % break_even_day)
	else:
		parts.append("never reached break-even")
	if neg > 0:
		parts.append("%d negative days (longest run %d)" % [neg, max_run])
	else:
		parts.append("no negative days")
	return " | ".join(parts)

# §19 balance-targets check (GDD §19). Given campaign aggregates, report
# which targets are met. `days` = total days, `stockout_days` = days the
# shop was short, `contract_fill_pct` = avg contract fill, `survived` = bool.
static func check_targets(days: int, stockout_days: int,
		contract_fill_pct: float, survived: bool, is_hard: bool) -> Dictionary:
	var results: Dictionary = {}
	# contract fill target: 85%+ on Normal
	var fill_target: float = 85.0
	results["contract_fill"] = {
		"target": fill_target,
		"got": contract_fill_pct,
		"met": contract_fill_pct >= fill_target,
	}
	# stockout target: <20% days by mid-game
	var stockout_target: float = 20.0
	var stockout_pct: float = (float(stockout_days) / float(maxi(days, 1))) * 100.0
	results["stockout"] = {
		"target_pct": stockout_target,
		"got_pct": stockout_pct,
		"met": stockout_pct < stockout_target,
	}
	# survival target: Normal >=70%, Hard 40-50% (single-run proxy: survived?)
	results["survival"] = {
		"target": ">=70% Normal / 40-50% Hard (multi-run)",
		"single_run_survived": survived,
		"met": survived,
	}
	var all_met: bool = true
	for k in results:
		if not results[k].met:
			all_met = false
	results["all_met"] = all_met
	return results
