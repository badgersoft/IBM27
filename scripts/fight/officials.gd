class_name Officials
extends RefCounted
## Loads the pool of ringside judges and TV pundits from
## res://data/officials.json and picks the officials for a fight.
##
## A judge is a Dictionary:
##   name      "Harold Pemberton"
##   country   "GBR"
##   fairness  1 - 99, PUBLIC (shown as FAIR / SO-SO / WILD)
##   likes     { attack, defence, landed, thrown, power } - SECRET, never shown
##
## A pundit is a Dictionary: name, accuracy (1 - 99).

const PATH := "res://data/officials.json"

## Fairness bands (public labels).
const FAIR_FROM := 70
const SO_SO_FROM := 40

static var _data: Dictionary = {}


## Three different judges at random.
static func pick_judges(rng: RandomNumberGenerator, count: int = 3) -> Array:
	var pool: Array = _load()["judges"].duplicate()
	var picked: Array = []
	for i in mini(count, pool.size()):
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


static func pick_pundit(rng: RandomNumberGenerator) -> Dictionary:
	var pundits: Array = _load()["pundits"]
	return pundits[rng.randi_range(0, pundits.size() - 1)]


static func all_judges() -> Array:
	return _load()["judges"]


## "FAIR", "SO-SO" or "WILD".
static func fairness_label(fairness: int) -> String:
	if fairness >= FAIR_FROM:
		return "FAIR"
	if fairness >= SO_SO_FROM:
		return "SO-SO"
	return "WILD"


static func fairness_color(fairness: int) -> Color:
	if fairness >= FAIR_FROM:
		return Palette.UI_GOOD
	if fairness >= SO_SO_FROM:
		return Palette.UI_WARN
	return Palette.UI_BAD


## Surname for tight table columns: "Maria Delgado-Ruiz" -> "DELGADO-RUIZ".
static func surname(person: Dictionary) -> String:
	var parts: PackedStringArray = str(person["name"]).split(" ")
	return parts[parts.size() - 1].to_upper()


## Initial and surname: "Maria Delgado-Ruiz" -> "M. DELGADO-RUIZ".
static func short_name(person: Dictionary) -> String:
	var name := str(person["name"])
	return "%s. %s" % [name.substr(0, 1).to_upper(), surname(person)]


static func _load() -> Dictionary:
	if not _data.is_empty():
		return _data
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("Officials: could not open %s" % PATH)
		return {"judges": [], "pundits": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Officials: %s is not valid JSON" % PATH)
		return {"judges": [], "pundits": []}
	_data = parsed
	return _data
