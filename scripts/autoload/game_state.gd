extends Node
## Global game state (autoloaded as "GameState").
##
## Holds the roster of boxers and the details of the next fight so that any
## scene can reach them. Nothing here is saved to disk yet.
##
## Command-line options (after "--") are read here too, which is handy for
## testing and for the screenshot tool:
##   --seed=<n>      fixed random seed for the roster and fight
##   --roster=<n>    use a different starting roster
##   --venue=<0-3>   force a venue (0 town gym, 1 city gym, 2 boxing hall, 3 grand arena)
##   --capture=<png> take a screenshot during the fight and quit (see CaptureTool)

const ROSTER_SIZE := 5
## The starting roster is the same five boxers every time the game is run
## (1985, after the original game). Fights and venues are still random.
## Change this, or pass --roster=<n>, for a different set of boxers.
const ROSTER_SEED := 1985

var roster: Array[BoxerData] = []
var red: BoxerData
var blue: BoxerData
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
	var roster_seed := int(options.get("roster", ROSTER_SEED))
	roster = BoxerGenerator.new(roster_seed).generate_roster(ROSTER_SIZE)


## Picks two different boxers from the roster at random, and a venue.
func new_fight() -> void:
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


## A seed for the fight itself (punch luck, AI choices).
func fight_seed() -> int:
	return _rng.randi() % 1000000


func _parse_options() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
