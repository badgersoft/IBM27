class_name ScorePair
extends Control
## Shows a score such as "10-9" with the dash ALWAYS in the same column.
##
## The red corner's number is right-aligned in its own slot and the blue
## corner's number is left-aligned in another, so "10-9", "9-10" and "10-10"
## all line up perfectly down a table. Each number is drawn in its corner's
## colour. Slots are two characters wide, or three for totals that can pass
## 100 (a 12-round fight is scored out of 120).

## Width of a pair with two-digit slots (the usual size).
const WIDTH := 5 * UiTheme.CHAR_W

## Width of a pair with [param digits] characters per slot.
static func width_for(digits: int) -> float:
	return (digits * 2 + 1) * UiTheme.CHAR_W


var _red: Label
var _dash: Label
var _blue: Label


func _init(digits: int = 2) -> void:
	var slot := digits * UiTheme.CHAR_W
	custom_minimum_size = Vector2(width_for(digits), UiTheme.ROW_H)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red = UiTheme.label("", UiTheme.BODY, Palette.UI_RED, HORIZONTAL_ALIGNMENT_RIGHT)
	_dash = UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_blue = UiTheme.label("", UiTheme.BODY, Palette.UI_BLUE, HORIZONTAL_ALIGNMENT_LEFT)
	add_child(UiTheme.place(_red, 0, 0, slot, UiTheme.ROW_H))
	add_child(UiTheme.place(_dash, slot, 0, UiTheme.CHAR_W, UiTheme.ROW_H))
	add_child(UiTheme.place(_blue, slot + UiTheme.CHAR_W, 0, slot, UiTheme.ROW_H))


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

