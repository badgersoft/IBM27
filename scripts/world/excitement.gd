class_name Excitement
extends RefCounted
## Rates a finished fight for excitement out of 10, from what happened in it.
##
## Points are added up for the things a crowd remembers:
##
##   knockdowns            each one, and more if both men went down
##   a comeback            the winner was knocked down, or behind on a
##                         neutral card after half the fight
##   big punches           each one (up to a limit)
##   one-twos              each one (up to a limit)
##   work rate             clean punches landed a round
##   a close finish        a tight decision, a split or a draw
##   the ending            a knockout, more so a late one
##   a title on the line
##
## The total is turned into a rating on an S-shaped curve centred on
## CENTRE points (a 5) that creeps towards 10 but never quite gets there:
## most fights land between 3 and 7, a great one 8 or more, and 9 or more is
## rare (a few long, wild fights in a hundred). 10 is next to impossible.

const BASE := 1.0
const KNOCKDOWN := 1.1
const MAX_KNOCKDOWNS := 4
const BOTH_DOWN := 1.2
const COMEBACK := 1.4
const BIG_PUNCH := 0.25
const MAX_BIG_PUNCH := 2.0
const ONE_TWO := 0.06
const MAX_ONE_TWO := 0.8
## Clean punches landed a round (both men) for no bonus, and for the full one.
const WORK_RATE := Vector2(18.0, 34.0)
const WORK_RATE_BONUS := 1.2
const CLOSE_DECISION := 1.0
const SPLIT := 0.6
const DRAW := 0.6
const KNOCKOUT := 1.0
const LATE_KNOCKOUT := 0.6
const TITLE := 0.5
## rating = 10 / (1 + e^(-(points - CENTRE) / WIDTH)).
const CENTRE := 6.6
const WIDTH := 2.7


## The rating (0 - 10, one decimal place) of [param sim], which must have
## finished.
static func rate(sim: FightSim) -> float:
	var result := sim.result
	var points := BASE
	var downs := [sim.red.knockdowns_total, sim.blue.knockdowns_total]
	points += mini(downs[0] + downs[1], MAX_KNOCKDOWNS) * KNOCKDOWN
	if downs[0] > 0 and downs[1] > 0:
		points += BOTH_DOWN

	var winner: int = result["winner"]
	if winner >= 0 and (downs[winner] > 0 or _was_behind(sim, winner)):
		points += COMEBACK

	var big := 0
	var one_twos := 0
	var landed := 0
	for f in sim.fighters:
		big += f.fight_stats["big"]
		one_twos += f.fight_stats["one_twos"]
		landed += f.fight_stats["landed"]
	points += minf(big * BIG_PUNCH, MAX_BIG_PUNCH)
	points += minf(one_twos * ONE_TWO, MAX_ONE_TWO)
	var per_round := landed / float(maxi(result["round"], 1))
	points += clampf((per_round - WORK_RATE.x) / (WORK_RATE.y - WORK_RATE.x), 0.0, 1.0) * WORK_RATE_BONUS

	match result["method"]:
		"KO", "TKO":
			points += KNOCKOUT
			if result["round"] > sim.rounds * 2 / 3.0:
				points += LATE_KNOCKOUT
		"SD":
			points += SPLIT
		"DRAW":
			points += DRAW
	if not result["method"] in ["KO", "TKO"]:
		var fair := sim.judges.fair_totals()
		if absi(fair[0] - fair[1]) <= 2:
			points += CLOSE_DECISION
	if sim.title_fight:
		points += TITLE
	return snappedf(10.0 / (1.0 + exp(-(points - CENTRE) / WIDTH)), 0.1)


## True if [param corner] was behind on the neutral card at the end of any
## round from halfway on.
static func _was_behind(sim: FightSim, corner: int) -> bool:
	var red := 0
	var blue := 0
	var card: Array = sim.judges.fair_card
	for r in card.size():
		var score: Array = card[r]
		if score.is_empty():
			break
		red += score[0]
		blue += score[1]
		if r + 1 >= sim.rounds / 2.0:
			var mine := red if corner == 0 else blue
			var theirs := blue if corner == 0 else red
			if mine < theirs:
				return true
	return false
