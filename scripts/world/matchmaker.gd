class_name Matchmaker
extends RefCounted
## The managers arranging the season's fights, once a month.
##
## The calendar:
##   * A fight is arranged two months ahead (CAMP_MONTHS): that is the
##     boxer's training camp. It takes place at the end of the month.
##   * A boxer can have a new fight arranged a month after his last one
##     (RECOVERY_MONTHS), so fights are at least three months apart.
##   * Arranging one by two months after his last fight (LATEST_GAP) is a
##     must, so everyone fights at least every four months: three or four
##     fights a year, with about a quarter of all boxers fighting in any
##     month.
##
## Who looks for a fight: a boxer who is due one always; otherwise his
## manager might wait a month (LOOK_CHANCE by type).
##
## Who he can fight (anyone not already booked and recovered):
##   1. In his own division, someone no more than ABOVE places above him or
##      BELOW places below him.
##   2. In the division above, only its bottom UP_DIVISION_BOTTOM available men.
##   3. In the division below, only its top DOWN_DIVISION_TOP available men.
## Managers only look outside their division now and then (CROSS_DIVISION).
##
## Who he picks, by his manager's type:
##   Money Man   the biggest purse on offer
##   Protective  the weakest man on offer (lowest overall rating)
##   Old School  anyone at all
## The other manager has his say: a protective one turns down a man clearly
## better than his own (PROTECTIVE_REFUSES overall points) unless his boxer
## is due a fight.
##
## Titles: any fight a champion has DEFENCE_DUE or more months after his
## last defence is for his title (and he goes looking for one), so he
## defends at least once a year; he often does sooner (VOLUNTARY_DEFENCE). A vacant title is fought for by the
## two best contenders as soon as both are free; until then neither is
## booked for anything else.

const CAMP_MONTHS := 2
const RECOVERY_MONTHS := 1
const LATEST_GAP := 2
const ABOVE := 4
const BELOW := 6
const UP_DIVISION_BOTTOM := 2
const DOWN_DIVISION_TOP := 3
const CROSS_DIVISION := 0.08
## Chance a manager arranges a fight in a month when his boxer is not yet
## due one: Money Man, Protective, Old School.
const LOOK_CHANCE: Array[float] = [0.30, 0.15, 0.45]
const PROTECTIVE_REFUSES := 4
## A money man takes the best-paid fight, or now and then the next best.
const MONEY_SECOND_CHOICE := 0.25
const DEFENCE_DUE := 9
const VOLUNTARY_DEFENCE := 0.6
## Tries before a boxer gives up for the month (other managers refusing).
const OFFERS := 3

var _rankings: Array[Rankings]
var _season: Season
var _rng: RandomNumberGenerator
var _reserved: Array[BoxerData] = []


func _init(rankings: Array[Rankings], season: Season, rng: RandomNumberGenerator) -> void:
	_rankings = rankings
	_season = season
	_rng = rng


## Arranges fights in [param month] for the end of month + CAMP_MONTHS.
## Returns the new fixtures.
func arrange(month: int) -> Array[Fixture]:
	var made: Array[Fixture] = []
	_reserved.clear()
	var fight_month := month + CAMP_MONTHS

	# Vacant titles first: the two best contenders, as soon as both are free.
	for table in _rankings:
		if table.champion != null or _season.has_vacant_title_fight(table.division):
			continue
		var top := table.contenders(2)
		if top.size() < 2:
			continue
		if _available(top[0], month) and _available(top[1], month):
			made.append(_book(top[0], top[1], month, fight_month, true))
		else:
			for b in top:
				if _season.booking(b) == null:
					_reserved.append(b)

	# Everyone else: those due a fight first, then the rest in a random order.
	var due: Array[BoxerData] = []
	var others: Array[BoxerData] = []
	for table in _rankings:
		for b in table.boxers:
			if not _available(b, month):
				continue
			if _is_due(b, month):
				due.append(b)
			else:
				others.append(b)
	_shuffle(due)
	_shuffle(others)
	for b in due + others:
		if not _available(b, month):
			continue   # Taken by an earlier booking this month.
		var urgent := _is_due(b, month)
		if not urgent and _rng.randf() >= LOOK_CHANCE[b.manager.type]:
			continue
		var opponent := _find_opponent(b, month)
		if opponent != null:
			made.append(_book(b, opponent, month, fight_month, false))
	return made


## A boxer free to have a fight arranged in [param month].
func _available(b: BoxerData, month: int) -> bool:
	return _season.booking(b) == null and month - b.last_fight_month >= RECOVERY_MONTHS \
			and not _reserved.has(b) and _rankings[b.division].index_of(b) >= 0


