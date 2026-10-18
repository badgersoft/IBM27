class_name OfficialCard
extends Control
## The judges' official scorecards, shown across the whole bottom of the
## fight screen while the verdict is read (1248 x 128). Each judge's row is
## filled in as his score is read out (see reveal_judges).
##
##   OFFICIAL SCORECARDS                                          RED  BLUE
##                 ROUND 1  ROUND 2  ROUND 3  ROUND 4  ROUND 5  ROUND 6  TOTAL
##   Y. SHIMADA     10-9     9-10     10-9     10-9     10-9     9-10   58-56
##   ...
##
## Seven equal columns (six rounds and the total) fill the space after the
## judges' names, with every score's dash in the same place.

const W := 1248
const H := 128
const PAD := 16
const CAPTION_Y := 7
const HEADER_Y := 27
const FIRST_ROW_Y := 43
const NAME_W := 240
const COLUMNS_X := PAD + NAME_W + 16
const COLUMN_W := 136

var _names: Array[Label] = []
var _cells: Array = []            # [judge][column]; the last column is the total.
var _revealed := 0


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.panel(0, 0, W, H))
	add_child(UiTheme.place(UiTheme.label("OFFICIAL SCORECARDS", UiTheme.CAPTION, Palette.UI_GOLD), PAD, CAPTION_Y, 240, UiTheme.CAPTION))
	var blue_key := UiTheme.label("BLUE", UiTheme.CAPTION, Palette.UI_BLUE, HORIZONTAL_ALIGNMENT_RIGHT)
	var red_key := UiTheme.label("RED", UiTheme.CAPTION, Palette.UI_RED, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(UiTheme.place(blue_key, W - PAD - 32, CAPTION_Y, 32, UiTheme.CAPTION))
	add_child(UiTheme.place(red_key, W - PAD - 32 - 8 - 24, CAPTION_Y, 24, UiTheme.CAPTION))

	var columns := FightSim.ROUNDS + 1
	for c in columns:
		var text := "TOTAL" if c == FightSim.ROUNDS else "ROUND %d" % (c + 1)
		var h := UiTheme.label(text, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(UiTheme.place(h, COLUMNS_X + c * COLUMN_W, HEADER_Y, COLUMN_W, UiTheme.CAPTION))
	for j in 3:
		var y := FIRST_ROW_Y + j * UiTheme.ROW_H
		var name_label := UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT)
		add_child(UiTheme.place(name_label, PAD, y, NAME_W, UiTheme.ROW_H))
		_names.append(name_label)
		var row: Array = []
		for c in columns:
			var cell := ScorePair.new()
			cell.position = Vector2(COLUMNS_X + c * COLUMN_W + (COLUMN_W - ScorePair.WIDTH) / 2.0, y)
			cell.clear()
			add_child(cell)
			row.append(cell)
		_cells.append(row)


func setup(judges: Judges) -> void:
	for j in judges.panel.size():
		_names[j].text = Officials.short_name(judges.panel[j])
		UiTheme.fit(_names[j], NAME_W)


## Fills in the first [param count] judges' rows; the rest stay blank.
func reveal_judges(count: int, sim: FightSim) -> void:
	_revealed = count
	var judges := sim.judges
	for j in judges.panel.size():
		var row: Array = _cells[j]
		if j >= _revealed:
			for cell in row:
				(cell as ScorePair).clear()
			continue
		for r in judges.rounds:
			var score: Array = judges.cards[j][r]
			if score.is_empty():
				(row[r] as ScorePair).clear()
			else:
				(row[r] as ScorePair).set_score(score[0], score[1])
		var t := judges.totals(j)
		(row[judges.rounds] as ScorePair).set_score(t[0], t[1])
