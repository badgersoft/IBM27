class_name PunchTypes
extends RefCounted
## The punches and the numbers that make them different.
##
## The first COUNT are the standard punches every boxer throws. The last two
## are SPECIAL punches only a few boxers have (BoxerData.special_punch, at
## most one each): the OVERHAND right loops over the guard, the WINDMILL is
## a wild circling haymaker. Both hit hard and are often big, but they are
## slow and tiring, and easy to see coming (TELEGRAPH: the other man reacts
## and slips them more often).
##
## Columns line up by punch so the table can be read (and tuned) at a glance.
##                     JAB    CROSS  HOOK   UPPER  BODY   OVERH  WINDM

enum Type { JAB, CROSS, HOOK, UPPERCUT, BODY, OVERHAND, WINDMILL }

## The standard punches (Type 0 - COUNT - 1).
const COUNT := 5
const SPECIALS: Array[int] = [Type.OVERHAND, Type.WINDMILL]

const NAMES:       Array[String] = ["JAB",  "CROSS", "HOOK", "UPPERCUT", "BODY SHOT", "OVERHAND RIGHT", "WINDMILL"]
const ANIMS:       Array[String] = ["jab",  "cross", "hook", "uppercut", "body",      "overhand",       "windmill"]
## What the crowd sees when a special one lands (and its short name).
const SHORT:       Array[String] = ["JAB",  "CROSS", "HOOK", "UPPERCUT", "BODY",      "OVERHAND",       "WINDMILL"]

## Health damage before power, fatigue and luck are applied.
const DAMAGE:      Array[float] = [0.28,   0.66,   0.76,   0.85,   0.52,   1.07,   1.30]
## Energy the puncher spends throwing it.
const ENERGY_COST: Array[float] = [0.45,   1.05,   1.20,   1.35,   1.10,   1.70,   2.00]
## How much a clean one rattles the head (feeds into knockdowns).
const STUN:        Array[float] = [0.35,   1.00,   1.25,   1.45,   0.15,   1.60,   1.80]
## How much the judges like seeing it land clean.
const SCORE:       Array[float] = [0.70,   1.00,   1.10,   1.20,   0.90,   1.30,   1.25]
## Chance a high guard stops it (uppercuts come up through the gloves; a body
## shot can only be caught on the elbows of a boxer covering up; an overhand
## comes over the top of the guard).
const BLOCKABLE:   Array[float] = [0.95,   0.90,   0.80,   0.45,   0.40,   0.55,   0.75]
## Head shots can stun and knock down; body shots drain energy instead.
const TO_HEAD:     Array[bool]  = [true,   true,   true,   true,   false,  true,   true]
## How easy it is to see coming: extra chance the other man reacts to it and
## slips it.
const TELEGRAPH:   Array[float] = [0.00,   0.00,   0.00,   0.00,   0.00,   0.10,   0.18]
## Extra chance it lands as a big punch.
const BIG_BONUS:   Array[float] = [0.00,   0.00,   0.00,   0.00,   0.00,   0.06,   0.10]

static var _reach_cache: Array[float] = []


## How far in front of the boxer's centre this punch lands, in body heights.
## Measured from the actual impact pose so it always matches the animation.
static func reach(type: int) -> float:
	if _reach_cache.is_empty():
		for i in ANIMS.size():
			_reach_cache.append(BoxerPoses.reach(ANIMS[i]))
	return _reach_cache[type]


static func is_power_punch(type: int) -> bool:
	return type != Type.JAB


static func is_special(type: int) -> bool:
	return type >= COUNT
