class_name PoundForPound
extends RefCounted
## The pound-for-pound list: the best boxers in the IBC, whatever their
## weight. Each man's score has two parts:
##
##   RECORD   his whole record: wins and knockouts against losses
##            RECORD_POINTS x (W + KO_SHARE x KO) / (W + L + D + RECORD_PAD),
##            scaled by where he stands in his division now (STANDING_FLOOR
##            at the bottom up to 1 for the champion) - a record built among
##            the best counts for more than one built among the amateurs.
##   QUALITY  every fight he has had this season, against a known opponent
##            of quality q (1 for the champion down to 0 for the last man,
##            where the opponent was ranked when they fought):
##              win   WIN_BASE + WIN_QUALITY x q^2, x KO_BONUS by knockout
##              draw  DRAW_QUALITY x q
##              loss  -(LOSS_BASE - LOSS_QUALITY x q): losing to a top man
##                    costs little, losing to a nobody costs a lot
##
## So wins and knockouts count, and the higher the man he beat was ranked,
## the more they count.

const RECORD_POINTS := 40.0
const KO_SHARE := 0.5
const RECORD_PAD := 3.0
const STANDING_FLOOR := 0.4
const WIN_BASE := 4.0
const WIN_QUALITY := 12.0
const KO_BONUS := 1.3
const DRAW_QUALITY := 4.0
const LOSS_BASE := 8.0
const LOSS_QUALITY := 6.0


## The top [param count]: [{"boxer", "division", "place", "score",
## "best_win": {"opponent", "place", "ko"} or {}}], best first.
static func top(rankings: Array[Rankings], season: Season, count: int = 10) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for table in rankings:
		for b in table.boxers:
			out.append(rate(b, table, season))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	return out.slice(0, count)


## One boxer's pound-for-pound rating (see the top of the file).
static func rate(b: BoxerData, table: Rankings, season: Season) -> Dictionary:
	var place := table.index_of(b)
	var standing := 1.0 - float(place) / float(maxi(table.size() - 1, 1))
	var fights := b.wins + b.losses + b.draws
	var record := RECORD_POINTS * (b.wins + KO_SHARE * b.kos) / (fights + RECORD_PAD)
	record *= lerpf(STANDING_FLOOR, 1.0, standing)
	var quality := 0.0
	var best := {}
	var best_q := -1.0
	for f in season.fixtures:
		if not f.is_done() or not f.involves(b) or f.summary.is_empty():
			continue
		var other := f.opponent_of(b)
		var other_place: int = f.summary.get("blue_rank" if other == f.blue else "red_rank", -1)
		var q := _quality(other_place, table.size())
		var winner := f.winner()
		var ko: bool = f.result.get("method", "") in ["KO", "TKO"]
		if winner == null:
			quality += DRAW_QUALITY * q
		elif winner == b:
			quality += (WIN_BASE + WIN_QUALITY * q * q) * (KO_BONUS if ko else 1.0)
			if q > best_q:
				best_q = q
				best = {"opponent": other, "place": other_place, "ko": ko}
		else:
			quality -= LOSS_BASE - LOSS_QUALITY * q
	return {"boxer": b, "division": b.division, "place": place, "score": record + quality, "best_win": best}


## 0 - 1: a man ranked [param place] (0 = champion) in a [param size]-man
## division; an unknown place counts as the middle.
static func _quality(place: int, size: int) -> float:
	if place < 0:
		return 0.5
	return 1.0 - float(place) / float(maxi(size - 1, 1))
