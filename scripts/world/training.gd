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
const MAX_SKILL := 97


## One month for [param b]; [param in_camp] if he has a fight within the
## next two months.
static func month(b: BoxerData, in_camp: bool) -> void:
	var age_change := 0.0
	for band in AGE_CHANGE:
		if b.age <= band[0]:
			age_change = band[1]
			break
	var training := TRAINING * (CAMP_BOOST if in_camp else 1.0)
	for skill in SKILLS:
		var change := age_change
		if change < 0.0:
			change *= FADE_SCALE.get(skill, 1.0)
		change += training
		var built: float = b.skill_progress.get(skill, 0.0) + change
		var whole := int(built)   # Towards zero, so -0.4 waits and -1.2 applies -1.
		if whole != 0:
			b.set(skill, clampi(int(b.get(skill)) + whole, MIN_SKILL, MAX_SKILL))
			built -= whole
		b.skill_progress[skill] = built