## Due a fight: a long enough gap since his last one, or a champion whose
## defence is due.
func _is_due(b: BoxerData, month: int) -> bool:
	if month - b.last_fight_month >= LATEST_GAP:
		return true
	var table := _rankings[b.division]
	return table.is_champion(b) and month + CAMP_MONTHS - table.last_defence_month >= DEFENCE_DUE


## Everyone [param b] could fight under the three rules.
func candidates(b: BoxerData, month: int) -> Array[BoxerData]:
	var out: Array[BoxerData] = []
	var table := _rankings[b.division]
	var i := table.index_of(b)
	for j in range(maxi(i - ABOVE, 0), mini(i + BELOW, table.size() - 1) + 1):
		var other := table.boxers[j]
		if other != b and _available(other, month):
			out.append(other)
	if _rng.randf() < CROSS_DIVISION:
		if b.division + 1 < _rankings.size():
			out.append_array(_available_from(_rankings[b.division + 1], UP_DIVISION_BOTTOM, true, month))
		if b.division > 0:
			out.append_array(_available_from(_rankings[b.division - 1], DOWN_DIVISION_TOP, false, month))
	return out


## The first [param count] available men from the bottom (or top) of a division.
func _available_from(table: Rankings, count: int, from_bottom: bool, month: int) -> Array[BoxerData]:
	var out: Array[BoxerData] = []
	var order := table.boxers.duplicate()
	if from_bottom:
		order.reverse()
	for b in order:
		if _available(b, month):
			out.append(b)
			if out.size() >= count:
				break
	return out


func _find_opponent(b: BoxerData, month: int) -> BoxerData:
	var options := candidates(b, month)
	for attempt in OFFERS:
		if options.is_empty():
			return null
		var pick := _choose(b, options)
		if _accepts(pick, b, month):
			return pick
		options.erase(pick)
	return null


## The manager's choice from [param options], by his type.
func _choose(b: BoxerData, options: Array[BoxerData]) -> BoxerData:
	match b.manager.type:
		ManagerData.Type.MONEY:
			var by_purse := options.duplicate()
			by_purse.sort_custom(func(x: BoxerData, y: BoxerData) -> bool: return _purse_with(b, x) > _purse_with(b, y))
			if by_purse.size() > 1 and _rng.randf() < MONEY_SECOND_CHOICE:
				return by_purse[1]
			return by_purse[0]
		ManagerData.Type.PROTECTIVE:
			var weakest := options[0]
			for o in options:
				if o.overall() < weakest.overall():
					weakest = o
			return weakest
		_:
			return options[_rng.randi_range(0, options.size() - 1)]


## Does [param b]'s manager accept a fight with [param challenger]?
func _accepts(b: BoxerData, challenger: BoxerData, month: int) -> bool:
	if b.manager.type != ManagerData.Type.PROTECTIVE or _is_due(b, month):
		return true
	return challenger.overall() <= b.overall() + PROTECTIVE_REFUSES


## The purse [param b] would earn against [param other] (for a money man).
func _purse_with(b: BoxerData, other: BoxerData) -> int:
	var division := maxi(b.division, other.division)
	return Purse.for_fight(_rankings[b.division].index_of(b), _rankings[other.division].index_of(other),
			_rankings[division].size(), division, false)


func _book(a: BoxerData, b: BoxerData, month: int, fight_month: int, vacant: bool) -> Fixture:
	var title := vacant
	if not vacant and a.division == b.division:
		var table := _rankings[a.division]
		var champ: BoxerData = a if table.is_champion(a) else (b if table.is_champion(b) else null)
		if champ != null:
			title = fight_month - table.last_defence_month >= DEFENCE_DUE or _rng.randf() < VOLUNTARY_DEFENCE
	var f := _terms(a, b, title)
	f.vacant = vacant
	f.month = fight_month
	f.arranged = month
	_season.add_fixture(f)
	return f


## The fight's corners, weight, length, purse and venue.
func _terms(a: BoxerData, b: BoxerData, title: bool) -> Fixture:
	var f := Fixture.new()
	var ia := _rankings[a.division].index_of(a)
	var ib := _rankings[b.division].index_of(b)
	var a_red := ia <= ib
	if a.division != b.division:
		a_red = a.division > b.division
	f.red = a if a_red else b
	f.blue = b if a_red else a
	f.division = maxi(a.division, b.division)
	f.title = title
	var count := _rankings[f.division].size()
	var best := mini(ia, ib)
	var level := Rankings.tier_for(best, count)
	f.rounds = Rankings.TITLE_ROUNDS if title else Rankings.TIER_ROUNDS[level]
	f.purse = Purse.for_fight(ia, ib, count, f.division, title, _rng)
	var venues: Array = Rankings.TIER_VENUES[level]
	f.venue = Venues.Id.GRAND_ARENA if title else venues[_rng.randi_range(0, venues.size() - 1)]
	return f


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp
