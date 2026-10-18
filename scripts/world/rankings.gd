class_name Rankings
extends RefCounted
## One weight division's rankings: every boxer in order, best first, and
## who holds the division's IBC title.
##
## The champion (when there is one) is always first and is shown as "C";
## everyone else is a numbered contender (1, 2, 3...). The order is split
## into thirds, which are the boxers' levels:
##
##   top third      Professional   12-round fights, purses in the millions
##   middle third   Semi-Pro       10-round fights, purses in the thousands
##   bottom third   Amateur        6-round fights, purses in the hundreds
##
## Results move boxers up and down in one of two ways (see Mode):
##
##   LADDER  The winner, if he was below the loser, takes the loser's place
##           and the loser (and everyone between them) drops one place. A
##           win over a lower-ranked man, or a draw, changes nothing. Easy to
##           follow: a big win is a big jump, and a loss only ever costs one
##           place.
##   POINTS  Every boxer has ranking points and the order is simply who has
##           most. A win earns points, more for beating a better-ranked man
##           (and a little more inside the distance or for a title); a loss
##           costs only half as much as the same win would have earned.
##           Boxers climb steadily, an upset is rewarded, and one bad night
##           costs a place or so rather than a career.
##
## A champion who loses a non-title fight keeps his belt and his place at
## the top; the man who beat him moves up as if he had beaten the number 1.

enum Mode { LADDER, POINTS }
enum Tier { AMATEUR, SEMI_PRO, PROFESSIONAL }

const MODE_NAMES: Array[String] = ["Ladder", "Points"]
const TIER_NAMES: Array[String] = ["Amateur", "Semi-Pro", "Professional"]
## Short forms for the Boxers list.
const TIER_SHORT: Array[String] = ["AM", "SEMI", "PRO"]
## Scheduled rounds for a fight at each level, and for a title fight.
const TIER_ROUNDS: Array[int] = [6, 10, 12]
const TITLE_ROUNDS := 12
## Venues for a fight at each level (see Venues.Id); title fights are
## always at the Grand Arena.
const TIER_VENUES: Array = [
	[Venues.Id.SMALL_GYM, Venues.Id.CITY_GYM],
	[Venues.Id.CITY_GYM, Venues.Id.BOXING_HALL],
	[Venues.Id.BOXING_HALL, Venues.Id.GRAND_ARENA],
]
## The title every division has.
const TITLE_NAME := "IBC"

# --- Points mode --------------------------------------------------------------
## Starting points: the top man has POINTS_TOP and each place below him
## POINTS_STEP fewer.
const POINTS_TOP := 1000.0
const POINTS_STEP := 20.0
## Elo-style expectation: a gap of POINTS_SCALE points makes the better man a
## 10-to-1 favourite on paper.
const POINTS_SCALE := 200.0
## Points at stake: a win earns up to POINTS_WIN (the more of an upset, the
## more), a loss costs up to POINTS_LOSS (half as much), a draw moves the
## two men POINTS_DRAW towards each other's expectations.
const POINTS_WIN := 40.0
const POINTS_LOSS := 20.0
const POINTS_DRAW := 16.0
const POINTS_KO_BONUS := 1.25      ## Wins inside the distance.
const POINTS_TITLE_BONUS := 1.5    ## Title fights.

var division: int = Divisions.Id.MIDDLEWEIGHT
var mode: Mode = Mode.LADDER
## Every boxer in the division, best first (the champion, if any, is first).
var boxers: Array[BoxerData] = []
## The IBC champion, or null while the title is vacant.
var champion: BoxerData = null
## Season month the title was last on the line (see Season).
var last_defence_month := -99


func _init(division_id: int, ranked: Array[BoxerData], ranking_mode: Mode) -> void:
	division = division_id
	mode = ranking_mode
	boxers = ranked.duplicate()
	for i in boxers.size():
		boxers[i].rank_points = POINTS_TOP - i * POINTS_STEP
	# The best man starts as champion.
	champion = boxers[0] if not boxers.is_empty() else null


func size() -> int:
	return boxers.size()


func index_of(b: BoxerData) -> int:
	return boxers.find(b)


func is_champion(b: BoxerData) -> bool:
	return b != null and b == champion


## 0 for the champion, otherwise his number among the contenders (from 1).
func rank_number(b: BoxerData) -> int:
	var i := index_of(b)
	if i < 0:
		return -1
	if champion == null:
		return i + 1
	return 0 if b == champion else i


