class_name ScorePair
extends Control
## Shows a score such as "10-9" with the dash ALWAYS in the same column.
##
## The red corner's number is right-aligned in its own two-character slot and
## the blue corner's number is left-aligned in another, so "10-9", "9-10" and
## "10-10" all line up perfectly down a table. Each number is drawn in its
## corner's colour.

const SLOT := 2 * UiTheme.CHAR_W   # Two characters per number.
const WIDTH := SLOT * 2 + UiTheme.CHAR_W

var _red: Label
var _dash: Label
var _blue: Label


func _init() -> void:
	custom_minimum_size = Vector2(WIDTH, UiTheme.ROW_H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red = UiTheme.label("", UiTheme.BODY, Palette.UI_RED, HORIZONTAL_ALIGNMENT_RIGHT)
	_dash = UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_blue = UiTheme.label("", UiTheme.BODY, Palette.UI_BLUE, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(UiTheme.place(_red, 0, 0, SLOT, UiTheme.ROW_H))
	add_child(UiTheme.place(_dash, SLOT, 0, UiTheme.CHAR_W, UiTheme.ROW_H))
	add_child(UiTheme.place(_blue, SLOT + UiTheme.CHAR_W, 0, SLOT, UiTheme.ROW_H))


## Shows [param red]-[param blue]. [param provisional] dims it (a live
## projection rather than a final score).
func set_score(red: int, blue: int, provisional: bool = false) -> void:
	_red.text = str(red)
	_dash.text = "-"
	_blue.text = str(blue)
	var alpha := 0.55 if provisional else 1.0
	_red.modulate.a = alpha
	_dash.modulate.a = alpha
	_blue.modulate.a = alpha


## An empty cell: a single dim dash in the centre column.
func clear() -> void:
	_red.text = ""
	_blue.text = ""
	_dash.text = "-"
	_dash.modulate.a = 0.5

