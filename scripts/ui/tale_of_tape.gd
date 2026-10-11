class_name TaleOfTape
extends Control
## Pre-fight "tale of the tape" comparing the two boxers (1040 x 456).
##
## Classic layout: red corner values right-aligned against the centre labels,
## blue corner values left-aligned, so the eye can run straight across a row.
## For each skill the better number is shown in gold.

signal dismissed

const W := 1040
const H := 456
const PAD := 16
const VALUE_W := 384
const LABEL_W := 240
const TABLE_Y := 80

var _prompt: Label
var _blink := 0.0


func setup(red: BoxerData, blue: BoxerData, venue_id: int, rounds: int) -> void:
	size = Vector2(W, H)
	add_child(UiTheme.panel(0, 0, W, H, Palette.UI_PANEL, Palette.UI_BORDER, 4))

	var title := UiTheme.label("TALE OF THE TAPE", UiTheme.LARGE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(title, 0, 16, W, 32))
	var bill := "%d ROUNDS  -  MIDDLEWEIGHT  -  %s" % [rounds, Venues.venue_name(venue_id).to_upper()]
	add_child(UiTheme.place(UiTheme.label(bill, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), 0, 52, W, 12))

	var rows: Array = [
		["", "RED CORNER", "BLUE CORNER"],
		["NAME", red.display_name().to_upper(), blue.display_name().to_upper()],
		["NICKNAME", _nick(red), _nick(blue)],
		["HOMETOWN", red.hometown().to_upper(), blue.hometown().to_upper()],
		["HEIGHT", _height(red), _height(blue)],
		["WEIGHT", "%d LB" % red.weight_lb, "%d LB" % blue.weight_lb],
		["STYLE", red.style_name().to_upper(), blue.style_name().to_upper()],
	]
	var skills := ["power", "speed", "stamina", "chin", "strength", "intelligence"]
	for s in skills:
		rows.append([s.to_upper(), red.get(s), blue.get(s)])
	rows.append(["HEALTH", roundi(red.start_health), roundi(blue.start_health)])

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
	add_child(UiTheme.place(_prompt, 0, H - 32, W, 12))


func _process(delta: float) -> void:
	_blink += delta
	if _prompt:
		_prompt.visible = fmod(_blink, 1.0) < 0.7


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		dismissed.emit()
		accept_event()


static func _nick(b: BoxerData) -> String:
	return "\"%s\"" % b.nickname.to_upper() if not b.nickname.is_empty() else "-"


static func _height(b: BoxerData) -> String:
	return "%d CM  %s" % [b.height_cm, b.height_imperial()]
