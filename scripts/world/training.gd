class_name Training
extends RefCounted
## A month of training and getting older, for every boxer.
##
## Each month every skill moves by a fraction of a point: training adds
## TRAINING a month (half as much again, CAMP_BOOST, in the two-month camp
## before a fight), and age adds to it or takes away (AGE_CHANGE): young men
## are still improving, men in their prime hold steady, and from 32 the
## skills start to fade, speed fastest. Whole points are applied as the
## fractions build up (BoxerData.skill_progress), so a skill moves a point
## at a time. Skills stay between MIN_SKILL and MAX_SKILL.
##
## For the computer's boxers the gains (training and youth) get smaller as
## a skill climbs past NPC_ROOM_FROM - (MAX_SKILL - skill) / (MAX_SKILL -
## NPC_ROOM_FROM) to the power NPC_ROOM_POWER - so a prospect improves
## quickly while he is raw but levels off in the 70s unless he was gifted
## to begin with, and the divisions don't all grow stronger year after year.
## (The player's boxer has his own curve: Facilities.)

const SKILLS: Array[String] = ["power", "speed", "stamina", "chin", "strength", "intelligence"]
const TRAINING := 0.12
const CAMP_BOOST := 1.5
## [up to this age, change a month].
const AGE_CHANGE: Array = [
	[23,  0.22],
	[27,  0.08],
	[31,  0.00],
	[34, -0.20],
	[99, -0.35],
]
## Speed fades faster with age, intelligence (experience) slower.
const FADE_SCALE := {"speed": 1.5, "intelligence": 0.4}
const MIN_SKILL := 20
const NPC_ROOM_FROM := 60.0
const NPC_ROOM_POWER := 2.0
## The champion and the men ranked in the top TOP_PLACES train like the
## player does in the best gyms: TOP_TRAINING times the gains, and still
## climbing until a skill reaches TOP_ROOM_FROM - so the men at the top of a
## division keep improving and the title is a hard climb.
const TOP_PLACES := 5
const TOP_TRAINING := 1.8
const TOP_ROOM_FROM := 70.0
const MAX_SKILL := 97


## How much of a gain a computer boxer's skill of [param value] still takes,
## if his gains start to shrink from [param from] (NPC_ROOM_FROM, or
## TOP_ROOM_FROM for the men at the top).
static func _room(value: float, from: float) -> float:
	if value <= from:
		return 1.0
	return pow(maxf(MAX_SKILL - value, 0.0) / (MAX_SKILL - from), NPC_ROOM_POWER)


## One month for [param b]; [param in_camp] if he has a fight within the
## next two months, [param top] if he is the champion or in the top
## TOP_PLACES. The player's boxer ([param self_trained]) only gets the
## effect of his age: his training is the player's weekly choice
## (Facilities.train).
static func month(b: BoxerData, in_camp: bool, self_trained: bool = false, top: bool = false) -> void:
	var age_change := 0.0
	for band in AGE_CHANGE:
		if b.age <= band[0]:
			age_change = band[1]
			break
	var training := 0.0 if self_trained else TRAINING * (CAMP_BOOST if in_camp else 1.0) * (TOP_TRAINING if top else 1.0)
	for skill in SKILLS:
		var change := age_change
		if change < 0.0:
			change *= FADE_SCALE.get(skill, 1.0)
		change += training
		if change > 0.0 and not self_trained:
			change *= _room(float(b.get(skill)), TOP_ROOM_FROM if top else NPC_ROOM_FROM)
		var built: float = b.skill_progress.get(skill, 0.0) + change
		var whole := int(built)   # Towards zero, so -0.4 waits and -1.2 applies -1.
		if whole != 0:
			b.set(skill, clampi(int(b.get(skill)) + whole, MIN_SKILL, MAX_SKILL))
			built -= whole
		b.skill_progress[skill] = built
