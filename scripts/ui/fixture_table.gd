class_name FixtureTable
extends Control
## A page of season fights as a table (1248 x 664), used by the Fixtures
## screen and the newspaper's results page.
##
##   DIV  RANK RED CORNER         V   RANK BLUE CORNER     RDS   PURSE  RESULT  RATING
##   HW      C A. PEREIRA      [belt]    1 D. WATANABE      12   $100M   KO 7    8.4
##              29-2-2                     22-2-0
##
## RESULT is short (KO 7, TKO 3, POINTS, DRAW) with the kind of result in
## small type under it (UD / SD / MD under POINTS, SPLIT under DRAW...).
##
## A title fight has the belt where the V would be. Once a fight is over the
## winner's name is gold, the loser's dim, and the result and its
## excitement rating (out of 10) are filled in; before that the RESULT
## column shows the month it is due (in the booked list) or a dash. Rows
## can be buttons (row_pressed) so a fight can be picked to watch.

signal row_pressed(fixture: Fixture)

const W := 1248
const H := 664
const ROW_H := 60
const FIRST_ROW_Y := 56
const HEADER_Y := 32
const VALUE_Y := 12              ## As in the Boxers list: name line...
const RECORD_Y := 30             ## ...and a caption line under it.
const PAGE_SIZE := 10
const NAME_CHARS := 16

## [caption, x, width, alignment]
const COLUMNS := [
	["DIV",      24,  48, HORIZONTAL_ALIGNMENT_LEFT],
	["RANK",     88,  32, HORIZONTAL_ALIGNMENT_RIGHT],
	["RED",     136, 288, HORIZONTAL_ALIGNMENT_LEFT],
	["",        432,  64, HORIZONTAL_ALIGNMENT_CENTER],
	["RANK",    504,  32, HORIZONTAL_ALIGNMENT_RIGHT],
	["BLUE",    552, 288, HORIZONTAL_ALIGNMENT_LEFT],
	["RDS",     848,  64, HORIZONTAL_ALIGNMENT_CENTER],
	["PURSE",   920, 104, HORIZONTAL_ALIGNMENT_RIGHT],
	["RESULT", 1040, 112, HORIZONTAL_ALIGNMENT_CENTER],
	["RATING", 1168,  64, HORIZONTAL_ALIGNMENT_RIGHT],
]
const DIVISION_SHORT: Array[String] = ["LW", "MW", "HW"]

var _rows: Control
var _empty_text := ""


func _init() -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.panel(0, 0, W, H))
	for col in COLUMNS:
		var h := UiTheme.label(col[0], UiTheme.CAPTION, Palette.UI_TEXT_DIM, col[3])
		add_child(UiTheme.place(h, col[1], HEADER_Y, col[2], UiTheme.CAPTION))
	_rows = Control.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.place(_rows, 0, 0, W, H))


## How many pages [param count] fights take.
static func page_count(count: int) -> int:
	return maxi(ceili(count / float(PAGE_SIZE)), 1)


