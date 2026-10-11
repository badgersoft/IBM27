class_name Judges
extends RefCounted
## Three ringside judges scoring on the 10-point must system.
##
## Each judge watches the same punches but values them a little differently
## (one loves clean punching, one loves pressure, one is in between) and adds a
## touch of personal opinion, so cards can disagree like they do in real life.
##
## Scoring will be expanded later; for now a round goes 10-9 to whoever did
## more, with a point off for every knockdown suffered.

const JUDGE_NAMES: Array[String] = ["JUDGE A", "JUDGE B", "JUDGE C"]

## Weights per judge: clean punching, damage, pressure, defence.
const STYLE_WEIGHTS: Array = [
	[1.00, 0.40, 0.10, 0.20],   # Judge A: clean punching purist.
	[0.80, 0.60, 0.35, 0.10],   # Judge B: likes the aggressor.
	[0.90, 0.50, 0.20, 0.15],   # Judge C: middle of the road.
]

## Below this share of the round's work the round is scored even (10-10).
const EVEN_ROUND := 0.015

var rounds: int
## cards[judge][round] = [red_points, blue_points], or [] if not yet scored.
var cards: Array = []

var _opinion: Array = []   # Per judge, per round: small random lean (-1 .. 1).


func _init(total_rounds: int, rng: RandomNumberGenerator) -> void:
	rounds = total_rounds
	for j in JUDGE_NAMES.size():
		var card: Array = []
		var lean: Array = []
		for r in total_rounds:
			card.append([])
			lean.append(rng.randf_range(-1.0, 1.0))
		cards.append(card)
		_opinion.append(lean)


## Works out how [param judge] would score a round from the two boxers' round
## stats right now. Used both live (as a projection) and at the bell.
func score_round(judge: int, round_index: int, red: Fighter, blue: Fighter) -> Array:
	var w: Array = STYLE_WEIGHTS[judge]
	var red_work := _work(w, red.round_stats)
	var blue_work := _work(w, blue.round_stats)
	# Personal opinion nudges close rounds one way or the other.
	var nudge: float = _opinion[judge][round_index] * 0.6
	red_work += nudge
	blue_work -= nudge

	var total := maxf(red_work + blue_work, 0.001)
	var share := (red_work - blue_work) / total
	var red_points := 10
	var blue_points := 10
	if share > EVEN_ROUND:
		blue_points = 9
	elif share < -EVEN_ROUND:
		red_points = 9
	# Each knockdown suffered costs a point (the 10-8 round).
	red_points -= red.knockdowns_round
	blue_points -= blue.knockdowns_round
	# Keep the round winner on 10 (the "must" in 10-point must).
	var top := maxi(red_points, blue_points)
	red_points += 10 - top
	blue_points += 10 - top
	return [clampi(red_points, 6, 10), clampi(blue_points, 6, 10)]


## Locks in the scores for a finished round.
func finalise_round(round_index: int, red: Fighter, blue: Fighter) -> void:
	for j in JUDGE_NAMES.size():
		cards[j][round_index] = score_round(j, round_index, red, blue)


## [red_total, blue_total] for one judge. Pass the in-progress round index to
## include the live projection for that round as well.
func totals(judge: int, live_round: int = -1, red: Fighter = null, blue: Fighter = null) -> Array:
	var red_total := 0
	var blue_total := 0
	for r in rounds:
		var score: Array = cards[judge][r]
		if score.is_empty() and r == live_round and red != null:
			score = score_round(judge, r, red, blue)
		if not score.is_empty():
			red_total += score[0]
			blue_total += score[1]
	return [red_total, blue_total]


## Number of judges currently favouring each corner: [red, blue, even].
func tally(live_round: int = -1, red: Fighter = null, blue: Fighter = null) -> Array:
	var out := [0, 0, 0]
	for j in JUDGE_NAMES.size():
		var t := totals(j, live_round, red, blue)
		if t[0] > t[1]:
			out[0] += 1
		elif t[1] > t[0]:
			out[1] += 1
		else:
			out[2] += 1
	return out


func _work(w: Array, s: Dictionary) -> float:
	return s["score"] * w[0] + s["damage"] * w[1] + s["pressure"] * 0.05 * w[2] + s["evaded"] * 0.3 * w[3]
