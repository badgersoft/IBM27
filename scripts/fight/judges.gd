class_name Judges
extends RefCounted
## The three official judges for a fight, plus the TV pundit's unofficial card.
##
## How a judge scores a round (10-point must system):
##  1. Each boxer's "work" in the round is valued using the judge's SECRET
##     likes (attacking, defence, punches landed, punches thrown, power).
##  2. The difference becomes a share of the round (-1 .. +1, + = red).
##  3. Fairness decides how far the judge strays from what they saw:
##     - every round gets a little personal noise (bigger for unfair judges);
##     - every fight the judge has a lean towards one boxer, strongest when a
##       boxer comes from the judge's own country ("home cooking").
##  4. Clear share = 10-9; a hair either way = 10-10; knockdowns decide the
##     round for the boxer who scored them (see _ten_point).
##
## The official cards are SECRET until the final bell. During the fight the
## screen shows the pundit's card instead: scored like a neutral judge, with a
## little noise depending on the pundit's accuracy, so it is a good but not
## perfect guide to how a fair judge would see it.

## How a perfectly neutral official values each part of a round.
const NEUTRAL_LIKES := {"attack": 0.25, "defence": 0.25, "landed": 1.00, "thrown": 0.10, "power": 0.60}

## Below this share of the round the round is scored even (10-10).
const EVEN_ROUND := 0.004
## A knockdown round only goes 10-8 when its scorer also clearly won the rest
## of the round by at least this share.
const CLEAR_ROUND := 0.12

## Round-to-round noise for the fairest (99) and least fair (1) judge.
const NOISE_FAIREST := 0.03
const NOISE_WILDEST := 0.16
## Per-fight lean: random favouritism and home-country bias at fairness 1.
const LEAN_RANDOM := 0.08
const LEAN_HOME := 0.18
## Round-to-round error for the most (99) and least (1) accurate pundit.
const PUNDIT_NOISE_BEST := 0.01
const PUNDIT_NOISE_WORST := 0.30

var rounds: int
var panel: Array = []          ## The three judges (see Officials).
var pundit: Dictionary = {}

## cards[judge][round] = [red_points, blue_points], or [] if not yet scored.
var cards: Array = []
## pundit_card[round], same format.
var pundit_card: Array = []
## A perfectly neutral card with no noise - used by the balance tool to spot
## "unexpected" decisions. Never shown in game.
var fair_card: Array = []

var _noise: Array = []          # [judge][round] share offset.
var _lean: Array = []           # [judge] share offset, + favours red.
var _pundit_noise: Array = []   # [round] share offset.


func _init(total_rounds: int, judges_panel: Array, pundit_info: Dictionary,
		red: BoxerData, blue: BoxerData, rng: RandomNumberGenerator) -> void:
	rounds = total_rounds
	panel = judges_panel
	pundit = pundit_info

	for judge in panel:
		var unfair := 1.0 - float(judge["fairness"]) / 99.0
		var spread := lerpf(NOISE_FAIREST, NOISE_WILDEST, unfair)
		var round_noise: Array = []
		for r in rounds:
			round_noise.append(rng.randfn(0.0, spread))
		_noise.append(round_noise)

		var home := 0.0
		if judge["country"] == red.country_code and judge["country"] != blue.country_code:
			home = 1.0
		elif judge["country"] == blue.country_code and judge["country"] != red.country_code:
			home = -1.0
		_lean.append(unfair * (home * LEAN_HOME + rng.randf_range(-1.0, 1.0) * LEAN_RANDOM))
		cards.append(_empty_card())

	var pundit_spread := lerpf(PUNDIT_NOISE_BEST, PUNDIT_NOISE_WORST, 1.0 - float(pundit.get("accuracy", 80)) / 99.0)
	for r in rounds:
		_pundit_noise.append(rng.randfn(0.0, pundit_spread))
	pundit_card = _empty_card()
	fair_card = _empty_card()


# ----------------------------------------------------------------------------
#  Scoring a round
# ----------------------------------------------------------------------------

## How an official with [param likes] values one boxer's round stats.
static func work(likes: Dictionary, s: Dictionary) -> float:
	return s["score"] * likes["landed"] \
		+ s["damage"] * likes["power"] \
		+ s["pressure"] * 1.5 * likes["attack"] \
		+ s["evaded"] * 1.5 * likes["defence"] \
		+ s["thrown"] * 0.5 * likes["thrown"]


## Official judge [param judge]'s score for a round, from the stats so far.
func score_round(judge: int, round_index: int, red: Fighter, blue: Fighter) -> Array:
	var share: float = _share(panel[judge]["likes"], red, blue) + _noise[judge][round_index] + _lean[judge]
	return _ten_point(share, red, blue)


## The pundit's score for a round (also used live for the round in progress).
func pundit_round(round_index: int, red: Fighter, blue: Fighter) -> Array:
	return _ten_point(_share(NEUTRAL_LIKES, red, blue) + _pundit_noise[round_index], red, blue)


## Locks in every card for a finished round.
func finalise_round(round_index: int, red: Fighter, blue: Fighter) -> void:
	for j in panel.size():
		cards[j][round_index] = score_round(j, round_index, red, blue)
	pundit_card[round_index] = pundit_round(round_index, red, blue)
	fair_card[round_index] = _ten_point(_share(NEUTRAL_LIKES, red, blue), red, blue)


# ----------------------------------------------------------------------------
#  Totals
# ----------------------------------------------------------------------------

## [red_total, blue_total] on an official card.
func totals(judge: int) -> Array:
	return _sum(cards[judge])


## [red_total, blue_total] on the pundit's card. Pass the round in progress to
## include the pundit's live view of it.
func pundit_totals(live_round: int = -1, red: Fighter = null, blue: Fighter = null) -> Array:
	var card := pundit_card.duplicate()
	if live_round >= 0 and red != null and card[live_round].is_empty():
		card[live_round] = pundit_round(live_round, red, blue)
	return _sum(card)


func fair_totals() -> Array:
	return _sum(fair_card)


## Number of official judges favouring each corner: [red, blue, even].
func tally() -> Array:
	var out := [0, 0, 0]
	for j in panel.size():
		var t := totals(j)
		if t[0] > t[1]:
			out[0] += 1
		elif t[1] > t[0]:
			out[1] += 1
		else:
			out[2] += 1
	return out


# ----------------------------------------------------------------------------
#  Helpers
# ----------------------------------------------------------------------------

func _empty_card() -> Array:
	var card: Array = []
	for r in rounds:
		card.append([])
	return card


## -1 .. +1: how much of the round went to red (+) or blue (-).
func _share(likes: Dictionary, red: Fighter, blue: Fighter) -> float:
	var red_work := work(likes, red.round_stats)
	var blue_work := work(likes, blue.round_stats)
	return (red_work - blue_work) / maxf(red_work + blue_work, 0.001)


## Turns a share of the round into a 10-point must score.
##
## Knockdowns decide a round the way real judges score them: the boxer who
## scored more knockdowns wins it - 10-8 if he was clearly winning the round
## anyway, otherwise 10-9 - and every extra
## knockdown costs another point. Without knockdowns the share decides it,
## with a 10-10 only when there is next to nothing in it.
func _ten_point(share: float, red: Fighter, blue: Fighter) -> Array:
	var kd_margin := blue.knockdowns_round - red.knockdowns_round   # + = red scored more.
	if kd_margin == 0:
		if share > EVEN_ROUND:
			return [10, 9]
		if share < -EVEN_ROUND:
			return [9, 10]
		return [10, 10]
	var red_scored := kd_margin > 0
	var also_won_round := share > CLEAR_ROUND if red_scored else share < -CLEAR_ROUND
	var other := 9 - (absi(kd_margin) - 1) - (1 if also_won_round else 0)
	other = clampi(other, 6, 9)
	return [10, other] if red_scored else [other, 10]


static func _sum(card: Array) -> Array:
	var red_total := 0
	var blue_total := 0
	for score in card:
		if not score.is_empty():
			red_total += score[0]
			blue_total += score[1]
	return [red_total, blue_total]
