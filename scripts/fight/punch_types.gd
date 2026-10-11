class_name PunchTypes
extends RefCounted
## The five punches and the numbers that make them different.
##
## Columns line up by punch so the table can be read (and tuned) at a glance.
##                     JAB    CROSS  HOOK   UPPER  BODY

enum Type { JAB, CROSS, HOOK, UPPERCUT, BODY }

const COUNT := 5

const NAMES:       Array[String] = ["JAB",  "CROSS", "HOOK", "UPPERCUT", "BODY SHOT"]
const ANIMS:       Array[String] = ["jab",  "cross", "hook", "uppercut", "body"]

## Health damage before power, fatigue and luck are applied.
const DAMAGE:      Array[float] = [0.28,   0.66,   0.76,   0.85,   0.52]
## Energy the puncher spends throwing it.
const ENERGY_COST: Array[float] = [0.45,   1.05,   1.20,   1.35,   1.10]
## How much a clean one rattles the head (feeds into knockdowns).
const STUN:        Array[float] = [0.35,   1.00,   1.25,   1.45,   0.15]
## How much the judges like seeing it land clean.
const SCORE:       Array[float] = [0.70,   1.00,   1.10,   1.20,   0.90]
## Chance a high guard stops it (uppercuts come up through the gloves; a body
## shot can only be caught on the elbows of a boxer covering up).
const BLOCKABLE:   Array[float] = [0.95,   0.90,   0.80,   0.45,   0.40]
## Head shots can stun and knock down; body shots drain energy instead.
const TO_HEAD:     Array[bool]  = [true,   true,   true,   true,   false]

static var _reach_cache: Array[float] = []


## How far in front of the boxer's centre this punch lands, in body heights.
## Measured from the actual impact pose so it always matches the animation.
static func reach(type: int) -> float:
	if _reach_cache.is_empty():
		for i in COUNT:
			_reach_cache.append(BoxerPoses.reach(ANIMS[i]))
	return _reach_cache[type]


static func is_power_punch(type: int) -> bool:
	return type != Type.JAB
