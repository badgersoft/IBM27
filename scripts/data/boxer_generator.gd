class_name BoxerGenerator
extends RefCounted
## Creates random boxers.
##
## Where a boxer comes from, and therefore what he is called, is driven by
## res://data/world.json so new countries or names can be added without
## touching code. Skills are rolled around a style "template" so, for example,
## an Evasive boxer usually has good stamina and a Slugger usually has power.

const WORLD_PATH := "res://data/world.json"

## Career length limits for the made-up records.
const MIN_AGE := 20
const MAX_AGE := 37
const MAX_FIGHTS := 50

## Share of a roster that gets a nickname (inclusive range).
const NICKNAME_MIN_SHARE := 0.40
const NICKNAME_MAX_SHARE := 0.50
## Longest nickname allowed, so "THE ESCAPE ARTIST" in quotes fits the tale
## of the tape, name plates and the Boxers table at full size.
const NICKNAME_MAX_CHARS := 18
## How often a nickname comes from each pool in world.json: one that suits the
## boxer's style, one that suits his division, or the general pool (which
## includes hometown nicknames). An empty pool hands over to the others.
const NICKNAME_POOL_WEIGHTS := {"style": 0.5, "division": 0.3, "any": 0.2}

## How each style shifts the six skills away from an average of 0.
## Order: power, speed, stamina, chin, strength, intelligence.
const STYLE_BIAS := {
	BoxerData.Style.BRAWLER: [ 8,  -2,   2,  10,  10,  -6],
	BoxerData.Style.SLUGGER: [12,  -6,  -4,   8,   6,  -8],
	BoxerData.Style.BOXER:   [-2,   8,   4,  -2,  -2,   8],
	BoxerData.Style.COUNTER: [ 4,   6,  -2,   0,  -4,  12],
	BoxerData.Style.EVASIVE: [-6,  10,  12,  -4,  -4,   6],
	BoxerData.Style.SHOWBOAT:[ 0,  12,  -2,  -4,  -2,  -2],
}
## Showboats are rare: one or two in a full roster (smaller groups, such as
## the simulator's pairs, get one now and then).
const SHOWBOATS_PER_ROSTER := Vector2i(1, 2)
const SHOWBOAT_CHANCE := 0.15

var _rng := RandomNumberGenerator.new()
var _world: Dictionary = {}


