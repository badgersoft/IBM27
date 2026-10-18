extends Node
## Global game state (autoloaded as "GameState").
##
## Holds every division's rankings (its boxers, best first, and its IBC
## champion), the season (fixtures, results and newspapers) and the details
## of the next fight, so that any scene can reach them. Nothing here is saved
## to disk yet.
##
## Command-line options (after "--") are read here too, which is handy for
## testing and for the screenshot tool:
##   --seed=<n>      fixed random seed for the fight
##   --roster=<n>    use different starting rosters
##   --division=<0-2> force a division (0 light, 1 middle, 2 heavy)
##   --venue=<0-3>   force a venue (0 town gym, 1 city gym, 2 boxing hall, 3 grand arena)
##   --capture=<png> take a screenshot during the fight and quit (see CaptureTool)
##   --index=<0-29>  which boxer's profile to open (with --division)
##   --rounds=<n>    fight length: 3, 6, 10 or 12 (normally set by the boxers' level)
##   --red=<n> --blue=<n>  pick the boxers by place in the rankings (1 = top)
##   --title         make it a title fight (the champion against the number 1)
##   --ranking=ladder|points  how results move boxers up and down (see Rankings)
##   --months=<n>    play the first n months of the season at start-up

## Boxers per division.
const ROSTER_SIZE := 30
## Seed for the managers and made-up career earnings (kept apart from the
## boxers' own seeds so adding them changed no one's name or skills).
const BUSINESS_SEED := 4242
## Seed for the season: the same fights are arranged every run.
const SEASON_SEED := 2027
## How a quick fight finds an opponent: someone no more than this many places
## above or below (see Matchmaker for the full rules the season uses).
const QUICK_FIGHT_ABOVE := 4
const QUICK_FIGHT_BELOW := 6

## How results move boxers up and down (see Rankings.Mode).
var ranking_mode: Rankings.Mode = Rankings.Mode.LADDER
## rankings[division] = that division's Rankings. Each division's starting
## roster is the same every run (its roster_seed in Divisions; the
## middleweights use 1985, after the original game). Pass --roster=<n> for a
## different set of boxers.
var rankings: Array[Rankings] = []
var season: Season
## The human boxer's division. There is no human boxer yet, so for now the
## newspaper's rankings notes follow the middleweights.
var player_division: int = Divisions.Id.MIDDLEWEIGHT

# --- The next fight ------------------------------------------------------------
var red: BoxerData
var blue: BoxerData
var division: int = Divisions.Id.MIDDLEWEIGHT
## Scheduled rounds (see FightLengths).
var rounds := FightLengths.DEFAULT_ROUNDS
var venue_id := 0
var title_fight := false
## Corner of the champion in a title fight (0 red, 1 blue), -1 if the title
## is vacant or not on the line.
var title_holder := -1
var purse := 0
## The season fixture being watched, or null for a quick fight.
var fixture: Fixture = null
## Which of the season's newspapers the newspaper screen shows.
var paper_index := 0

## The Boxers screen remembers its tab, page and order, and which boxer's
## profile is open (his place in that order).
enum ListOrder { OVERALL, RANKING }
var roster_tab: int = Divisions.Id.MIDDLEWEIGHT
var roster_page := 0
var roster_order: ListOrder = ListOrder.OVERALL
var profile_division: int = Divisions.Id.MIDDLEWEIGHT
var profile_index := 0

## Options parsed from the command line.
var options := {}

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_parse_options()
	var seed_value := int(options.get("seed", -1))
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	if options.get("ranking", "") == "points":
		ranking_mode = Rankings.Mode.POINTS
	if options.has("division"):
		profile_division = clampi(int(options["division"]), 0, Divisions.count() - 1)
	profile_index = clampi(int(options.get("index", 0)), 0, ROSTER_SIZE - 1)
	if options.get("order", "") == "rank":
		roster_order = ListOrder.RANKING
	_build_rosters()
	season = Season.new(rankings, SEASON_SEED + int(options.get("roster", 0)))
	season.player_division = player_division
	season.start()
	for m in int(options.get("months", 0)):
		season.play_month()
	paper_index = season.papers.size() - 1


## The boxers in one division, best-ranked first.
func boxers_in(division_id: int) -> Array[BoxerData]:
	return rankings[division_id].boxers


func rankings_for(b: BoxerData) -> Rankings:
	return rankings[b.division]


func is_champion(b: BoxerData) -> bool:
	return rankings[b.division].is_champion(b)


## A division's boxers in the Boxers list's current order.
func listed_boxers(division_id: int) -> Array[BoxerData]:
	if roster_order == ListOrder.RANKING:
		return rankings[division_id].boxers
	return rankings[division_id].by_overall()


## Picks the next quick fight: a division, a boxer and an opponent ranked
## near him (no more than QUICK_FIGHT_ABOVE places above or QUICK_FIGHT_BELOW
## below), and a venue to suit. The fight's length and purse come from the
## better man's level; a fight involving the champion is for his title.
## --division, --red, --blue, --title, --rounds and --venue override.
func new_fight() -> void:
	fixture = null
	if options.has("division"):
		division = clampi(int(options["division"]), 0, Divisions.count() - 1)
	else:
		division = _rng.randi_range(0, Divisions.count() - 1)
	var table := rankings[division]
	var roster := table.boxers
	var first := _rng.randi_range(0, roster.size() - 1)
	var options_for_first: Array[int] = []
	for i in range(maxi(first - QUICK_FIGHT_ABOVE, 0), mini(first + QUICK_FIGHT_BELOW, roster.size() - 1) + 1):
		if i != first:
			options_for_first.append(i)
	var second: int = options_for_first[_rng.randi_range(0, options_for_first.size() - 1)]
	if options.has("title"):
		first = 0
		second = 1
	# --red / --blue pick boxers by their place in the rankings (from 1).
	if options.has("red"):
		first = clampi(int(options["red"]) - 1, 0, roster.size() - 1)
	if options.has("blue"):
		second = clampi(int(options["blue"]) - 1, 0, roster.size() - 1)
	red = roster[first]
	blue = roster[second]

	title_fight = table.is_champion(red) or table.is_champion(blue) or (options.has("title") and table.champion == null)
	title_holder = -1
	if title_fight and table.champion != null:
		title_holder = 0 if table.is_champion(red) else 1
	var best := mini(first, second)
	var level := table.tier_at(best)
	rounds = Rankings.TITLE_ROUNDS if title_fight else Rankings.TIER_ROUNDS[level]
	if options.has("rounds") and FightLengths.is_valid(int(options["rounds"])):
		rounds = int(options["rounds"])
	purse = Purse.for_fight(first, second, roster.size(), division, title_fight, _rng)

	if options.has("venue"):
		venue_id = clampi(int(options["venue"]), 0, Venues.count() - 1)
	elif title_fight:
		venue_id = Venues.Id.GRAND_ARENA
	else:
		var venues: Array = Rankings.TIER_VENUES[level]
		venue_id = venues[_rng.randi_range(0, venues.size() - 1)]


## Sets up season fixture [param f] to be watched in the ring.
func watch_fixture(f: Fixture) -> void:
	fixture = f
	red = f.red
	blue = f.blue
	division = f.division
	rounds = f.rounds
	venue_id = f.venue
	title_fight = f.title
	title_holder = -1
	if f.title and not f.vacant:
		title_holder = 0 if is_champion(f.red) else 1
	purse = f.purse


## Adds a finished fight to the boxers' records, pays the purse and updates
## the rankings and the title. [param result] is FightSim.result. Returns a
## summary: {"draw", "winner", "loser", "new_champion", "retained",
## "winner_purse", "loser_purse"}.
func record_fight(fight_red: BoxerData, fight_blue: BoxerData, result: Dictionary, title: bool, fight_purse: int) -> Dictionary:
	return Season.record_result(rankings, fight_red, fight_blue, result, title, fight_purse)


## Builds every division: the boxers are generated (middleweights first so
## their roster never changes when other divisions are added; surnames and
## nicknames unique across all divisions), put in their starting ranking
## order (see _standing), given managers and career earnings, and the best
## man in each division is crowned champion.
func _build_rosters() -> void:
	rankings.resize(Divisions.count())
	var order := [Divisions.Id.MIDDLEWEIGHT, Divisions.Id.LIGHTWEIGHT, Divisions.Id.HEAVYWEIGHT]
	var used_names: Array[String] = []
	var used_nicknames: Array[String] = []
	var business := BoxerGenerator.new(BUSINESS_SEED + int(options.get("roster", 0)))
	var business_rng := RandomNumberGenerator.new()
	business_rng.seed = BUSINESS_SEED
	var used_managers: Array[String] = []
	var next_id := 1
	for id in order:
		var seed_value: int = Divisions.get_division(id)["roster_seed"]
		if options.has("roster"):
			seed_value = int(options["roster"]) + id * 2
		var roster := BoxerGenerator.new(seed_value).generate_roster(ROSTER_SIZE, id, used_names, used_nicknames)
		for b in roster:
			used_names.append(b.last_name)
			if not b.nickname.is_empty():
				used_nicknames.append(b.nickname)
		roster.sort_custom(func(a: BoxerData, b: BoxerData) -> bool: return _standing(a) > _standing(b))
		var table := Rankings.new(id, roster, ranking_mode)
		for i in roster.size():
			var b: BoxerData = table.boxers[i]
			b.id = next_id
			next_id += 1
			b.manager = business.generate_manager(b, used_managers)
			used_managers.append("%s %s" % [b.manager.first_name, b.manager.last_name])
			b.earnings = Career.estimate_earnings(b, i, roster.size(), table.is_champion(b), business_rng)
			b.birth_month = business_rng.randi_range(0, 11)
		rankings[id] = table


## Starting ranking order: mostly ability, then a good record and
## experience; a man past his best (over 34) loses a little ground.
static func _standing(b: BoxerData) -> float:
	var fights := b.total_fights()
	var win_rate := float(b.wins) / fights if fights > 0 else 0.5
	return b.overall() + 10.0 * (win_rate - 0.75) + minf(fights, 30.0) * 0.4 - maxf(b.age - 34.0, 0.0)


## A seed for the fight itself (punch luck, AI choices).
func fight_seed() -> int:
	return _rng.randi() % 1000000


func _parse_options() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
