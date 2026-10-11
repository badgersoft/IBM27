extends Node
## Global game state (autoloaded as "GameState").
##
## Holds the roster of boxers and the details of the next fight so that any
## scene can reach them. Nothing here is saved to disk yet.
##
## Command-line options (after "--") are read here too, which is handy for
## testing and for the screenshot tool:
##   --seed=<n>      fixed random seed for the roster and fight
##   --roster=<n>    use different starting rosters
##   --division=<0-2> force a division (0 light, 1 middle, 2 heavy)
##   --venue=<0-3>   force a venue (0 town gym, 1 city gym, 2 boxing hall, 3 grand arena)
##   --capture=<png> take a screenshot during the fight and quit (see CaptureTool)

## Boxers per division.
const ROSTER_SIZE := 10

## rosters[division] = that division's boxers. Each division's starting roster
## is the same every run (its roster_seed in Divisions; the middleweights use
## 1985, after the original game). Fights and venues are still random. Pass
## --roster=<n> for a different set of boxers.
var rosters: Array = []
var red: BoxerData
var blue: BoxerData
var division: int = Divisions.Id.MIDDLEWEIGHT
var venue_id := 0

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
	_build_rosters()


## The boxers in one division.
func boxers_in(division_id: int) -> Array[BoxerData]:
	return rosters[division_id]


## Picks a division, two different boxers from it, and a venue - all at random
## unless --division / --venue are given.
func new_fight() -> void:
	if options.has("division"):
		division = clampi(int(options["division"]), 0, Divisions.count() - 1)
	else:
		division = _rng.randi_range(0, Divisions.count() - 1)
	var roster := boxers_in(division)
	var first := _rng.randi_range(0, roster.size() - 1)
	var second := _rng.randi_range(0, roster.size() - 2)
	if second >= first:
		second += 1
	red = roster[first]
	blue = roster[second]
	if options.has("venue"):
		venue_id = clampi(int(options["venue"]), 0, Venues.count() - 1)
	else:
		venue_id = _rng.randi_range(0, Venues.count() - 1)


## Middleweights are generated first so their roster never changes when other
## divisions are added; surnames and nicknames are kept unique across all
## divisions.
func _build_rosters() -> void:
	rosters.resize(Divisions.count())
	var order := [Divisions.Id.MIDDLEWEIGHT, Divisions.Id.LIGHTWEIGHT, Divisions.Id.HEAVYWEIGHT]
	var used_names: Array[String] = []
	var used_nicknames: Array[String] = []
	for id in order:
		var seed_value: int = Divisions.get_division(id)["roster_seed"]
		if options.has("roster"):
			seed_value = int(options["roster"]) + id * 2
		var roster := BoxerGenerator.new(seed_value).generate_roster(ROSTER_SIZE, id, used_names, used_nicknames)
		for b in roster:
			used_names.append(b.last_name)
			if not b.nickname.is_empty():
				used_nicknames.append(b.nickname)
		rosters[id] = roster


## A seed for the fight itself (punch luck, AI choices).
func fight_seed() -> int:
	return _rng.randi() % 1000000


func _parse_options() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
