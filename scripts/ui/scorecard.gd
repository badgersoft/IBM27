class_name Scorecard
extends Control
## The panel under the ring (512 x 136). It has three faces:
##
## TODAY'S JUDGES (before the first bell) - who is judging and how fair they are:
##   TODAY'S JUDGES
##   JUDGE                FROM      FAIRNESS
##   H. PEMBERTON          GBR        FAIR
##
## PUNDIT (during the fight) - the official cards are secret, so this shows a
## ringside TV pundit's unofficial card. The round in progress is the pundit's
## live view, dimmed:
##   RINGSIDE PUNDIT - UNOFFICIAL                 SALLY BRENNAN
##              ROUND 1   ROUND 2   ROUND 3    TOTAL
##   CARD        10-9      9-10       -        19-19
##   --------------------------------------------------
##              SCORES IT LEVEL  19-19
##
## OFFICIAL (after the final bell) - the judges' real cards, each row filled
## in as that judge's score is read out (see reveal_judges).

enum Mode { JUDGES, PUNDIT, OFFICIAL }

const W := 512
const H := 136
const PAD := 16
const COL_W := 96                 # Score columns are all the same width.
const HEADER_Y := 32
const FIRST_ROW_Y := 48
## "Today's judges" columns: name, country, fairness band. Only the band
## (FAIR / SO-SO / WILD) is shown - the number behind it stays hidden.
const JUDGE_NAME_W := 256
const COUNTRY_X := 288
const COUNTRY_W := 64
const FAIR_X := 368
const FAIR_W := 128

var mode: Mode = Mode.JUDGES

var _faces := {}                  # Mode -> Control holding that face.
var _pundit_cells: Array = []     # 3 rounds + total.
var _verdict: Label
var _official_cells: Array = []   # [judge][column], column 3 = total.
var _official_names: Array = []
var _pundit_name: Label
var _revealed := 3                # Official rows shown (the rest stay blank).


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.panel(0, 0, W, H))
	_faces[Mode.JUDGES] = _face()
	_faces[Mode.PUNDIT] = _face()
	_faces[Mode.OFFICIAL] = _face()
	_build_pundit(_faces[Mode.PUNDIT])
	_build_official(_faces[Mode.OFFICIAL])
	set_mode(Mode.JUDGES)


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	for m in _faces:
		_faces[m].visible = m == mode


## Fills in the "today's judges" face (public information only).
func show_judges(judges: Judges) -> void:
	var face: Control = _faces[Mode.JUDGES]
	for child in face.get_children():
		child.queue_free()
	face.add_child(UiTheme.place(UiTheme.label("TODAY'S JUDGES", UiTheme.CAPTION, Palette.UI_GOLD), PAD, 12, 240, UiTheme.CAPTION))
	face.add_child(UiTheme.place(UiTheme.label("JUDGE", UiTheme.CAPTION, Palette.UI_TEXT_DIM), PAD, HEADER_Y, JUDGE_NAME_W, UiTheme.CAPTION))
	face.add_child(UiTheme.place(UiTheme.label("FROM", UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), COUNTRY_X, HEADER_Y, COUNTRY_W, UiTheme.CAPTION))
	face.add_child(UiTheme.place(UiTheme.label("FAIRNESS", UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), FAIR_X, HEADER_Y, FAIR_W, UiTheme.CAPTION))
	for j in judges.panel.size():
		var judge: Dictionary = judges.panel[j]
		var fairness := int(judge["fairness"])
		var y := FIRST_ROW_Y + j * UiTheme.ROW_H
		var name_label := UiTheme.label(Officials.short_name(judge))
		UiTheme.fit(name_label, JUDGE_NAME_W)
		face.add_child(UiTheme.place(name_label, PAD, y, JUDGE_NAME_W, UiTheme.ROW_H))
		face.add_child(UiTheme.place(UiTheme.label(judge["country"], UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), COUNTRY_X, y, COUNTRY_W, UiTheme.ROW_H))
		var band := UiTheme.label(Officials.fairness_label(fairness), UiTheme.BODY, Officials.fairness_color(fairness), HORIZONTAL_ALIGNMENT_CENTER)
		face.add_child(UiTheme.place(band, FAIR_X, y, FAIR_W, UiTheme.ROW_H))
	_pundit_name.text = str(judges.pundit["name"]).to_upper()
	for j in judges.panel.size():
		_official_names[j].text = Officials.surname(judges.panel[j])


## Updates whichever face is showing.
func refresh(sim: FightSim) -> void:
	match mode:
		Mode.PUNDIT:
			_refresh_pundit(sim)
		Mode.OFFICIAL:
			_refresh_official(sim)


# ============================================================================
#  Faces
# ============================================================================

func _face() -> Control:
	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.place(face, 0, 0, W, H))
	return face


