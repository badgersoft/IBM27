class_name RoundStrip
extends Control
## A row of boxes, one per round, coloured by who won each round on a card:
##
##   [red] [blue] [red] [grey] [    ] [    ]
##
##   red / blue  - that corner won the round
##   grey        - an even round (10-10)
##   gold edge   - a big round (10-8 or wider, usually a knockdown)
##   dark        - not scored yet
##
## Boxes are sized to the fight length so 3, 6, 10 and 12 rounds all fill the
## same space: the widest step from STEPS that fits is used. The round
## numbers are drawn as 8 px captions centred over the boxes by whoever owns
## the strip (see number_x()).

const GAP := 4                       ## Between boxes.
const BOX_H := 16
const EDGE := 2                      ## Gold edge on a big round.

var rounds := 6
var step := 32                       ## Box width + GAP.
var _scores: Array = []              ## [red, blue] per round, or [] if unscored.


## Lays out [param round_count] boxes within [param max_width], choosing the
## widest step in [param steps] (largest first) that fits.
func setup(round_count: int, max_width: float, steps: Array) -> void:
	rounds = round_count
	step = steps[-1]
	for s in steps:
		if round_count * s - GAP <= max_width:
			step = s
			break
	size = Vector2(rounds * step - GAP, BOX_H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scores.clear()
	for r in rounds:
		_scores.append([])
	queue_redraw()


## Centre x of round [param r]'s box, in the strip's own coordinates.
func number_x(r: int) -> float:
	return r * step + (step - GAP) / 2.0


## Shows round [param r]'s score, or an unscored box for an empty array.
func set_round(r: int, score: Array) -> void:
	if r < _scores.size() and _scores[r] != score:
		_scores[r] = score.duplicate()
		queue_redraw()


func clear_all() -> void:
	for r in rounds:
		_scores[r] = []
	queue_redraw()


func _draw() -> void:
	for r in rounds:
		var rect := Rect2(r * step, 0, step - GAP, BOX_H)
		var score: Array = _scores[r]
		if score.is_empty():
			draw_rect(rect, Palette.UI_PANEL_DARK)
			draw_rect(rect, Color(Palette.UI_TEXT_DIM, 0.5), false, 1.0)
			continue
		var margin: int = score[0] - score[1]
		var fill := Palette.UI_TEXT_DIM
		if margin > 0:
			fill = Palette.UI_RED
		elif margin < 0:
			fill = Palette.UI_BLUE
		draw_rect(rect, fill)
		if absi(margin) >= 2:
			draw_rect(rect.grow(-EDGE / 2.0), Palette.UI_GOLD, false, EDGE)
