class_name BoxerGenerator
extends RefCounted
## Creates random boxers.
##
## Where a boxer comes from, and therefore what he is called, is driven by
## res://data/world.json so new countries or names can be added without
## touching code. Skills are rolled around a style "template" so, for example,
## an Evasive boxer usually has good stamina and a Slugger usually has power.

const WORLD_PATH := "res://data/world.json"

## Share of a roster that gets a nickname (inclusive range).
const NICKNAME_MIN_SHARE := 0.40
const NICKNAME_MAX_SHARE := 0.50

## How each style shifts the six skills away from an average of 0.
## Order: power, speed, stamina, chin, strength, intelligence.
const STYLE_BIAS := {
	BoxerData.Style.BRAWLER: [ 8,  -2,   2,  10,  10,  -6],
	BoxerData.Style.SLUGGER: [12,  -6,  -4,   8,   6,  -8],
	BoxerData.Style.BOXER:   [-2,   8,   4,  -2,  -2,   8],
	BoxerData.Style.COUNTER: [ 4,   6,  -2,   0,  -4,  12],
	BoxerData.Style.EVASIVE: [-6,  10,  12,  -4,  -4,   6],
}

var _rng := RandomNumberGenerator.new()
var _world: Dictionary = {}


func _init(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_world = _load_world()


## Builds a roster of [param count] unique-looking boxers. Between 40% and 50%
## of them (rounded sensibly) are given a nickname.
func generate_roster(count: int) -> Array[BoxerData]:
	var roster: Array[BoxerData] = []
	var used_trunks: Array[int] = []
	var used_names: Array[String] = []

	for i in count:
		var boxer := generate_boxer(used_trunks)
		# Avoid two boxers with the same surname in one small roster.
		var attempts := 0
		while used_names.has(boxer.last_name) and attempts < 10:
			boxer = generate_boxer(used_trunks)
			attempts += 1
		used_trunks.append(boxer.trunks_index)
		used_names.append(boxer.last_name)
		roster.append(boxer)

	_assign_nicknames(roster)
	return roster


## Builds a single random boxer. Trunk colours already in [param avoid_trunks]
## are skipped (while there are colours left) so fighters look different.
func generate_boxer(avoid_trunks: Array[int] = []) -> BoxerData:
	var b := BoxerData.new()

	# --- Where he is from, and his name ----------------------------------------
	var code := _pick_country_code()
	var country: Dictionary = _world["countries"][code]
	b.country_code = code
	b.country = country["name"]
	b.city = _pick(country["cities"])
	b.first_name = _pick(country["first"])
	b.last_name = _pick(country["last"])

	# --- Body -----------------------------------------------------------------
	b.height_cm = _rng.randi_range(BoxerData.MIN_HEIGHT_CM, BoxerData.MAX_HEIGHT_CM)
	b.weight_lb = _rng.randi_range(BoxerData.MIN_WEIGHT_LB, BoxerData.MAX_WEIGHT_LB)
	b.skin_index = _rng.randi_range(0, Palette.SKIN_TONES.size() - 1)
	b.hair_index = _rng.randi_range(0, Palette.HAIR_TONES.size() - 1)
	b.hair_style = _rng.randi_range(0, Palette.HAIR_STYLES.size() - 1)
	b.boots_index = _rng.randi_range(0, Palette.BOOTS.size() - 1)
	b.trunks_index = _pick_trunks(avoid_trunks)

	# --- Fighting style and skills ---------------------------------------------
	b.style = _rng.randi_range(0, BoxerData.STYLE_NAMES.size() - 1) as BoxerData.Style
	var bias: Array = STYLE_BIAS[b.style]
	b.power        = _roll_skill(bias[0])
	b.speed        = _roll_skill(bias[1])
	b.stamina      = _roll_skill(bias[2])
	b.chin         = _roll_skill(bias[3])
	b.strength     = _roll_skill(bias[4])
	b.intelligence = _roll_skill(bias[5])
	b.recovery     = _roll_skill(0)

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


func _assign_nicknames(roster: Array[BoxerData]) -> void:
	var n := roster.size()
	if n == 0:
		return
	# Work out how many boxers get a nickname, staying inside 40% - 50%.
	var low := ceili(n * NICKNAME_MIN_SHARE)
	var high := floori(n * NICKNAME_MAX_SHARE)
	var wanted := _rng.randi_range(mini(low, high), maxi(low, high))

	var order: Array = range(n)
	_shuffle(order)
	var used: Array[String] = []
	for i in wanted:
		var boxer: BoxerData = roster[order[i]]
		var style_key: String = BoxerData.STYLE_NAMES[boxer.style].to_upper()
		var pool: Array = _world["nicknames"][style_key]
		var nick: String = _pick(pool)
		var attempts := 0
		while used.has(nick) and attempts < 10:
			nick = _pick(pool)
			attempts += 1
		used.append(nick)
		boxer.nickname = nick


func _pick(list: Array) -> Variant:
	return list[_rng.randi_range(0, list.size() - 1)]


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = list[i]
		list[i] = list[j]
		list[j] = tmp
