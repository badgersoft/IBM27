class_name OfficialCard
extends Control
## The judges' official scorecards, shown across the whole bottom of the
## fight screen while the verdict is read (1248 x 176). Each judge's row is
## filled in as his score is read out (see reveal_judges).
##
##   OFFICIAL SCORECARDS                    RED  BLUE  EVEN  GOLD EDGE 10-8
##   JUDGE              1     2     3     4     5     6            TOTAL
##   Y. SHIMADA       [red] [blu] [red] [red] [gry] [red]          58-56
##   ...
##
## Every round is a box coloured by who that judge gave it to (RoundStrip),
## sized so 3, 6, 10 and 12 rounds all fill the same space, and the total is
## a full-size score with room for three digits in the longer fights.

const W := 1248
const H := 176
const PAD := 16
const CAPTION_Y := 8
const HEADER_Y := 42
const FIRST_ROW_Y := 64
const ROW_H := 32
const NAME_W := 240
const STRIP_AREA := Vector2(272, 1048)      ## x from / to.
const STRIP_STEPS := [128, 96, 72, 64]
const STRIP_DROP := 3                       ## Box top below the row top.
const TOTAL_X := 1072
const TOTAL_W := 160

## The colour key: [text, colour].
const KEY := [["RED", Palette.UI_RED], ["BLUE", Palette.UI_BLUE], ["EVEN", Palette.UI_TEXT_DIM], ["GOLD EDGE 10-8", Palette.UI_GOLD]]
const KEY_GAP := 16

var _names: Array[Label] = []
var _strips: Array[RoundStrip] = []
var _totals: Array[ScorePair] = []
var _revealed := 0


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.panel(0, 0, W, H))
	add_child(UiTheme.place(UiTheme.label("OFFICIAL SCORECARDS", UiTheme.CAPTION, Palette.UI_GOLD), PAD, CAPTION_Y, 240, UiTheme.CAPTION))
	# Key, right-aligned: each entry as wide as its text (8 px a character).
	var x := float(W - PAD)
	for i in range(KEY.size() - 1, -1, -1):
		var entry: Array = KEY[i]
		var w := str(entry[0]).length() * UiTheme.CAPTION
		x -= w
		add_child(UiTheme.place(UiTheme.label(entry[0], UiTheme.CAPTION, entry[1]), x, CAPTION_Y, w, UiTheme.CAPTION))
		x -= KEY_GAP


## Lays the card out for [param judges] (names and fight length).
func setup(judges: Judges) -> void:
	add_child(UiTheme.place(UiTheme.label("JUDGE", UiTheme.CAPTION, Palette.UI_TEXT_DIM), PAD, HEADER_Y, NAME_W, UiTheme.CAPTION))
	var total_caption := UiTheme.label("TOTAL", UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(total_caption, TOTAL_X, HEADER_Y, TOTAL_W, UiTheme.CAPTION))
	var digits := 3 if judges.rounds * 10 >= 100 else 2

	for j in judges.panel.size():
		var y := FIRST_ROW_Y + j * ROW_H
		var name_label := UiTheme.label(Officials.short_name(judges.panel[j]), UiTheme.BODY, Palette.UI_TEXT)
		add_child(UiTheme.place(name_label, PAD, y, NAME_W, UiTheme.ROW_H))
		_names.append(name_label)

		var strip := RoundStrip.new()
		strip.setup(judges.rounds, STRIP_AREA.y - STRIP_AREA.x, STRIP_STEPS)
		strip.position = Vector2(roundf(STRIP_AREA.x + (STRIP_AREA.y - STRIP_AREA.x - strip.size.x) / 2.0), y + STRIP_DROP)
		add_child(strip)
		_strips.append(strip)

		var total := ScorePair.new(digits)
		total.position = Vector2(TOTAL_X + (TOTAL_W - ScorePair.width_for(digits)) / 2.0, y)
		total.clear()
		add_child(total)
		_totals.append(total)

	# Round numbers over the boxes, from the first strip's layout.
	var first := _strips[0]
	for r in judges.rounds:
		var number := UiTheme.label(str(r + 1), UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		var nx := first.position.x + first.number_x(r) - first.step / 2.0
		add_child(UiTheme.place(number, nx, HEADER_Y, first.step, UiTheme.CAPTION))


## Fills in the first [param count] judges' rows; the rest stay blank.
func reveal_judges(count: int, sim: FightSim) -> void:
	_revealed = count
	var judges := sim.judges
	for j in judges.panel.size():
		if j >= _revealed:
			_strips[j].clear_all()
			_totals[j].clear()
			continue
		for r in judges.rounds:
			_strips[j].set_round(r, judges.cards[j][r])
		var t := judges.totals(j)
		_totals[j].set_score(t[0], t[1])
