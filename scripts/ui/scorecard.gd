class_name Scorecard
extends Control
## The judges' scorecard shown under the ring (512 x 136).
##
##   JUDGES' SCORECARD                         RED  BLUE
##              ROUND 1   ROUND 2   ROUND 3    TOTAL
##   JUDGE A     10-9      9-10       -        19-19
##   JUDGE B     ...
##
## Finished rounds are shown bright; the round in progress shows each judge's
## current projection, dimmed, so you can see who is winning it right now.

const W := 512
const H := 136
const PAD := 16
const COL_W := 96                 # Every column is the same width.
const HEADER_Y := 32
const FIRST_ROW_Y := 48

var _cells: Array = []            # _cells[judge][column] -> ScorePair (column 3 = total)


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.panel(0, 0, W, H))

	add_child(UiTheme.place(UiTheme.label("JUDGES' SCORECARD", UiTheme.CAPTION, Palette.UI_TEXT_DIM), PAD, 12, 240, 12))
	var blue_key := UiTheme.label("BLUE", UiTheme.CAPTION, Palette.UI_BLUE, HORIZONTAL_ALIGNMENT_RIGHT)
	var red_key := UiTheme.label("RED", UiTheme.CAPTION, Palette.UI_RED, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(UiTheme.place(blue_key, W - PAD - 32, 12, 32, 12))
	add_child(UiTheme.place(red_key, W - PAD - 32 - 8 - 24, 12, 24, 12))

	var headers := ["ROUND 1", "ROUND 2", "ROUND 3", "TOTAL"]
	for c in headers.size():
		var h := UiTheme.label(headers[c], UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(UiTheme.place(h, PAD + COL_W * (c + 1), HEADER_Y, COL_W, 12))

	for j in Judges.JUDGE_NAMES.size():
		var y := FIRST_ROW_Y + j * UiTheme.ROW_H
		var name_label := UiTheme.label(Judges.JUDGE_NAMES[j], UiTheme.CAPTION, Palette.UI_TEXT)
		add_child(UiTheme.place(name_label, PAD, y, COL_W, UiTheme.ROW_H))
		var row: Array = []
		for c in 4:
			var cell := ScorePair.new()
			cell.position = Vector2(PAD + COL_W * (c + 1) + (COL_W - ScorePair.WIDTH) / 2.0, y)
			cell.clear()
			add_child(cell)
			row.append(cell)
		_cells.append(row)


## Redraws every cell from the judges' cards plus the live round projection.
func refresh(sim: FightSim) -> void:
	var live := sim.phase == FightSim.Phase.ROUND or sim.phase == FightSim.Phase.COUNT
	var live_round := sim.round_number - 1 if live else -1
	for j in Judges.JUDGE_NAMES.size():
		for r in sim.judges.rounds:
			var cell: ScorePair = _cells[j][r]
			var score: Array = sim.judges.cards[j][r]
			if not score.is_empty():
				cell.set_score(score[0], score[1])
			elif r == live_round:
				var p := sim.judges.score_round(j, r, sim.red, sim.blue)
				cell.set_score(p[0], p[1], true)
			else:
				cell.clear()
		var any_scored: bool = live_round >= 0 or not sim.judges.cards[j][0].is_empty()
		var total_cell: ScorePair = _cells[j][3]
		if any_scored:
			var t := sim.judges.totals(j, live_round, sim.red, sim.blue)
			total_cell.set_score(t[0], t[1])
		else:
			total_cell.clear()