## "C" for the champion, "4" for the number 4 contender.
func rank_label(b: BoxerData) -> String:
	var n := rank_number(b)
	return "C" if n == 0 else str(n)


## "IBC CHAMPION" or "NO. 4" - for profiles and the tale of the tape.
func rank_text(b: BoxerData) -> String:
	var n := rank_number(b)
	return "%s CHAMPION" % TITLE_NAME if n == 0 else "NO. %d" % n


## The level of whoever is at [param index] in the order.
func tier_at(index: int) -> Tier:
	return tier_for(index, boxers.size())


static func tier_for(index: int, count: int) -> Tier:
	var third := ceili(count / 3.0)
	if index < third:
		return Tier.PROFESSIONAL
	if index < third * 2:
		return Tier.SEMI_PRO
	return Tier.AMATEUR


func tier_of(b: BoxerData) -> Tier:
	return tier_at(maxi(index_of(b), 0))


## The best [param count] contenders (not the champion), in order.
func contenders(count: int) -> Array[BoxerData]:
	var out: Array[BoxerData] = []
	for b in boxers:
		if b != champion:
			out.append(b)
			if out.size() >= count:
				break
	return out


## The boxers ordered by overall rating, best first (for the Boxers list).
func by_overall() -> Array[BoxerData]:
	var out := boxers.duplicate()
	out.sort_custom(func(a: BoxerData, b: BoxerData) -> bool:
		if a.overall() != b.overall():
			return a.overall() > b.overall()
		return index_of(a) < index_of(b))
	return out


## Records a fight between two boxers of this division. [param winner] and
## [param loser] are the two men (either way round for a draw). A title
## fight won by the challenger, or a vacant title won by anyone, crowns the
## winner. Returns what changed: {"new_champion": bool, "retained": bool}.
func record(winner: BoxerData, loser: BoxerData, draw: bool, by_ko: bool, title_fight: bool) -> Dictionary:
	var change := {"new_champion": false, "retained": false}
	if index_of(winner) < 0 or index_of(loser) < 0:
		return change   # Not both in this division (a fight across divisions).
	if title_fight:
		if draw or winner == champion:
			change["retained"] = champion != null
		else:
			champion = winner
			change["new_champion"] = true
	if mode == Mode.LADDER:
		if not draw:
			_ladder(winner, loser)
	else:
		_points(winner, loser, draw, by_ko, title_fight)
	_champion_first()
	return change


## Takes [param old] out of the rankings and puts [param fresh] in at the
## bottom (a retirement and a new prospect). Vacates the title if [param old]
## was the champion; returns true if so.
func replace(old: BoxerData, fresh: BoxerData) -> bool:
	var vacated := old == champion
	if vacated:
		champion = null
	boxers.erase(old)
	fresh.rank_points = (boxers[-1].rank_points - POINTS_STEP) if not boxers.is_empty() else POINTS_TOP
	boxers.append(fresh)
	return vacated


# ----------------------------------------------------------------------------

func _ladder(winner: BoxerData, loser: BoxerData) -> void:
	var wi := index_of(winner)
	var li := index_of(loser)
	if wi < li:
		return   # Already above him.
	# A champion beaten without his title on the line keeps the top spot.
	var target := li
	if loser == champion and winner != champion:
		target = li + 1
	if target >= wi:
		return
	boxers.remove_at(wi)
	boxers.insert(target, winner)


func _points(winner: BoxerData, loser: BoxerData, draw: bool, by_ko: bool, title_fight: bool) -> void:
	var expect_w := _expectation(winner.rank_points, loser.rank_points)
	var scale := POINTS_TITLE_BONUS if title_fight else 1.0
	if draw:
		winner.rank_points += POINTS_DRAW * (0.5 - expect_w) * scale
		loser.rank_points += POINTS_DRAW * (expect_w - 0.5) * scale
	else:
		var gain := POINTS_WIN * (1.0 - expect_w) * scale * (POINTS_KO_BONUS if by_ko else 1.0)
		winner.rank_points += gain
		loser.rank_points -= POINTS_LOSS * (1.0 - expect_w) * scale
	boxers.sort_custom(func(a: BoxerData, b: BoxerData) -> bool: return a.rank_points > b.rank_points)


## Chance (on paper) that a man with [param a] points beats one with [param b].
static func _expectation(a: float, b: float) -> float:
	return 1.0 / (1.0 + pow(10.0, (b - a) / POINTS_SCALE))


func _champion_first() -> void:
	if champion != null and boxers[0] != champion:
		boxers.erase(champion)
		boxers.insert(0, champion)
