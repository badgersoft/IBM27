class_name Facilities
extends RefCounted
## What a career boxer can rent by the week, and his weekly training.
##
##   TRAINING  where he trains: a better gym makes every session count for
##             more (boost).
##   RECOVERY  where he recovers between fights: a better one gets his
##             health back faster (boost).
## The cheapest of each is free; the rest cost [cost] dollars a week, paid
## when the week ends.

enum Kind { TRAINING, RECOVERY }
enum Session { WEIGHTS, SPEED, STAMINA, PUNCHING, RECOVERY }

const TRAINING: Array = [
	{"name": "Local Gym",           "cost": 0,     "boost": 1.0, "blurb": "A heavy bag, a rope and a mirror."},
	{"name": "Boxing Club",         "cost": 400,   "boost": 1.3, "blurb": "Proper rings and sparring partners."},
	{"name": "Fight Academy",       "cost": 2500,  "boost": 1.7, "blurb": "Specialist coaches for every skill."},
	{"name": "Performance Centre",  "cost": 12000, "boost": 2.2, "blurb": "Sports science and video analysis."},
	{"name": "Olympic Complex",     "cost": 50000, "boost": 3.0, "blurb": "Where the world's best prepare."},
]
const RECOVERY: Array = [
	{"name": "Local Day Spa",           "cost": 0,     "boost": 1.0, "blurb": "A sauna, a massage and a cup of tea."},
	{"name": "Physio Clinic",           "cost": 300,   "boost": 1.3, "blurb": "Hands-on treatment for the knocks."},
	{"name": "Sports Injury Clinic",    "cost": 2000,  "boost": 1.7, "blurb": "Scans, ice baths and specialists."},
	{"name": "Private Hospital",        "cost": 9000,  "boost": 2.2, "blurb": "Round-the-clock medical care."},
	{"name": "Elite Medical Institute", "cost": 40000, "boost": 3.0, "blurb": "The best doctors money can buy."},
]

## The kinds of session: [name, main skill, its share, second skill, its
## share, what it is shown as doing]. RECOVERY trains nothing: it is a week
## of rest and treatment that brings his health back (REST_RECOVERY).
const SESSIONS: Array = [
	["WEIGHTS",  "strength", 1.0, "chin",         0.5, "STRENGTH AND CHIN"],
	["SPEED",    "speed",    1.0, "intelligence", 0.4, "SPEED AND RING SENSE"],
	["STAMINA",  "stamina",  1.0, "recovery",     0.5, "STAMINA AND RECOVERY"],
	["PUNCHING", "power",    1.0, "intelligence", 0.4, "POWER AND TECHNIQUE"],
	["RECOVERY", "",         0.0, "",             0.0, "HEALTH AND ENERGY"],
]
## Skill points from one session at the Local Gym, for a skill of 50. Weak
## skills improve faster (CATCH_UP more per point under 50), strong ones
## slower, and a young man faster than an old one.
const SESSION_GAIN := 1.0
const CATCH_UP := 0.04
const MAX_SKILL := 97
## Condition (percent) back each week at the Local Day Spa, plus a share of
## his recovery skill.
const RECOVERY_BASE := 6.0
const RECOVERY_SKILL := 0.10
## A RECOVERY session gets back this many weeks' worth on top.
const REST_RECOVERY := 1.5


static func list(kind: Kind) -> Array:
	return TRAINING if kind == Kind.TRAINING else RECOVERY


## The skill points one [param session] would add to [param b]'s skills at
## facility [param gym]: {skill: points}.
static func session_gains(b: BoxerData, session: int, gym: int) -> Dictionary:
	var s: Array = SESSIONS[session]
	if session == Session.RECOVERY:
		return {}
	var boost: float = TRAINING[gym]["boost"]
	var youth := clampf(1.3 - (b.age - 20) * 0.03, 0.6, 1.3)
	var out := {}
	for k in [[s[1], s[2]], [s[3], s[4]]]:
		var skill: String = k[0]
		var value := float(b.get(skill))
		var room := clampf(1.0 + (50.0 - value) * CATCH_UP, 0.25, 2.5)
		out[skill] = SESSION_GAIN * float(k[1]) * boost * youth * room
	return out


## Trains [param b] for a week: the gains build up as fractions and whole
## points are added (see BoxerData.skill_progress). Returns the gains.
static func train(b: BoxerData, session: int, gym: int) -> Dictionary:
	var gains := session_gains(b, session, gym)
	for skill in gains:
		var built: float = b.skill_progress.get(skill, 0.0) + gains[skill]
		var whole := int(built)
		if whole > 0:
			b.set(skill, mini(int(b.get(skill)) + whole, MAX_SKILL))
			built -= whole
		b.skill_progress[skill] = built
	return gains


## Condition [param b] gets back in a week at recovery facility [param spa].
static func weekly_recovery(b: BoxerData, spa: int) -> float:
	return (RECOVERY_BASE + b.recovery * RECOVERY_SKILL) * float(RECOVERY[spa]["boost"])


## The extra condition a RECOVERY session gives [param b] at [param spa].
static func rest(b: BoxerData, spa: int) -> float:
	return weekly_recovery(b, spa) * REST_RECOVERY


## "FIT", "BRUISED", "HURT" or "INJURED" for a condition.
static func condition_text(condition: float) -> String:
	if condition >= 95.0:
		return "FIT"
	if condition >= 75.0:
		return "BRUISED"
	if condition >= 50.0:
		return "HURT"
	return "INJURED"
