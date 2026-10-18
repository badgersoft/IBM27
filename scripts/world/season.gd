class_name Season
extends RefCounted
## The season calendar: the fights arranged month by month, the results, the
## monthly newspaper and the boxers getting older.
##
## Months are counted from 0 = January 2027. A month goes like this:
##   1. Its fixtures (arranged two months ago) are fought at the end of the
##      month: watched in the ring, or simulated by FightSim exactly as a
##      watched fight runs (run_fight), so the results are the same kind.
##   2. Each result goes on the boxers' records and earnings and moves them in
##      the rankings (complete).
##   3. Month end (finish_month): every boxer trains (harder in camp) and
##      gets older (Training); some old boxers retire and young prospects
##      take their places; the newspaper is written (Newspaper).
##   4. Into the next month, and the managers arrange the fights for two
##      months on (Matchmaker).
##
## To get going, the managers arrange WARM_UP months of fights before the
## season (start): those before January are taken as fought and only set
## when everyone last fought, so the season begins with fights spread
## evenly over the months, as if it had always been running.

const START_YEAR := 2027
const MONTH_NAMES: Array[String] = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY",
		"AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"]
## A fight is simulated in steps this long, as in the game.
const STEP := 1.0 / 60.0
## Safety net: no fight runs longer than this many steps.
const MAX_STEPS := 60 * 1500
## Retirement: from RETIRE_FROM, each month a boxer with no fight arranged
## retires with RETIRE_CHANCE for every year past RETIRE_FROM - 1; at
## RETIRE_AGE he goes as soon as he is free.
const RETIRE_FROM := 35
const RETIRE_CHANCE := 0.03
const RETIRE_AGE := 39
## Months of fights arranged (but not fought) before the season starts, and
## how long before that the boxers last fought (at random).
const WARM_UP := 10
const START_LAST_FIGHT := Vector2i(1, 4)

var month := 0
var fixtures: Array[Fixture] = []
var papers: Array[Dictionary] = []
var retired: Array[BoxerData] = []
## Things worth a line in this month's paper (retirements, new faces).
var notes: Array[String] = []
## The human boxer's division: the newspaper notes who climbs its rankings.
var player_division: int = Divisions.Id.MIDDLEWEIGHT

var _rankings: Array[Rankings]
var _rng := RandomNumberGenerator.new()
var _matchmaker: Matchmaker
var _generator: BoxerGenerator
var _next_id := 0


func _init(rankings: Array[Rankings], seed_value: int) -> void:
	_rankings = rankings
	_rng.seed = seed_value
	_generator = BoxerGenerator.new(seed_value)
	_matchmaker = Matchmaker.new(rankings, self, _rng)
	for table in _rankings:
		for b in table.boxers:
			_next_id = maxi(_next_id, b.id)


## Runs the warm-up (see WARM_UP): the season opens with the first three
## months' fights arranged and everyone's last fight staggered.
func start() -> void:
	var first := -WARM_UP - Matchmaker.CAMP_MONTHS
	for table in _rankings:
		table.last_defence_month = first
		for b in table.boxers:
			b.last_fight_month = first - _rng.randi_range(START_LAST_FIGHT.x, START_LAST_FIGHT.y)
	for m in range(first, 1):
		_matchmaker.arrange(m)
		# Fights before January count as fought (results are not made up).
		for f in fixtures.duplicate():
			if f.month < 0:
				f.red.last_fight_month = f.month
				f.blue.last_fight_month = f.month
				if f.title:
					_rankings[f.division].last_defence_month = f.month
				fixtures.erase(f)


# ----------------------------------------------------------------------------
#  The calendar
# ----------------------------------------------------------------------------

## "JANUARY 2027" for season month [param m].
static func date_text(m: int) -> String:
	return "%s %d" % [MONTH_NAMES[posmod(m, 12)], START_YEAR + floori(m / 12.0)]


## "JAN" for season month [param m].
static func short_month(m: int) -> String:
	return MONTH_NAMES[posmod(m, 12)].substr(0, 3)


func fixtures_in(m: int) -> Array[Fixture]:
	var out: Array[Fixture] = []
	for f in fixtures:
		if f.month == m:
			out.append(f)
	return out


## Fixtures arranged for after this month, soonest first.
func upcoming() -> Array[Fixture]:
	var out: Array[Fixture] = []
	for f in fixtures:
		if f.month > month:
			out.append(f)
	return out


## The fight [param b] has arranged and not yet fought, or null.
func booking(b: BoxerData) -> Fixture:
	for f in fixtures:
		if not f.is_done() and f.involves(b):
			return f
	return null


func has_vacant_title_fight(division: int) -> bool:
	for f in fixtures:
		if f.vacant and f.division == division and not f.is_done():
			return true
	return false


func add_fixture(f: Fixture) -> void:
	# Kept in order of month, then title fights first, then heaviest
	# division first and the best-ranked fights first within it.
	fixtures.append(f)
	fixtures.sort_custom(func(a: Fixture, b: Fixture) -> bool:
		if a.month != b.month:
			return a.month < b.month
		if a.title != b.title:
			return a.title
		if a.division != b.division:
			return a.division > b.division
		return _best_place(a) < _best_place(b))


## The better-ranked man's place in the fight's division (for ordering).
func _best_place(f: Fixture) -> int:
	var table := _rankings[f.division]
	var a := table.index_of(f.red)
	var b := table.index_of(f.blue)
	return mini(a if a >= 0 else 99, b if b >= 0 else 99)


func month_finished() -> bool:
	for f in fixtures_in(month):
		if not f.is_done():
			return false
	return true


# ----------------------------------------------------------------------------
#  Fights
# ----------------------------------------------------------------------------

## A seed for fixture [param f]'s fight (so a month replays the same way).
func fight_seed(f: Fixture) -> int:
	return absi(hash([month, f.red.id, f.blue.id])) % 1000000


## Fights [param f] with no graphics, exactly as a watched fight runs, and
## keeps the finished simulation on it. Safe to call on a worker thread: it
## only reads the two boxers.
static func run_fight(f: Fixture, seed_value: int) -> void:
	var sim := FightSim.new(f.red, f.blue, seed_value, f.rounds)
	sim.title_fight = f.title
	sim.start_fight()
	var steps := 0
	while sim.phase != FightSim.Phase.FINISHED and steps < MAX_STEPS:
		sim.step(STEP)
		steps += 1
	f.sim = sim


## Records [param f]'s finished fight ([param sim]): records, purse,
## rankings and title, and the excitement rating.
func complete(f: Fixture, sim: FightSim) -> void:
	var before := [_rank(f.red), _rank(f.blue)]
	var summary := record_result(_rankings, f.red, f.blue, sim.result, f.title, f.purse)
	summary["red_rank"] = before[0]
	summary["blue_rank"] = before[1]
	summary["red_rank_after"] = _rank(f.red)
	summary["blue_rank_after"] = _rank(f.blue)
	summary["knockdowns"] = sim.red.knockdowns_total + sim.blue.knockdowns_total
	summary["big_punches"] = sim.red.fight_stats["big"] + sim.blue.fight_stats["big"]
	if f.title and (summary["retained"] or summary["new_champion"]):
		_rankings[f.division].last_defence_month = f.month
	f.red.last_fight_month = f.month
	f.blue.last_fight_month = f.month
	f.result = sim.result
	f.summary = summary
	f.excitement = Excitement.rate(sim)
	f.sim = null


## Adds a finished fight to the boxers' records, pays the purse (60/40)
## and updates the rankings and the title. Returns a summary: {"draw",
## "winner", "loser", "new_champion", "retained", "winner_purse", "loser_purse"}.
static func record_result(rankings: Array[Rankings], fight_red: BoxerData, fight_blue: BoxerData, result: Dictionary,
		title: bool, fight_purse: int) -> Dictionary:
	var winner_corner: int = result["winner"]
	var draw := winner_corner < 0
	var by_ko: bool = result["method"] in ["KO", "TKO"]
	var winner := fight_red if winner_corner != 1 else fight_blue
	var loser := fight_blue if winner == fight_red else fight_red
	if draw:
		fight_red.add_result("D", false)
		fight_blue.add_result("D", false)
	else:
		winner.add_result("W", by_ko)
		loser.add_result("L", by_ko)
	var shares := Purse.split(fight_purse, draw)
	winner.earnings += shares[0]
	loser.earnings += shares[1]
	var summary := {"draw": draw, "winner": winner, "loser": loser,
			"winner_purse": shares[0], "loser_purse": shares[1]}
	var change := {"new_champion": false, "retained": false}
	if fight_red.division == fight_blue.division:
		change = rankings[fight_red.division].record(winner, loser, draw, by_ko, title)
	summary.merge(change)
	return summary


## His place in his division (0 = champion), or -1 if he is not ranked.
func _rank(b: BoxerData) -> int:
	return _rankings[b.division].rank_number(b)


# ----------------------------------------------------------------------------
#  Month end
# ----------------------------------------------------------------------------

## Fights the rest of this month's fixtures here and now (no thread) and
## finishes the month. Returns the newspaper. Used by tools and --months.
func play_month() -> Dictionary:
	for f in fixtures_in(month):
		if not f.is_done():
			run_fight(f, fight_seed(f))
			complete(f, f.sim)
	return finish_month()


## Once every fight of the month is done: training, birthdays, retirements,
## the newspaper, then on to next month and its new bookings. Returns the
## newspaper.
func finish_month() -> Dictionary:
	notes.clear()
	for table in _rankings:
		for b in table.boxers.duplicate():
			var next := booking(b)
			var in_camp: bool = b.last_fight_month == month or (next != null and next.month - month <= 1)
			Training.month(b, in_camp)
			if posmod(month, 12) == b.birth_month:
				b.age += 1
			if next == null and _retires(b):
				_retire(b, table)
	var paper := Newspaper.write(self, month, _rng)
	papers.append(paper)
	month += 1
	_matchmaker.arrange(month)
	return paper


func _retires(b: BoxerData) -> bool:
	if b.age >= RETIRE_AGE:
		return true
	if b.age < RETIRE_FROM:
		return false
	return _rng.randf() < (b.age - RETIRE_FROM + 1) * RETIRE_CHANCE


## [param b] hangs up his gloves; a young prospect takes his place at the
## bottom of the division.
func _retire(b: BoxerData, table: Rankings) -> void:
	var was_champion := table.is_champion(b)
	var names: Array[String] = []
	var nicknames: Array[String] = []
	for t in _rankings:
		for other in t.boxers:
			names.append(other.last_name)
			if not other.nickname.is_empty():
				nicknames.append(other.nickname)
	var fresh := _generator.generate_prospect(table.division as Divisions.Id, names, nicknames)
	_next_id += 1
	fresh.id = _next_id
	fresh.manager = _generator.generate_manager(fresh)
	fresh.last_fight_month = month
	fresh.earnings = Career.estimate_earnings(fresh, table.size() - 1, table.size(), false, _rng)
	table.replace(b, fresh)
	retired.append(b)
	var line := "%s (%d) RETIRES WITH A RECORD OF %s." % [b.display_name().to_upper(), b.age, b.record()]
	if was_champion:
		line = "IBC %s CHAMPION %s (%d) RETIRES. THE TITLE IS VACANT." % [
				Divisions.division_name(table.division).to_upper(), b.display_name().to_upper(), b.age]
	notes.append(line)
	notes.append("NEW FACE: %s, %d, FROM %s, JOINS THE %sS." % [fresh.display_name().to_upper(), fresh.age,
			fresh.city.to_upper(), Divisions.division_name(table.division).to_upper()])
