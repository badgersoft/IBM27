class_name ScoreBug
extends Control
## TV-style score bug showing the round and the fight clock (288 x 48).
##
##   +-----------------+-----------------+
##   |      ROUND      |      TIME       |   <- captions, 8 px
##   |       1/3       |      2:47       |   <- values, 16 px
##   +-----------------+-----------------+
##
## Kept deliberately sparse: two cells, two sizes of text, 8 px of air between
## the border, the caption, the value and the border again.

const W := 288
const H := 48
const HALF := W / 2
## Label tops, chosen (and measured on screen) so the visible letters sit with
## equal space around them: 8 px border-to-caption, 7 px caption-to-value,
## 8 px value-to-border. Label boxes include the font's internal leading, which
## is why these are not simply 8 and 24.
const CAPTION_Y := 3
const VALUE_Y := 21

var _round: Label
var _time: Label


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.panel(0, 0, W, H, Palette.UI_PANEL_DARK))
	add_child(UiTheme.block(Palette.UI_BORDER, HALF - 1, 10, 2, H - 20))

	for i in 2:
		var caption := UiTheme.label(["ROUND", "TIME"][i], UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(UiTheme.place(caption, i * HALF, CAPTION_Y, HALF, UiTheme.CAPTION))
	_round = UiTheme.label("1/3", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_time = UiTheme.label("3:00", UiTheme.BODY, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(_round, 0, VALUE_Y, HALF, UiTheme.BODY))
	add_child(UiTheme.place(_time, HALF, VALUE_Y, HALF, UiTheme.BODY))


func show_state(round_number: int, total_rounds: int, clock_text: String) -> void:
	_round.text = "%d/%d" % [round_number, total_rounds]
	_time.text = clock_text
