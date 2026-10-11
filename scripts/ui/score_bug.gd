class_name ScoreBug
extends Control
## TV-style score bug showing the round and the fight clock (240 x 48).
##
##    ROUND   |   TIME
##     1/3    |   2:47

const W := 240
const H := 48
const HALF := W / 2

var _round: Label
var _time: Label


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.panel(0, 0, W, H, Palette.UI_PANEL_DARK))
	add_child(UiTheme.block(Palette.UI_BORDER, HALF - 1, 8, 2, H - 16))

	for i in 2:
		var caption := UiTheme.label(["ROUND", "TIME"][i], UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(UiTheme.place(caption, i * HALF, 6, HALF, 12))
	_round = UiTheme.label("1/3", UiTheme.LARGE, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_time = UiTheme.label("3:00", UiTheme.LARGE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(_round, 0, 20, HALF, 24))
	add_child(UiTheme.place(_time, HALF, 20, HALF, 24))


func show_state(round_number: int, total_rounds: int, clock_text: String) -> void:
	_round.text = "%d/%d" % [round_number, total_rounds]
	_time.text = clock_text
