class_name Rivalries
extends RefCounted
## Rivalries and hype. Two men who have fought build up "heat" (0 - 100),
## worked out from their fights this season (nothing extra is saved):
##
##   each meeting     MEETING_HEAT, plus CLOSE_HEAT for a split or majority
##                    decision or a draw, KNOCKDOWN_HEAT a knockdown (up to
##                    MAX_KNOCKDOWN_HEAT) and TITLE_HEAT for a title fight,
##                    fading by half every HALF_LIFE months
##   every rematch    REMATCH_HEAT more
##
## At RIVALRY_HEAT or more a fight between them is a GRUDGE MATCH: a bigger
## purse (up to HYPE_PURSE more at full heat), a bigger venue, newspaper
## build-up, trash talk on the tale of the tape, and a crowd that boos the
## villain - the man who leads their series (the crowd wants to see him
## beaten), or if it is level the better-ranked one.

const MEETING_HEAT := 12.0
const CLOSE_HEAT := 18.0
const KNOCKDOWN_HEAT := 8.0
const MAX_KNOCKDOWN_HEAT := 24.0
const TITLE_HEAT := 15.0
const REMATCH_HEAT := 10.0
const HALF_LIFE := 18.0
const RIVALRY_HEAT := 35.0
const HYPE_PURSE := 0.5

## Trash talk (21 letters at most, so it fits a tale of the tape column
## at full size, quotes and all): from the man
## who won their last fight, and from the man out for revenge.
const WINNER_TALK: Array[String] = [
	"SAME RESULT, SOONER.", "HE KNOWS IT'S COMING.", "I OWN THIS GUY.",
	"BRING A STRETCHER.", "HE WANTS MORE? FINE.", "NO JUDGES NEEDED.",
]
const REVENGE_TALK: Array[String] = [
	"HE GOT LUCKY.", "IT'S PERSONAL NOW.", "I OWE HIM ONE.",
	"REVENGE IS MINE.", "HE'S ALL TALK.", "I'LL SHUT HIS MOUTH.",
]
const LEVEL_TALK: Array[String] = [
	"THIS SETTLES IT.", "ONE OF US GOES DOWN.", "NO MORE DRAWS.",
]


## 0 - 100: how much bad blood there is between [param a] and [param b].
static func heat(season: Season, a: BoxerData, b: BoxerData) -> float:
	if season == null or a == null or b == null:
		return 0.0
	var total := 0.0
	var meetings := 0
	for f in season.fixtures:
		if not f.is_done() or not f.involves(a) or not f.involves(b):
			continue
		meetings += 1
		var h := MEETING_HEAT
		var method: String = f.result.get("method", "")
		if method in ["SD", "MD", "DRAW"]:
			h += CLOSE_HEAT
		h += minf(KNOCKDOWN_HEAT * int(f.summary.get("knockdowns", 0)), MAX_KNOCKDOWN_HEAT)
		if f.title:
			h += TITLE_HEAT
		total += h * pow(0.5, maxf(season.month - f.month, 0) / HALF_LIFE)
	if meetings > 1:
		total += REMATCH_HEAT * (meetings - 1)
	return clampf(total, 0.0, 100.0)


static func is_rivalry(season: Season, a: BoxerData, b: BoxerData) -> bool:
	return heat(season, a, b) >= RIVALRY_HEAT


## How much bigger a fight between them pays (1.0 if they are not rivals).
static func purse_factor(season: Season, a: BoxerData, b: BoxerData) -> float:
	var h := heat(season, a, b)
	return 1.0 + HYPE_PURSE * h / 100.0 if h >= RIVALRY_HEAT else 1.0


## The man the crowd boos in a grudge match (null if it isn't one): the
## one who leads their series, or the better-ranked if it is level.
static func villain(season: Season, a: BoxerData, b: BoxerData) -> BoxerData:
	if not is_rivalry(season, a, b):
		return null
	var h := season.head_to_head(a, b)
	if h[0] != h[1]:
		return a if h[0] > h[1] else b
	var table := season.rankings_of(a)
	return a if table.index_of(a) <= table.index_of(b) else b


## Something [param me] says about [param other] before a grudge match.
static func trash_talk(season: Season, me: BoxerData, other: BoxerData, rng: RandomNumberGenerator) -> String:
	var last: Fixture = null
	for f in season.fixtures:
		if f.is_done() and f.involves(me) and f.involves(other):
			last = f
	var lines := LEVEL_TALK
	if last != null and last.winner() != null:
		lines = WINNER_TALK if last.winner() == me else REVENGE_TALK
	return lines[rng.randi_range(0, lines.size() - 1)]


## "II", "III"... for their [param meeting]th fight (2 and up).
static func numeral(meeting: int) -> String:
	var numerals: Array[String] = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return numerals[meeting] if meeting < numerals.size() else str(meeting)
