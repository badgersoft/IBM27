class_name TaleOfTape
extends Control
## Pre-fight "tale of the tape" comparing the two boxers (1040 x 512).
## HEAD TO HEAD gives each man's wins in their earlier fights (gold for the
## man who leads), or FIRST MEETING.
##
## Classic layout: red corner values right-aligned against the centre labels,
## blue corner values left-aligned, so the eye can run straight across a row.
## For each skill the better number is shown in gold.

signal dismissed

const W := 1040
const H := 512
const PAD := 16
const VALUE_W := 384
const LABEL_W := 240
const TABLE_Y := 64

var _prompt: Label
var _blink := 0.0


## [param title_fight] if the IBC title is on the line; [param purse] in dollars.
func setup(red: BoxerData, blue: BoxerData, venue_id: int, rounds: int, title_fight: bool, purse: int) -> void:
	size = Vector2(W, H)
	add_child(UiTheme.panel(0, 0, W, H, Palette.UI_PANEL, Palette.UI_BORDER, 4))

	var title := UiTheme.label("TALE OF THE TAPE", UiTheme.LARGE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(title, 0, 12, W, UiTheme.LARGE))
	var billing := "%s  -  %s" % [FightLengths.level_name(rounds).to_upper(), red.division_name().to_upper()]
	if title_fight:
		billing = "%s %s TITLE" % [Rankings.TITLE_NAME, red.division_name().to_upper()]
	var bill := "%d ROUNDS  -  %s  -  %s" % [rounds, billing, Venues.venue_name(venue_id).to_upper()]
	if purse > 0:
		bill += "  -  PURSE %s" % Purse.money_text(purse)
	else:
		bill = "%d ROUNDS  -  EXHIBITION  -  %s" % [rounds, Venues.venue_name(venue_id).to_upper()]
	add_child(UiTheme.place(UiTheme.label(bill, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), 0, 44, W, UiTheme.CAPTION))

	var rows: Array = [
		["", "RED CORNER", "BLUE CORNER"],
		["NAME", red.display_name().to_upper(), blue.display_name().to_upper()],
		["NICKNAME", _nick(red), _nick(blue)],
		["RANKING", GameState.rankings_for(red).rank_text(red), GameState.rankings_for(blue).rank_text(blue)],
		["HOMETOWN", red.hometown().to_upper(), blue.hometown().to_upper()],
		["AGE", str(red.age), str(blue.age)],
		["RECORD", red.record_with_kos(), blue.record_with_kos()],
		_head_to_head(red, blue),
		["HEIGHT", _height(red), _height(blue)],
		["WEIGHT", "%d LB" % red.weight_lb, "%d LB" % blue.weight_lb],
		["STYLE", red.style_name().to_upper(), blue.style_name().to_upper()],
	]
	var skills := ["power", "speed", "stamina", "chin", "strength", "intelligence"]
	for s in skills:
		rows.append([s.to_upper(), red.get(s), blue.get(s)])

	for i in rows.size():
		var y := TABLE_Y + i * UiTheme.ROW_H
		if i % 2 == 1:
			add_child(UiTheme.block(Color(1, 1, 1, 0.04), PAD, y, W - PAD * 2, UiTheme.ROW_H))
		var row: Array = rows[i]
		var red_colour := Palette.UI_TEXT
		var blue_colour := Palette.UI_TEXT
		if i == 0:
			red_colour = Palette.UI_RED
			blue_colour = Palette.UI_BLUE
		elif row[0] == "HEAD TO HEAD":
			var h := GameState.season.head_to_head(red, blue)
			red_colour = Palette.UI_GOLD if h[0] > h[1] else Palette.UI_TEXT
			blue_colour = Palette.UI_GOLD if h[1] > h[0] else Palette.UI_TEXT
		elif row[0] == "RANKING":
			# The champion's line is in gold.
			red_colour = Palette.UI_GOLD if GameState.is_champion(red) else Palette.UI_TEXT
			blue_colour = Palette.UI_GOLD if GameState.is_champion(blue) else Palette.UI_TEXT
		elif row[1] is int:
			if row[1] > row[2]:
				red_colour = Palette.UI_GOLD
			elif row[2] > row[1]:
				blue_colour = Palette.UI_GOLD
		var red_label := UiTheme.label(str(row[1]), UiTheme.BODY, red_colour, HORIZONTAL_ALIGNMENT_RIGHT)
		var blue_label := UiTheme.label(str(row[2]), UiTheme.BODY, blue_colour, HORIZONTAL_ALIGNMENT_LEFT)
		var centre := UiTheme.label(row[0], UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.fit(red_label, VALUE_W - PAD)
		UiTheme.fit(blue_label, VALUE_W - PAD)
		add_child(UiTheme.place(red_label, PAD, y, VALUE_W - PAD, UiTheme.ROW_H))
		add_child(UiTheme.place(centre, PAD + VALUE_W, y, LABEL_W, UiTheme.ROW_H))
		add_child(UiTheme.place(blue_label, PAD + VALUE_W + LABEL_W + PAD, y, VALUE_W - PAD, UiTheme.ROW_H))

	_prompt = UiTheme.label("TAP OR PRESS SPACE TO FIGHT", UiTheme.CAPTION, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(_prompt, 0, H - 24, W, UiTheme.CAPTION))


func _process(delta: float) -> void:
	_blink += delta
	if _prompt:
		_prompt.visible = fmod(_blink, 1.0) < 0.7


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		dismissed.emit()
		accept_event()


## [label, red, blue]: each man's wins (and any draws) against the other, or
## FIRST MEETING with nothing either side.
static func _head_to_head(red: BoxerData, blue: BoxerData) -> Array:
	var h := GameState.season.head_to_head(red, blue)
	if h[0] + h[1] + h[2] == 0:
		return ["FIRST MEETING", "", ""]
	var draws := "  %d DRAW%s" % [h[2], "S" if h[2] > 1 else ""] if h[2] > 0 else ""
	return ["HEAD TO HEAD", _wins(h[0]) + draws, _wins(h[1]) + draws]


static func _wins(n: int) -> String:
	return "%d WIN%s" % [n, "" if n == 1 else "S"]


static func _nick(b: BoxerData) -> String:
	return "\"%s\"" % b.nickname.to_upper() if not b.nickname.is_empty() else "-"


static func _height(b: BoxerData) -> String:
	return b.height_imperial()
