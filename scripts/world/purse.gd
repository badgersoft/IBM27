class_name Purse
extends RefCounted
## What a fight is worth. The purse is split 60% to the winner and 40% to
## the loser (half each for a draw).
##
## A fight's level is that of the better-ranked boxer (see Rankings). Inside
## a level the purse grows with how high the two men are ranked between them:
##
##   level          purse                          most fights
##   Amateur        $200 - $10K                    a few hundred dollars
##   Semi-Pro       $5K - $50K                     $5K - $25K
##   Professional   $5M - $100M (title fights)     tens of millions
##
## Then:  x 0.70 if no title is on the line, and by division
## (Heavyweight 100%, Middleweight 80%, Lightweight 60%), so only a
## heavyweight title fight between the champion and the number 1 reaches
## $100M; a middleweight one tops out at $80M.

const WINNER_SHARE := 0.60
const NON_TITLE := 0.70
## By division: Lightweight, Middleweight, Heavyweight.
const DIVISION_SHARE: Array[float] = [0.60, 0.80, 1.00]
## Per level [lowest, highest, curve]: purse = lowest x (highest / lowest)
## ^ (quality ^ curve). A curve over 1 keeps most fights near the bottom of
## the range; under 1 lifts the middle.
const LEVELS: Array = [
	[200.0,       10000.0,     3.0],    # Amateur
	[5000.0,      50000.0,     1.3],    # Semi-Pro
	[5000000.0,   100000000.0, 0.7],    # Professional
]
## Random spread either side, so no two purses are quite the same.
const SPREAD := 0.10


## The purse for a fight between the boxers at [param index_a] and
## [param index_b] of a [param count]-man division.
static func for_fight(index_a: int, index_b: int, count: int, division: int, title: bool,
		rng: RandomNumberGenerator = null) -> int:
	var best := mini(index_a, index_b)
	var tier := Rankings.tier_for(best, count)
	var level: Array = LEVELS[tier]
	var q := quality(index_a, index_b, count)
	var amount: float = level[0] * pow(level[1] / level[0], pow(q, level[2]))
	if not title:
		amount *= NON_TITLE
	amount *= DIVISION_SHARE[clampi(division, 0, DIVISION_SHARE.size() - 1)]
	if rng != null:
		amount *= rng.randf_range(1.0 - SPREAD, 1.0 + SPREAD)
	return roundi(amount)


## 0 - 1: how big a fight this is within its level. The top two men of the
## level score 1, the bottom two 0. A man from a lower level counts as the
## bottom of this one.
static func quality(index_a: int, index_b: int, count: int) -> float:
	var third := ceili(count / 3.0)
	var start := floori(mini(index_a, index_b) / float(third)) * third
	var a := clampi(index_a - start, 0, third - 1)
	var b := clampi(index_b - start, 0, third - 1)
	return clampf(1.0 - float(a + b - 1) / float(maxi(third * 2 - 3, 1)), 0.0, 1.0)


## The winner's and loser's shares: [winner, loser].
static func split(purse: int, draw: bool) -> Array[int]:
	if draw:
		var half := floori(purse / 2.0)
		return [half, purse - half]
	var w := roundi(purse * WINNER_SHARE)
	return [w, purse - w]


## "$350M", "$12.4M", "$850K", "$7.5K", "$450".
static func money_text(amount: int) -> String:
	var a := float(amount)
	if a >= 10000000.0:
		return "$%dM" % roundi(a / 1000000.0)
	if a >= 999500.0:
		return "$%.1fM" % (a / 1000000.0)
	if a >= 9950.0:
		return "$%dK" % roundi(a / 1000.0)
	if a >= 999.5:
		return "$%.1fK" % (a / 1000.0)
	return "$%d" % amount
