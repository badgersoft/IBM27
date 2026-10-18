class_name FightLengths
extends RefCounted
## The four fight lengths. Every scorecard lays itself out for whichever
## length the fight has, so all four fit neatly.

const LIST: Array = [
	{"rounds":  3, "name": "Exhibition"},
	{"rounds":  6, "name": "Amateur"},
	{"rounds": 10, "name": "Semi-Pro"},
	{"rounds": 12, "name": "Professional"},
]
## Used until the game lets you choose (and for every fight in this build).
const DEFAULT_ROUNDS := 6


static func is_valid(rounds: int) -> bool:
	for entry in LIST:
		if entry["rounds"] == rounds:
			return true
	return false


## "Amateur" for 6 rounds, and so on.
static func level_name(rounds: int) -> String:
	for entry in LIST:
		if entry["rounds"] == rounds:
			return entry["name"]
	return ""