## Shows page [param page] of [param fixtures]. [param clickable] makes the
## rows of fights not yet fought into buttons; [param show_month] puts the
## month in the RESULT column of fights not yet fought; [param rankings]
## gives each man's current place.
func show_page(fixtures: Array[Fixture], page: int, rankings: Array[Rankings], clickable: bool,
		show_month: bool, empty_text: String = "NO FIGHTS") -> void:
	for child in _rows.get_children():
		child.queue_free()
	if fixtures.is_empty():
		var none := UiTheme.label(empty_text, UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_rows.add_child(UiTheme.place(none, 0, FIRST_ROW_Y + ROW_H * 2, W, UiTheme.ROW_H))
		return
	var first := page * PAGE_SIZE
	for i in range(first, mini(first + PAGE_SIZE, fixtures.size())):
		_row(fixtures[i], FIRST_ROW_Y + (i - first) * ROW_H, i % 2 == 0, rankings, clickable, show_month)


func _row(f: Fixture, y: float, stripe: bool, rankings: Array[Rankings], clickable: bool, show_month: bool) -> void:
	if stripe:
		_rows.add_child(UiTheme.block(Color(1, 1, 1, 0.04), 8, y, W - 16, ROW_H))
	if clickable and not f.is_done():
		var row := Button.new()
		row.focus_mode = Control.FOCUS_ALL
		row.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		var lit := UiTheme.box(Color(1, 1, 1, 0.07), Palette.UI_BORDER, 2)
		for state in ["hover", "focus", "pressed"]:
			row.add_theme_stylebox_override(state, lit)
		UiTheme.place(row, 8, y, W - 16, ROW_H)
		row.pressed.connect(func() -> void: row_pressed.emit(f))
		_rows.add_child(row)

	var winner := f.winner()
	var red_colour := Palette.UI_TEXT
	var blue_colour := Palette.UI_TEXT
	if winner != null:
		red_colour = Palette.UI_GOLD if winner == f.red else Palette.UI_TEXT_DIM
		blue_colour = Palette.UI_GOLD if winner == f.blue else Palette.UI_TEXT_DIM
	var result := f.result_text() if f.is_done() else ("%s" % Season.short_month(f.month) if show_month else "-")
	var rating := "%.1f" % f.excitement if f.is_done() else ""
	var values := [
		DIVISION_SHORT[f.division], _rank(f, 0, rankings), _name(f.red), "" if f.title else "V",
		_rank(f, 1, rankings), _name(f.blue), str(f.rounds), Purse.money_text(f.purse), result, rating,
	]
	var colours := [Palette.UI_TEXT_DIM, Palette.UI_GOLD, red_colour, Palette.UI_TEXT_DIM,
			Palette.UI_GOLD, blue_colour, Palette.UI_TEXT, Palette.UI_TEXT, Palette.UI_TEXT, Palette.UI_GOLD]
	for c in COLUMNS.size():
		var col: Array = COLUMNS[c]
		var cell := UiTheme.label(values[c], UiTheme.BODY, colours[c], col[3])
		_rows.add_child(UiTheme.place(cell, col[1], y + VALUE_Y, col[2], UiTheme.ROW_H))
	# Records under the names.
	for corner in 2:
		var b := f.red if corner == 0 else f.blue
		var col: Array = COLUMNS[2 if corner == 0 else 5]
		var record := UiTheme.label(b.record(), UiTheme.CAPTION, Palette.UI_TEXT_DIM)
		_rows.add_child(UiTheme.place(record, col[1], y + RECORD_Y, col[2], UiTheme.CAPTION))
	if f.is_done():
		var res: Array = COLUMNS[8]
		var verdict := UiTheme.label(f.verdict_text(), UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_rows.add_child(UiTheme.place(verdict, res[1], y + RECORD_Y, res[2], UiTheme.CAPTION))
	if f.title:
		var belt := BeltIcon.new(2)
		var mid: Array = COLUMNS[3]
		belt.position = Vector2(mid[1] + (mid[2] - belt.size.x) / 2.0, y + VALUE_Y + 12 - belt.size.y / 2.0)
		_rows.add_child(belt)


## A corner's place ("C", "4"): when the fight was fought, for a result, or
## now for a fight to come.
static func _rank(f: Fixture, corner: int, rankings: Array[Rankings]) -> String:
	if f.is_done():
		var place: int = f.summary.get("red_rank" if corner == 0 else "blue_rank", -1)
		if place < 0:
			return ""
		return "C" if place == 0 else str(place)
	var b := f.red if corner == 0 else f.blue
	var table := rankings[b.division]
	return table.rank_label(b) if table.index_of(b) >= 0 else ""


## "F. COLOMBO", kept to NAME_CHARS so every name is full size.
static func _name(b: BoxerData) -> String:
	var short := "%s. %s" % [b.first_name.substr(0, 1).to_upper(), b.last_name.to_upper()]
	if short.length() > NAME_CHARS:
		return b.last_name.to_upper().substr(0, NAME_CHARS)
	return short
