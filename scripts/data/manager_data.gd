class_name ManagerData
extends Resource
## A boxer's manager. Every boxer has his own, and the manager's type decides
## which fights he goes looking for when the season's fights are arranged.

enum Type { MONEY, PROTECTIVE, OLD_SCHOOL }

const TYPE_NAMES: Array[String] = ["Money Man", "Protective", "Old School"]
## One line for the boxer's profile (at most 40 characters).
const TYPE_BLURBS: Array[String] = [
	"Chases the biggest purse going.",
	"Picks easier fights to protect him.",
	"Will fight anyone, any time.",
]
## How common each type is (shares add up to 1).
const TYPE_SHARES: Array[float] = [0.40, 0.30, 0.30]

@export var first_name: String = ""
@export var last_name: String = ""
@export var type: Type = Type.OLD_SCHOOL


## "J. Marsh"
func short_name() -> String:
	return "%s. %s" % [first_name.substr(0, 1), last_name]


func type_name() -> String:
	return TYPE_NAMES[type]


func type_blurb() -> String:
	return TYPE_BLURBS[type]