func _init(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_world = _load_world()


## Builds a roster of [param count] unique-looking boxers in [param division].
## Between 40% and 50% of them (rounded sensibly) are given a nickname.
## Surnames in [param avoid_names] and nicknames in [param avoid_nicknames]
## (e.g. other divisions' boxers) are skipped, so both stay unique game-wide.
func generate_roster(count: int, division: Divisions.Id = Divisions.Id.MIDDLEWEIGHT,
		avoid_names: Array[String] = [], avoid_nicknames: Array[String] = []) -> Array[BoxerData]:
	var roster: Array[BoxerData] = []
	var used_trunks: Array[int] = []
	var used_names: Array[String] = avoid_names.duplicate()

	for i in count:
		var boxer := generate_boxer(used_trunks, division)
		# Avoid two boxers with the same surname.
		var attempts := 0
		while used_names.has(boxer.last_name) and attempts < 10:
			boxer = generate_boxer(used_trunks, division)
			attempts += 1
		used_trunks.append(boxer.trunks_index)
		used_names.append(boxer.last_name)
		roster.append(boxer)

	_assign_showboats(roster)
	_assign_nicknames(roster, avoid_nicknames)
	return roster


## Builds a single random boxer. Trunk colours already in [param avoid_trunks]
## are skipped (while there are colours left) so fighters look different.
func generate_boxer(avoid_trunks: Array[int] = [], division: Divisions.Id = Divisions.Id.MIDDLEWEIGHT) -> BoxerData:
	var b := BoxerData.new()
	b.division = division

	# --- Where he is from, and his name ----------------------------------------
	var code := _pick_country_code()
	var country: Dictionary = _world["countries"][code]
	b.country_code = code
	b.country = country["name"]
	b.city = _pick(country["cities"])
	b.first_name = _pick(country["first"])
	b.last_name = _pick(country["last"])

	# --- Body -----------------------------------------------------------------
	_roll_size(b)
	b.skin_index = _rng.randi_range(0, Palette.SKIN_TONES.size() - 1)
	b.hair_index = _rng.randi_range(0, Palette.HAIR_TONES.size() - 1)
	b.hair_style = _rng.randi_range(0, Palette.HAIR_STYLES.size() - 1)
	b.boots_index = _rng.randi_range(0, Palette.BOOTS.size() - 1)
	b.trunks_index = _pick_trunks(avoid_trunks)

	# --- Fighting style and skills ---------------------------------------------
	# Showboats are added afterwards, a few per roster (_assign_showboats).
	b.style = _rng.randi_range(0, BoxerData.Style.SHOWBOAT - 1) as BoxerData.Style
	_roll_skills(b)

	# --- Career record (placeholder) ------------------------------------------------
	_roll_record(b)

	# --- Condition ---------------------------------------------------------------
	# Fitter boxers (stamina) with a higher pain threshold (strength, chin) start
	# a little healthier. Nobody starts at a perfect 100.
	var fitness := (b.stamina * 0.5 + b.strength * 0.3 + b.chin * 0.2) / 99.0
	b.start_health = clampf(84.0 + fitness * 12.0 + _rng.randf_range(-3.0, 3.0), 82.0, 98.0)
	b.start_health = snappedf(b.start_health, 0.1)
	return b


# ----------------------------------------------------------------------------
#  Helpers
# ----------------------------------------------------------------------------

## Height and weight inside the boxer's division.
##
## Heavyweights have no upper limit in real life. Most are well-toned men in
## the lower half of the 200 - 290 lb range, with a few big men near the top:
## the weight is skewed towards the light end (a power curve on a random
## roll), and taller men tend to be heavier.
func _roll_size(b: BoxerData) -> void:
	var div := Divisions.get_division(b.division)
	var h: Array = div["height_cm"]
	var w: Array = div["weight_lb"]
	b.height_cm = _rng.randi_range(h[0], h[1])
	if b.division == Divisions.Id.HEAVYWEIGHT:
		var tall := inverse_lerp(float(h[0]), float(h[1]), b.height_cm)
		var roll := clampf(_rng.randf() * 0.75 + tall * 0.25, 0.0, 1.0)
		b.weight_lb = clampi(roundi(lerpf(w[0], w[1], pow(roll, 1.8))), w[0], w[1])
	else:
		b.weight_lb = _rng.randi_range(w[0], w[1])


## Makes up a believable professional record:
##  - older boxers have had more fights (about 1.5 - 3.5 a year since turning pro
##    at 18 - 23), never more than MAX_FIGHTS;
##  - better boxers (higher average skill) win a bigger share;
##  - draws are rare;
##  - harder punchers finish more of their wins inside the distance.
func _roll_record(b: BoxerData) -> void:
	b.age = _rng.randi_range(MIN_AGE, MAX_AGE)
	var pro_debut := _rng.randi_range(18, 23)
	var years := maxi(b.age - pro_debut, 0)
	# Even the youngest prospect has a handful of pro fights behind him.
	var fights := clampi(roundi(years * _rng.randf_range(1.5, 3.5)) + _rng.randi_range(3, 5), 3, MAX_FIGHTS)

	var skill := ((b.power + b.speed + b.stamina + b.chin + b.strength + b.intelligence) / 6.0 - 40.0) / 45.0
	var win_rate := clampf(0.55 + clampf(skill, 0.0, 1.0) * 0.42 + _rng.randf_range(-0.08, 0.08), 0.40, 0.98)
	b.draws = 0
	for i in fights - 3:   # Nobody starts a career with a run of draws.
		if _rng.randf() < 0.03:
			b.draws += 1
	b.wins = clampi(roundi((fights - b.draws) * win_rate), 0, fights - b.draws)
	b.losses = fights - b.draws - b.wins

	var ko_bias: float = Divisions.get_division(b.division)["ko_bias"]
	var ko_rate := clampf(0.12 + b.power / 99.0 * 0.65 + ko_bias + _rng.randf_range(-0.08, 0.08), 0.05, 0.92)
	b.kos = clampi(roundi(b.wins * ko_rate), 0, b.wins)


func _load_world() -> Dictionary:
	var file := FileAccess.open(WORLD_PATH, FileAccess.READ)
	if file == null:
		push_error("BoxerGenerator: could not open %s" % WORLD_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("BoxerGenerator: %s is not valid JSON" % WORLD_PATH)
		return {}
	return parsed


## Picks a region using the percentage weights, then a country inside it.
func _pick_country_code() -> String:
	var regions: Array = _world["regions"]
	var total := 0.0
	for region in regions:
		total += float(region["weight"])
	var roll := _rng.randf() * total
	for region in regions:
		roll -= float(region["weight"])
		if roll <= 0.0:
			return _pick(region["countries"])
	return _pick(regions[-1]["countries"])


## Skills centre on 60 with a spread of roughly +-15, nudged by style.
## Most land between 35 and 85; a rare few dip under 30 as asked.
## The six skills (and recovery), centred on the style's strengths.
func _roll_skills(b: BoxerData) -> void:
	var bias: Array = STYLE_BIAS[b.style]
	b.power        = _roll_skill(bias[0])
	b.speed        = _roll_skill(bias[1])
	b.stamina      = _roll_skill(bias[2])
	b.chin         = _roll_skill(bias[3])
	b.strength     = _roll_skill(bias[4])
	b.intelligence = _roll_skill(bias[5])
	b.recovery     = _roll_skill(0)


## Turns one or two boxers in a roster into showboats: they keep their name
## and body but get a showboat's skills and a career to match.
func _assign_showboats(roster: Array[BoxerData]) -> void:
	var picks: Array = []
	if roster.size() >= 6:
		var order: Array = range(roster.size())
		_shuffle(order)
		picks = order.slice(0, _rng.randi_range(SHOWBOATS_PER_ROSTER.x, SHOWBOATS_PER_ROSTER.y))
	else:
		for i in roster.size():
			if _rng.randf() < SHOWBOAT_CHANCE:
				picks.append(i)
	for i in picks:
		var b: BoxerData = roster[i]
		b.style = BoxerData.Style.SHOWBOAT
		_roll_skills(b)
		_roll_record(b)


func _roll_skill(bias: int) -> int:
	var value := _rng.randfn(60.0 + bias, 13.0)
	return clampi(roundi(value), 20, 97)


func _pick_trunks(avoid: Array[int]) -> int:
	var options: Array[int] = []
	for i in Palette.TRUNKS.size():
		if not avoid.has(i):
			options.append(i)
	if options.is_empty():
		return _rng.randi_range(0, Palette.TRUNKS.size() - 1)
	return options[_rng.randi_range(0, options.size() - 1)]


func _assign_nicknames(roster: Array[BoxerData], avoid: Array[String]) -> void:
	var n := roster.size()
	if n == 0:
		return
	# Work out how many boxers get a nickname, staying inside 40% - 50%.
	var low := ceili(n * NICKNAME_MIN_SHARE)
	var high := floori(n * NICKNAME_MAX_SHARE)
	var wanted := _rng.randi_range(mini(low, high), maxi(low, high))

	var order: Array = range(n)
	_shuffle(order)
	var used: Array[String] = avoid.duplicate()
	for i in wanted:
		var boxer: BoxerData = roster[order[i]]
		boxer.nickname = _pick_nickname(boxer, used)
		if not boxer.nickname.is_empty():
			used.append(boxer.nickname)


## A nickname nobody in [param used] has, from a pool chosen by
## NICKNAME_POOL_WEIGHTS. Returns "" only if every pool is used up.
func _pick_nickname(boxer: BoxerData, used: Array[String]) -> String:
	var pools := {
		"style": _nickname_options(_world["nicknames"]["style"][BoxerData.STYLE_NAMES[boxer.style].to_upper()], boxer, used),
		"division": _nickname_options(_world["nicknames"]["division"][boxer.division_name().to_upper()], boxer, used),
		"any": _nickname_options(_world["nicknames"]["any"], boxer, used),
	}
	var total := 0.0
	for key in pools:
		if not (pools[key] as Array).is_empty():
			total += float(NICKNAME_POOL_WEIGHTS[key])
	if total <= 0.0:
		return ""
	var roll := _rng.randf() * total
	for key in pools:
		var options: Array = pools[key]
		if options.is_empty():
			continue
		roll -= float(NICKNAME_POOL_WEIGHTS[key])
		if roll <= 0.0:
			return _pick(options)
	return _pick(pools["any"] if not (pools["any"] as Array).is_empty() else pools["style"])


## The nicknames in [param pool] still free for [param boxer]: hometown ones
## filled in with his city, anything too long or already taken left out.
func _nickname_options(pool: Array, boxer: BoxerData, used: Array[String]) -> Array:
	var out: Array = []
	for entry in pool:
		var nick := str(entry).replace("{city}", boxer.city)
		if nick.length() <= NICKNAME_MAX_CHARS and not used.has(nick):
			out.append(nick)
	return out


func _pick(list: Array) -> Variant:
	return list[_rng.randi_range(0, list.size() - 1)]


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp
