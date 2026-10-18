class_name PostFight
extends Control
## The post-fight screen, shown over the whole fight screen once the verdict
## has been read: both boxers' fight stats side by side, the result, the
## money and rankings, and the match rating out of 10.
##
## Layout (1280 x 800 frame, one panel 1248 x 768 at 16, 16):
##   y  32  FIGHT STATS                     12 ROUNDS - HEAVYWEIGHT - VENUE
##   y  88  RED NAME            (stat)            BLUE NAME
##   y 120  stat rows, red value right-aligned to the label, blue left
##   y 504  +-- RESULT (592 x 184) ------+  +-- MATCH RATING (592 x 184) --+
##   y 704           [ NEW FIGHT ]  [ MAIN MENU ]
##
## As in the tale of the tape, the better number in each row is gold.

signal next_pressed
signal menu_pressed

const W := 1248
const H := 768
const PAD := 16
const TITLE_Y := 16
const NAMES_Y := 72
const FIRST_ROW_Y := 104
const ROW_H := 32
const VALUE_W := 400
const LABEL_X := 416
const LABEL_W := 416
const BOXES_Y := 488
const BOX_W := 600
const BOX_H := 184
## Result rows: winner, method, purse, then each boxer's ranking.
const RESULT_ROW_Y := 32
const BUTTON_Y := 696
const BUTTON_W := 288
const BUTTON_H := 48
const BUTTON_GAP := 32
## Words for the rating: [at least, word].
const RATING_WORDS: Array = [
	[9.0, "AN ALL-TIME CLASSIC!"],
	[8.0, "A GREAT FIGHT"],
	[6.5, "A GOOD FIGHT"],
	[5.0, "A DECENT FIGHT"],
	[3.5, "A SCRAPPY FIGHT"],
	[0.0, "A DULL ONE"],
]
## The rating's bar: ten segments, one per point.
const SEGMENT_W := 48
const SEGMENT_GAP := 4
const SEGMENT_H := 16

var _first_button: Button