## Column headings shared by the pundit and official faces.
func _round_headers(face: Control) -> void:
	var headers := ["ROUND 1", "ROUND 2", "ROUND 3", "TOTAL"]
	for c in headers.size():
		var h := UiTheme.label(headers[c], UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		face.add_child(UiTheme.place(h, PAD + COL_W * (c + 1), HEADER_Y, COL_W, UiTheme.CAPTION))


func _score_row(face: Control, y: float) -> Array:
	var row: Array = []
	for c in 4:
		var cell := ScorePair.new()
		cell.position = Vector2(PAD + COL_W * (c + 1) + (COL_W - ScorePair.WIDTH) / 2.0, y)
		cell.clear()
		face.add_child(cell)
		row.append(cell)
	return row


func _build_pundit(face: Control) -> void:
	face.add_child(UiTheme.place(UiTheme.label("RINGSIDE PUNDIT  -  UNOFFICIAL", UiTheme.CAPTION, Palette.UI_TEXT_DIM), PAD, 12, 288, UiTheme.CAPTION))
	_pundit_name = UiTheme.label("", UiTheme.CAPTION, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	face.add_child(UiTheme.place(_pundit_name, W - PAD - 192, 12, 192, UiTheme.CAPTION))
	_round_headers(face)
	face.add_child(UiTheme.place(UiTheme.label("CARD", UiTheme.CAPTION), PAD, FIRST_ROW_Y, COL_W, UiTheme.ROW_H))
	_pundit_cells = _score_row(face, FIRST_ROW_Y)
	face.add_child(UiTheme.block(Color(Palette.UI_TEXT_DIM, 0.4), PAD, 84, W - PAD * 2, 1))
	_verdict = UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	face.add_child(UiTheme.place(_verdict, PAD, 96, W - PAD * 2, UiTheme.ROW_H))


func _build_official(face: Control) -> void:
	face.add_child(UiTheme.place(UiTheme.label("OFFICIAL SCORECARDS", UiTheme.CAPTION, Palette.UI_GOLD), PAD, 12, 240, UiTheme.CAPTION))
	var blue_key := UiTheme.label("BLUE", UiTheme.CAPTION, Palette.UI_BLUE, HORIZONTAL_ALIGNMENT_RIGHT)
	var red_key := UiTheme.label("RED", UiTheme.CAPTION, Palette.UI_RED, HORIZONTAL_ALIGNMENT_RIGHT)
	face.add_child(UiTheme.place(blue_key, W - PAD - 32, 12, 32, UiTheme.CAPTION))
	face.add_child(UiTheme.place(red_key, W - PAD - 32 - 8 - 24, 12, 24, UiTheme.CAPTION))
	_round_headers(face)
	for j in 3:
		var y := FIRST_ROW_Y + j * UiTheme.ROW_H
		var name_label := UiTheme.label("", UiTheme.CAPTION)
		face.add_child(UiTheme.place(name_label, PAD, y, COL_W, UiTheme.ROW_H))
		_official_names.append(name_label)
		_official_cells.append(_score_row(face, y))


func _refresh_pundit(sim: FightSim) -> void:
	var live := sim.phase == FightSim.Phase.ROUND or sim.phase == FightSim.Phase.COUNT
	var live_round := sim.round_number - 1 if live else -1
	var judges := sim.judges
	var any := false
	for r in judges.rounds:
		var cell: ScorePair = _pundit_cells[r]
		var score: Array = judges.pundit_card[r]
		if not score.is_empty():
			cell.set_score(score[0], score[1])
			any = true
		elif r == live_round:
			var p := judges.pundit_round(r, sim.red, sim.blue)
			cell.set_score(p[0], p[1], true)
			any = true
		else:
			cell.clear()
	var total_cell: ScorePair = _pundit_cells[3]
	if not any:
		total_cell.clear()
		_verdict.text = ""
		return
	var t := judges.pundit_totals(live_round, sim.red, sim.blue)
	total_cell.set_score(t[0], t[1])
	if t[0] == t[1]:
		_verdict.text = "SCORES IT LEVEL  %d-%d" % [t[0], t[1]]
		_verdict.add_theme_color_override("font_color", Palette.UI_TEXT)
	else:
		var leader := 0 if t[0] > t[1] else 1
		var boxer: BoxerData = sim.fighters[leader].data
		_verdict.text = "SCORES IT %d-%d  %s" % [maxi(t[0], t[1]), mini(t[0], t[1]), boxer.last_name.to_upper()]
		_verdict.add_theme_color_override("font_color", Palette.corner_color(leader))
	UiTheme.fit(_verdict, W - PAD * 2)


## How many judges' rows of the official face are filled in.
func reveal_judges(count: int, sim: FightSim) -> void:
	_revealed = count
	refresh(sim)


func _refresh_official(sim: FightSim) -> void:
	var judges := sim.judges
	for j in judges.panel.size():
		if j >= _revealed:
			for cell in _official_cells[j]:
				(cell as ScorePair).clear()
			continue
		for r in judges.rounds:
			var cell: ScorePair = _official_cells[j][r]
			var score: Array = judges.cards[j][r]
			if score.is_empty():
				cell.clear()
			else:
				cell.set_score(score[0], score[1])
		var t := judges.totals(j)
		_official_cells[j][3].set_score(t[0], t[1])
