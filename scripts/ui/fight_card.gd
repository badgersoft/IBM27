class_name FightCard
extends Control
## One fight as a card (W x H), for the Fixtures screen's fight-night board.
##
##   +------------------------------------------------+
##   | 12 ROUNDS  -  GRAND ARENA              [belt]  |   top line
##   | |  C   K. KASSYMOV                    33-1-0   |   red corner
##   | |  1   C. COTE                        49-1-0   |   blue corner
##   |------------------------------------------------|
##   | $60M                      8.4/10  [ KO 7 ]     |   purse, rating, result
##   +------------------------------------------------+
##
## A title fight and the player's own fight have a gold border (the belt, or
## YOUR FIGHT, top right). Once fought, the winner's name is gold and the
## loser's dim, and the result shows as a badge: red for a stoppage. A card
## can be a button (pressed) to pick the fight to watch.

signal pressed(fixture: Fixture)

const W := 400
const H := 136
const PAD := 16
const TOP_Y := 12
const CORNER_Y: Array[int] = [28, 56]
const RULE_Y := 88
const BOTTOM_Y := 96
const RANK_X := 28
const RANK_W := 40
const NAME_X := 80
const NAME_W := 224
const RECORD_W := 72
const BADGE := Vector2(112, 28)
const RATING_W := 96
const NAME_CHARS := 14

var fixture: Fixture


## [param show_month] puts the month on the top line (fights to come);
## [param mine] marks the player's fight; [param clickable] makes it a
## button while it is still to be fought.
func _init(f: Fixture, rankings: Array[Rankings], clickable: bool, show_month: bool, mine: bool) -> void:
	fixture = f
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var special := f.title or mine
	var border := Palette.UI_GOLD if special else Color(Palette.UI_TEXT_DIM, 0.45)
	if clickable and not f.is_done():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("normal", UiTheme.box(Palette.UI_PANEL, border, 2))
		var lit := UiTheme.box(Palette.UI_PANEL.lightened(0.08), Palette.UI_GOLD, 3)
		for state in ["hover", "focus", "pressed"]:
			b.add_theme_stylebox_override(state, lit)
		UiTheme.place(b, 0, 0, W, H)
		b.pressed.connect(func() -> void: pressed.emit(f))
		add_child(b)
	else:
		add_child(UiTheme.panel(0, 0, W, H, Palette.UI_PANEL, border, 2))

	# Top line: (month,) rounds and venue; the belt or YOUR FIGHT on the right.
	var top := "%d ROUNDS  -  %s" % [f.rounds, Venues.venue_name(f.venue).to_upper()]
	if f.title:
		top = "IBC TITLE  -  " + top
	if show_month and not f.is_done():
		top = "%s  -  %s" % [Season.short_month(f.month), top]
	add_child(UiTheme.place(UiTheme.label(top, UiTheme.CAPTION, Palette.UI_GOLD if f.title else Palette.UI_TEXT_DIM), PAD, TOP_Y, W - PAD * 2 - 96, UiTheme.CAPTION))
	if mine:
		add_child(UiTheme.place(UiTheme.label("YOUR FIGHT", UiTheme.CAPTION, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_RIGHT), W - PAD - 96, TOP_Y, 96, UiTheme.CAPTION))
	elif f.title:
		var belt := BeltIcon.new(1)
		belt.position = Vector2(W - PAD - belt.size.x, TOP_Y + 4 - belt.size.y / 2.0)
		add_child(belt)

	# The two corners.
	var winner := f.winner()
	for corner in 2:
		var b := f.red if corner == 0 else f.blue
		var y := CORNER_Y[corner]
		add_child(UiTheme.block(Palette.UI_RED if corner == 0 else Palette.UI_BLUE, PAD, y, 4, UiTheme.ROW_H))
		var rank := UiTheme.label(_rank(f, corner, rankings), UiTheme.BODY, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		add_child(UiTheme.place(rank, RANK_X, y + 4, RANK_W, UiTheme.ROW_H))
		var colour := Palette.UI_TEXT
		if winner != null:
			colour = Palette.UI_GOLD if winner == b else Palette.UI_TEXT_DIM
		add_child(UiTheme.place(UiTheme.label(_name(b), UiTheme.BODY, colour), NAME_X, y + 4, NAME_W, UiTheme.ROW_H))
		var record := UiTheme.label(b.record(), UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		add_child(UiTheme.place(record, W - PAD - RECORD_W, y + 12, RECORD_W, UiTheme.CAPTION))

	# Bottom line: the purse, then the rating and the result badge.
	add_child(UiTheme.block(Color(Palette.UI_TEXT_DIM, 0.3), PAD, RULE_Y, W - PAD * 2, 1))
	add_child(UiTheme.place(UiTheme.label(Purse.money_text(f.purse), UiTheme.BODY, Palette.UI_TEXT), PAD, BOTTOM_Y + 2, 160, UiTheme.ROW_H))
	var badge_x := W - PAD - BADGE.x
	if f.is_done():
		var rating := UiTheme.label("%.1f/10" % f.excitement, UiTheme.BODY, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		add_child(UiTheme.place(rating, badge_x - 16 - RATING_W, BOTTOM_Y + 2, RATING_W, UiTheme.ROW_H))
		var stoppage: bool = f.result.get("method", "") in ["KO", "TKO"]
		var fill := Color("8a2430") if stoppage else Palette.UI_PANEL_DARK
		add_child(UiTheme.panel(badge_x, BOTTOM_Y, BADGE.x, BADGE.y, fill, Color(Palette.UI_TEXT_DIM, 0.6), 2))
		var text := UiTheme.label(f.result_text(), UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		add_child(UiTheme.place(text, badge_x, BOTTOM_Y + 2, BADGE.x, UiTheme.ROW_H))
	else:
		var due := UiTheme.label("TO COME", UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		add_child(UiTheme.place(due, badge_x, BOTTOM_Y + 10, BADGE.x, UiTheme.CAPTION))


## The first button inside (for focus), or null if the card isn't clickable.
func button() -> Button:
	for child in get_children():
		if child is Button:
			return child
	return null


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