## [param summary] is Season.record_result's summary plus "red_rank",
## "blue_rank", "red_rank_after" and "blue_rank_after" (0 = champion, -1 =
## not ranked in this division). [param next_text] labels the first button
## (NEW FIGHT, or FIXTURES for a season fight).
func setup(sim: FightSim, summary: Dictionary, rating: float, purse: int, venue_id: int, next_text: String) -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiTheme.panel(0, 0, W, H, Palette.UI_PANEL, Palette.UI_BORDER, 4))
	var red := sim.red
	var blue := sim.blue

	add_child(UiTheme.place(UiTheme.label("FIGHT STATS", UiTheme.TITLE, Palette.UI_GOLD), PAD, TITLE_Y, 480, UiTheme.TITLE + 8))
	var bill := "%d ROUNDS  -  %s  -  %s" % [sim.rounds, red.data.division_name().to_upper(), Venues.venue_name(venue_id).to_upper()]
	if sim.title_fight:
		bill = "IBC %s TITLE  -  %s" % [red.data.division_name().to_upper(), Venues.venue_name(venue_id).to_upper()]
	add_child(UiTheme.place(UiTheme.label(bill, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT), 512, TITLE_Y + 12, W - PAD - 512, UiTheme.CAPTION))

	# Names over the two value columns.
	for corner in 2:
		var f: Fighter = sim.fighters[corner]
		var name_label := UiTheme.label(f.data.display_name().to_upper(), UiTheme.BODY, Palette.corner_color(corner),
				HORIZONTAL_ALIGNMENT_RIGHT if corner == 0 else HORIZONTAL_ALIGNMENT_LEFT)
		UiTheme.fit(name_label, VALUE_W - PAD)
		var x := PAD if corner == 0 else LABEL_X + LABEL_W
		add_child(UiTheme.place(name_label, x, NAMES_Y, VALUE_W - PAD, UiTheme.ROW_H))

	var rows := _rows(red, blue)
	for i in rows.size():
		var y := FIRST_ROW_Y + i * ROW_H
		if i % 2 == 0:
			add_child(UiTheme.block(Color(1, 1, 1, 0.04), PAD, y, W - PAD * 2, ROW_H))
		var row: Array = rows[i]
		var better: int = row[3]
		var red_text := UiTheme.label(row[1], UiTheme.BODY, Palette.UI_GOLD if better == 0 else Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		var blue_text := UiTheme.label(row[2], UiTheme.BODY, Palette.UI_GOLD if better == 1 else Palette.UI_TEXT)
		add_child(UiTheme.place(red_text, PAD, y + 4, VALUE_W - PAD, UiTheme.ROW_H))
		add_child(UiTheme.place(UiTheme.label(row[0], UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), LABEL_X, y + 4, LABEL_W, UiTheme.ROW_H))
		add_child(UiTheme.place(blue_text, LABEL_X + LABEL_W, y + 4, VALUE_W - PAD, UiTheme.ROW_H))

	_result_box(sim, summary, purse)
	_rating_box(rating)

	var left := roundf((W - BUTTON_W * 2 - BUTTON_GAP) / 2.0)
	_first_button = _button(next_text, left, next_pressed)
	_button("MAIN MENU", left + BUTTON_W + BUTTON_GAP, menu_pressed)


## Puts the keyboard focus on the first button.
func focus() -> void:
	_first_button.grab_focus()


## [label, red text, blue text, which corner is better (-1 = neither)].
static func _rows(red: Fighter, blue: Fighter) -> Array:
	var out := []
	var r := red.fight_stats
	var b := blue.fight_stats
	out.append(_count_row("PUNCHES THROWN", r["thrown"], b["thrown"]))
	out.append(_count_row("PUNCHES LANDED", r["landed"], b["landed"]))
	var r_acc := roundi(100.0 * r["landed"] / maxf(r["thrown"], 1.0))
	var b_acc := roundi(100.0 * b["landed"] / maxf(b["thrown"], 1.0))
	out.append(["ACCURACY", "%d%%" % r_acc, "%d%%" % b_acc, _better(r_acc, b_acc)])
	out.append(_count_row("JABS LANDED", r["landed"] - r["power_landed"], b["landed"] - b["power_landed"]))
	out.append(_count_row("POWER PUNCHES", r["power_landed"], b["power_landed"]))
	out.append(_count_row("SIG. STRIKES", r["significant"], b["significant"]))
	out.append(_count_row("BIG PUNCHES", r["big"], b["big"]))
	out.append(_count_row("ONE-TWOS", r["one_twos"], b["one_twos"]))
	out.append(_count_row("PUNCHES AVOIDED", r["evaded"], b["evaded"]))
	out.append(_count_row("KNOCKDOWNS", blue.knockdowns_total, red.knockdowns_total))
	var r_hp := roundi(red.health)
	var b_hp := roundi(blue.health)
	out.append(["HEALTH AT THE END", str(r_hp), str(b_hp), _better(r_hp, b_hp)])
	return out


static func _count_row(text: String, red_value: int, blue_value: int) -> Array:
	return [text, str(red_value), str(blue_value), _better(red_value, blue_value)]


static func _better(red_value: int, blue_value: int) -> int:
	if red_value == blue_value:
		return -1
	return 0 if red_value > blue_value else 1


## How it ended, the money and the rankings.
func _result_box(sim: FightSim, summary: Dictionary, purse: int) -> void:
	var box := _box(PAD, "RESULT")
	var result := sim.result
	var winner: int = result["winner"]
	var how := ""
	match result["method"]:
		"KO", "TKO":
			how = "%s IN ROUND %d AT %s" % [result["method"], result["round"], result["time"]]
		"DRAW":
			how = "%s DRAW" % str(result["detail"])
		_:
			how = {"UD": "UNANIMOUS", "SD": "SPLIT", "MD": "MAJORITY"}[result["method"]] + " DECISION"
	var lines: Array = []
	if winner >= 0:
		var w: Fighter = sim.fighters[winner]
		lines.append(["WINNER", w.data.display_name().to_upper(), Palette.corner_color(winner)])
	lines.append(["METHOD", how, Palette.UI_TEXT])
	var shares := Purse.split(purse, winner < 0)
	lines.append(["PURSE", "%s  (%s / %s)" % [Purse.money_text(purse), Purse.money_text(shares[0]), Purse.money_text(shares[1])], Palette.UI_TEXT])
	for corner in 2:
		lines.append(["RED" if corner == 0 else "BLUE", _rank_change(sim, summary, corner), Palette.UI_TEXT,
				Palette.corner_color(corner)])
	for i in lines.size():
		var y := RESULT_ROW_Y + i * UiTheme.ROW_H
		var label_colour: Color = lines[i][3] if lines[i].size() > 3 else Palette.UI_TEXT_DIM
		box.add_child(UiTheme.place(UiTheme.label(lines[i][0], UiTheme.BODY, label_colour), PAD, y, 160, UiTheme.ROW_H))
		var value := UiTheme.label(lines[i][1], UiTheme.BODY, lines[i][2])
		UiTheme.fit(value, BOX_W - PAD * 2 - 160)
		box.add_child(UiTheme.place(value, PAD + 160, y, BOX_W - PAD * 2 - 160, UiTheme.ROW_H))


## "JOHNSON  6 > 2" - his ranking before and after (C = champion).
static func _rank_change(sim: FightSim, summary: Dictionary, corner: int) -> String:
	var key := "red_rank" if corner == 0 else "blue_rank"
	var before: int = summary.get(key, -1)
	var after: int = summary.get(key + "_after", -1)
	var surname: String = sim.fighters[corner].data.last_name.to_upper()
	if before < 0 or after < 0:
		return surname
	if before == after:
		return "%s  %s (SAME)" % [surname, _place(before)]
	return "%s  %s > %s" % [surname, _place(before), _place(after)]


static func _place(rank: int) -> String:
	return "C" if rank == 0 else str(rank)


## The rating: big number, a ten-segment bar and a word for it.
func _rating_box(rating: float) -> void:
	var box := _box(W - PAD - BOX_W, "MATCH RATING")
	var number := UiTheme.label("%.1f" % rating, UiTheme.HUGE, Palette.UI_GOLD)
	box.add_child(UiTheme.place(number, PAD, 32, 4 * UiTheme.HUGE, UiTheme.HUGE + 8))
	box.add_child(UiTheme.place(UiTheme.label("OUT OF 10", UiTheme.BODY, Palette.UI_TEXT_DIM), PAD + 4 * UiTheme.HUGE + PAD, 52, 192, UiTheme.ROW_H))
	var word := ""
	for entry in RATING_WORDS:
		if rating >= entry[0]:
			word = entry[1]
			break
	box.add_child(UiTheme.place(UiTheme.label(word, UiTheme.BODY, Palette.UI_TEXT), PAD, 96, BOX_W - PAD * 2, UiTheme.ROW_H))
	# One segment per point, lit up to the rating (part-lit for the decimal).
	var bar_x := float(PAD) + (BOX_W - PAD * 2 - (10 * SEGMENT_W + 9 * SEGMENT_GAP)) / 2.0
	for i in 10:
		var x := bar_x + i * (SEGMENT_W + SEGMENT_GAP)
		box.add_child(UiTheme.block(Palette.UI_PANEL_DARK, x, 144, SEGMENT_W, SEGMENT_H))
		var fill := clampf(rating - i, 0.0, 1.0)
		if fill > 0.0:
			box.add_child(UiTheme.block(Palette.UI_GOLD, x, 144, roundf(SEGMENT_W * fill), SEGMENT_H))


func _box(x: float, caption: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.place(holder, x, BOXES_Y, BOX_W, BOX_H))
	holder.add_child(UiTheme.panel(0, 0, BOX_W, BOX_H, Palette.UI_PANEL_DARK))
	holder.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.CAPTION, Palette.UI_GOLD), PAD, 10, 240, UiTheme.CAPTION))
	return holder


func _button(text: String, x: float, pressed_signal: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, BUTTON_Y, BUTTON_W, BUTTON_H)
	b.pressed.connect(func() -> void: pressed_signal.emit())
	add_child(b)
	return b
