class_name Scorecard
extends Control
## The panel under the ring during the fight (512 x 128). It has two faces:
##
## TODAY'S JUDGES (before the first bell) - who is judging and how fair they are:
##   TODAY'S JUDGES
##   JUDGE                FROM      FAIRNESS
##   H. PEMBERTON          GBR        FAIR
##
## PUNDIT (during the fight) - the official cards are secret, so this shows a
## ringside TV pundit's unofficial card. Like a real card, each round is only
## scored when the bell ends it. Six rounds sit in two rows of three:
##   RINGSIDE PUNDIT - UNOFFICIAL                 SALLY BRENNAN
##   R1  10-9    R2  9-10    R3  10-9     |     TOTAL
##   R4   -      R5   -      R6   -       |     29-28
##   --------------------------------------------------
##              SCORES IT 29-28  JOHNSON
##
## The judges' official cards are shown on OfficialCard once the verdict is
## being read.

enum Mode { JUDGES, PUNDIT }

const W := 512
const H := 128
const PAD := 16
const HEADER_Y := 27
const FIRST_ROW_Y := 43
## Pundit's card: rounds in rows of three, each cell a dim round number and
## the score; the total in its own block on the right.
const ROUNDS_PER_ROW := 3
const ROUND_ROW_Y := 26
const ROUND_LABEL_W := 32
const ROUND_PITCH := 120
const TOTAL_X := 384
const TOTAL_W := 112
## "Today's judges" columns: name, country, fairness band. Only the band
## (FAIR / SO-SO / WILD) is shown - the number behind it stays hidden.
const JUDGE_NAME_W := 256
const COUNTRY_X := 288
const COUNTRY_W := 64
const FAIR_X := 368
const FAIR_W := 128

var mode: Mode = Mode.JUDGES

var _faces := {}                  # Mode -> Control holding that face.
var _pundit_cells: Array = []     # One per round.
var _pundit_total: ScorePair
var _verdict: Label
var _pundit_name: Label


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.panel(0, 0, W, H))
	_faces[Mode.JUDGES] = _face()
	_faces[Mode.PUNDIT] = _face()
	_build_pundit(_faces[Mode.PUNDIT])
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
	face.add_child(UiTheme.place(UiTheme.label("TODAY'S JUDGES", UiTheme.CAPTION, Palette.UI_GOLD), PAD, 7, 240, UiTheme.CAPTION))
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


## Updates the pundit's card (the judges face never changes).
func refresh(sim: FightSim) -> void:
	if mode == Mode.PUNDIT:
		_refresh_pundit(sim)


# ============================================================================
#  Faces
# ============================================================================

func _face() -> Control:
	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.place(face, 0, 0, W, H))
	return face


func _build_pundit(face: Control) -> void:
	face.add_child(UiTheme.place(UiTheme.label("RINGSIDE PUNDIT  -  UNOFFICIAL", UiTheme.CAPTION, Palette.UI_TEXT_DIM), PAD, 7, 288, UiTheme.CAPTION))
	_pundit_name = UiTheme.label("", UiTheme.CAPTION, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	face.add_child(UiTheme.place(_pundit_name, W - PAD - 192, 7, 192, UiTheme.CAPTION))

	for r in FightSim.ROUNDS:
		var x := PAD + (r % ROUNDS_PER_ROW) * ROUND_PITCH
		var y := ROUND_ROW_Y + (r / ROUNDS_PER_ROW) * UiTheme.ROW_H
		# An 8 px label draws its capitals 7 px down, which centres them on
		# the 16 px score beside it.
		var number := UiTheme.label("R%d" % (r + 1), UiTheme.CAPTION, Palette.UI_TEXT_DIM)
		face.add_child(UiTheme.place(number, x, y, ROUND_LABEL_W, UiTheme.CAPTION))
		var cell := ScorePair.new()
		cell.position = Vector2(x + ROUND_LABEL_W, y)
		cell.clear()
		face.add_child(cell)
		_pundit_cells.append(cell)

	# Total: a thin divider, the caption over the first row, the score under it.
	var rows := ceili(FightSim.ROUNDS / float(ROUNDS_PER_ROW))
	face.add_child(UiTheme.block(Color(Palette.UI_TEXT_DIM, 0.4), TOTAL_X - 8, ROUND_ROW_Y + 4, 1, rows * UiTheme.ROW_H - 8))
	var caption := UiTheme.label("TOTAL", UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	face.add_child(UiTheme.place(caption, TOTAL_X, ROUND_ROW_Y, TOTAL_W, UiTheme.CAPTION))
	_pundit_total = ScorePair.new()
	_pundit_total.position = Vector2(TOTAL_X + (TOTAL_W - ScorePair.WIDTH) / 2.0, ROUND_ROW_Y + UiTheme.ROW_H)
	_pundit_total.clear()
	face.add_child(_pundit_total)

	face.add_child(UiTheme.block(Color(Palette.UI_TEXT_DIM, 0.4), PAD, 79, W - PAD * 2, 1))
	_verdict = UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	face.add_child(UiTheme.place(_verdict, PAD, 91, W - PAD * 2, UiTheme.ROW_H))


func _refresh_pundit(sim: FightSim) -> void:
	var judges := sim.judges
	var any := false
	for r in judges.rounds:
		var cell: ScorePair = _pundit_cells[r]
		var score: Array = judges.pundit_card[r]
		if not score.is_empty():
			cell.set_score(score[0], score[1])
			any = true
		else:
			cell.clear()
	if not any:
		_pundit_total.clear()
		_verdict.text = "SCORED AFTER EACH ROUND"
		_verdict.add_theme_color_override("font_color", Palette.UI_TEXT_DIM)
		return
	var t := judges.pundit_totals()
	_pundit_total.set_score(t[0], t[1])
	if t[0] == t[1]:
		_verdict.text = "SCORES IT LEVEL  %d-%d" % [t[0], t[1]]
		_verdict.add_theme_color_override("font_color", Palette.UI_TEXT)
	else:
		var leader := 0 if t[0] > t[1] else 1
		var boxer: BoxerData = sim.fighters[leader].data
		_verdict.text = "SCORES IT %d-%d  %s" % [maxi(t[0], t[1]), mini(t[0], t[1]), boxer.last_name.to_upper()]
		_verdict.add_theme_color_override("font_color", Palette.corner_color(leader))
	UiTheme.fit(_verdict, W - PAD * 2)
