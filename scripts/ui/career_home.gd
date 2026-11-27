extends Control
## The career home page: how the player's boxer stands, his next fight and
## any fight offers, this week's training, and the way to everything else.
##
## Layout (1280 x 800 frame):
##   y  16  WEEK 1 OF JANUARY 2027                   FIGHT NIGHT IN 3 WEEKS
##   y  80  +- menu -+  +-- boxer (1008 x 176): portrait, name, six tiles ---+
##          |SCHEDULE|  +-- NEXT FIGHT (496 x 152) --+ +-- FIGHT OFFERS -----+
##          |FIXTURES|  +-- TRAINING THIS WEEK (1008 x 344) -----------------+
##          |  ...   |  |  six skill bars, this week's gains                 |
##          |        |  |  [WEIGHTS] [SPEED] [STAMINA] [PUNCHING] [RECOVERY]  |
##          |NEXT    |  |  the latest news                                   |
##   y 784  +--------+  +----------------------------------------------------+
##
## Training: one session a week (WEIGHTS, SPEED, STAMINA, PUNCHING, or
## RECOVERY to get his health back); once chosen, the others are greyed out
## until next week. NEXT WEEK pays the rent and moves the calendar on; on
## the month's last week it goes to fight night (the Fixtures screen)
## instead.

const FRAME_SIZE := Vector2(1280, 800)
const PAD := 16
const CAPTION_Y := 10
## The date line across the top: the week and month on the left, how long
## to fight night on the right.
const DATE_LINE := Rect2(24, 16, 1232, 32)
## The menu down the left, NEXT WEEK (the main thing to press) at its foot.
const MENU_X := 16
const MENU_W := 224
const MENU_Y := 80
const MENU_H := 48
const MENU_GAP := 8
const NEXT_WEEK := Rect2(16, 712, 224, 72)
## The panels, right of the menu.
const HERO := Rect2(256, 80, 1008, 176)
const NEXT_FIGHT := Rect2(256, 272, 496, 152)
const OFFERS := Rect2(768, 272, 496, 152)
const TRAINING := Rect2(256, 440, 1008, 344)
## The boxer panel: the portrait, his name and so on, then two rows of three
## tiles (caption, value, a line under it).
const NAME_X := 160
const NAME_W := 344
const TILE_X := 520
const TILE := Vector2(152, 72)
const TILE_GAP := 8
## Training: his six skills as bars, three to a column...
const SKILLS_SHOWN: Array[String] = ["power", "speed", "stamina", "chin", "strength", "intelligence"]
const SKILL_Y := 32
const SKILL_ROW_H := 32
const SKILL_COLUMN_X: Array[int] = [16, 520]
const SKILL_LABEL_W := 208
const SKILL_BAR_W := 136
const SKILL_VALUE_W := 48
const SKILL_GAIN_W := 64
## ...the five session buttons under them, and the latest news.
const SESSION_Y := 144
const SESSION_SIZE := Vector2(176, 48)
const SESSION_CAPTION_Y := 200
const NEWS_Y := 232
const NEWS_LINES := 3
## Fight offers: up to three rows; the rank (right-aligned), the name, and
## WANTS A FIGHT.
const MAX_OFFERS_SHOWN := 3
const OFFER_ROW_Y := 40
const OFFER_ROW_H := 32
const OFFER_COLUMNS := [16, 80, 272]
const OFFER_RANK_W := 48
## Quiet borders: gold is kept for what matters.
const QUIET_BORDER := Color(0.55, 0.58, 0.70, 0.45)

var _frame: Control
var _career: PlayerCareer
var _season: Season


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := UiTheme.block(Palette.UI_BACKGROUND, 0, 0, 0, 0)
	add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.offset_left = -FRAME_SIZE.x / 2.0
	_frame.offset_top = -FRAME_SIZE.y / 2.0
	_frame.offset_right = FRAME_SIZE.x / 2.0
	_frame.offset_bottom = FRAME_SIZE.y / 2.0
	add_child(_frame)

	GameState.ensure_career()
	_career = GameState.career
	_season = GameState.season
	GameState.back_scene = "res://scenes/career_home.tscn"
	GameState.picking = false
	_build()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "career":
		_capture(GameState.options["capture"])


func _build() -> void:
	for child in _frame.get_children():
		child.queue_free()
	_build_date_line()
	_build_hero()
	_build_next_fight()
	_build_offers()
	_build_training()
	_build_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_to_menu()


# ============================================================================
#  Panels
# ============================================================================

## "WEEK 2 OF JANUARY 2027" on the left; on the right the weeks to fight
## night, or FIGHT NIGHT itself in the last week of the month.
func _build_date_line() -> void:
	var date := UiTheme.label(_career.date_text(_season), UiTheme.TITLE, Palette.UI_GOLD)
	_frame.add_child(UiTheme.place(date, DATE_LINE.position.x, DATE_LINE.position.y, DATE_LINE.size.x, DATE_LINE.size.y))
	var to_go := PlayerCareer.WEEKS_PER_MONTH - 1 - _career.week
	var right: Label
	if to_go == 0:
		right = UiTheme.label("FIGHT NIGHT", UiTheme.TITLE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		var when := "FIGHT NIGHT NEXT WEEK" if to_go == 1 else "FIGHT NIGHT IN %d WEEKS" % to_go
		right = UiTheme.label(when, UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		right.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_frame.add_child(UiTheme.place(right, DATE_LINE.position.x, DATE_LINE.position.y, DATE_LINE.size.x, DATE_LINE.size.y))


## The portrait, his name, nickname, division and style (and special punch),
## then six tiles: OVERALL, RANKING, RECORD / HEALTH, MONEY, SPONSOR.
func _build_hero() -> void:
	var panel := _panel(HERO, "")
	var b := _career.boxer
	var table := _season.rankings_of(b)
	var portrait := BoxerPortrait.new(Vector2i(64, 72), 2, 0.66, 70.0)
	portrait.position = Vector2(PAD, PAD)
	panel.add_child(portrait)
	portrait.show_boxer(b)
	var name_label := UiTheme.label(b.display_name().to_upper(), UiTheme.LARGE, Palette.UI_GOLD)
	panel.add_child(UiTheme.place(name_label, NAME_X, 24, NAME_W, UiTheme.LARGE))
	var nick := "\"%s\"" % b.nickname.to_upper() if not b.nickname.is_empty() else ""
	panel.add_child(UiTheme.place(UiTheme.label(nick, UiTheme.BODY, Palette.UI_GOLD), NAME_X, 64, NAME_W, UiTheme.ROW_H))
	panel.add_child(UiTheme.place(UiTheme.label(b.division_name().to_upper(), UiTheme.BODY, Palette.UI_TEXT_DIM), NAME_X, 96, NAME_W, UiTheme.ROW_H))
	panel.add_child(UiTheme.place(UiTheme.label(b.style_line(), UiTheme.BODY, Palette.UI_TEXT_DIM), NAME_X, 128, NAME_W, UiTheme.ROW_H))

	var health_colour := Palette.UI_GOOD if b.condition >= 95.0 else (Palette.UI_WARN if b.condition >= 50.0 else Palette.UI_BAD)
	var sponsor := "NONE"
	var offers := _career.sponsor_offers.size()
	var sponsor_note := "%d OFFER%s" % [offers, "" if offers == 1 else "S"] if offers > 0 else ""
	if not _career.sponsor.is_empty():
		sponsor = "%d MONTHS" % int(_career.sponsor["months_left"])
		sponsor_note = str(_career.sponsor["name"]).to_upper()
	var tiles := [
		["OVERALL", str(b.overall()), Palette.UI_GOLD, ""],
		["RANKING", table.rank_text(b), Palette.UI_TEXT, Rankings.TIER_NAMES[table.tier_of(b)].to_upper()],
		["RECORD", b.record(), Palette.UI_TEXT, "%d KO" % b.kos],
		["HEALTH", "%d%%" % roundi(b.condition), health_colour, Facilities.condition_text(b.condition)],
		["MONEY", Purse.money_text(_career.money), Palette.UI_TEXT, "EARNED %s" % Purse.money_text(b.earnings)],
		["SPONSOR", sponsor, Palette.UI_TEXT, sponsor_note],
	]
	for i in tiles.size():
		var x := TILE_X + (i % 3) * (TILE.x + TILE_GAP)
		var y := PAD + int(i / 3.0) * (TILE.y + TILE_GAP)
		panel.add_child(UiTheme.panel(x, y, TILE.x, TILE.y, Palette.UI_PANEL_DARK, QUIET_BORDER, 1))
		panel.add_child(UiTheme.place(UiTheme.label(tiles[i][0], UiTheme.CAPTION, Palette.UI_TEXT_DIM), x + 8, y + 8, TILE.x - 16, UiTheme.CAPTION))
		var value := UiTheme.label(tiles[i][1], UiTheme.LARGE if i == 0 else UiTheme.BODY, tiles[i][2])
		panel.add_child(UiTheme.place(value, x + 8, y + 24, TILE.x - 16, UiTheme.LARGE))
		var note := UiTheme.label(tiles[i][3], UiTheme.CAPTION, Palette.UI_TEXT_DIM)
		note.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		panel.add_child(UiTheme.place(note, x + 8, y + TILE.y - 16, TILE.x - 16, UiTheme.CAPTION))


func _build_next_fight() -> void:
	var panel := _panel(NEXT_FIGHT, "NEXT FIGHT")
	var w := NEXT_FIGHT.size.x - PAD * 2
	var f := _season.booking(_career.boxer)
	if f == null:
		var hint := "SEE SCHEDULE TO FIND ONE"
		if not _career.can_arrange(_season):
			hint = "YOU CAN ARRANGE ONE FROM %s" % Season.date_text(_career.free_from(_season))
		panel.add_child(UiTheme.place(UiTheme.label("NONE ARRANGED", UiTheme.LARGE, Palette.UI_TEXT), PAD, 40, w, UiTheme.LARGE))
		panel.add_child(UiTheme.place(UiTheme.label(hint, UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, 88, w, UiTheme.ROW_H))
		return
	var other := f.opponent_of(_career.boxer)
	var table := _season.rankings_of(other)
	var lines := [
		["V " + other.display_name().to_upper(), UiTheme.LARGE, Palette.UI_GOLD],
		["%s  %s  OVR %d" % [table.rank_text(other), other.record(), other.overall()], UiTheme.BODY, Palette.UI_TEXT],
		["%s - %d ROUNDS - %s" % [_short_date(f.month), f.rounds, Purse.money_text(f.purse)], UiTheme.BODY, Palette.UI_TEXT_DIM],
	]
	if f.title:
		lines[2][0] = "%s - IBC TITLE - %s" % [_short_date(f.month), Purse.money_text(f.purse)]
	for i in lines.size():
		var l := UiTheme.label(lines[i][0], lines[i][1], lines[i][2])
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		panel.add_child(UiTheme.place(l, PAD, [40, 80, 112][i], w, maxi(lines[i][1], UiTheme.ROW_H)))


func _build_offers() -> void:
	var panel := _panel(OFFERS, "FIGHT OFFERS")
	# Three lines at most: offers, or two and "AND n MORE". Columns: the
	# rank (right-aligned), the name, then WANTS A FIGHT.
	var keen := _career.live_requests(_season)
	var room := MAX_OFFERS_SHOWN if keen.size() <= MAX_OFFERS_SHOWN else MAX_OFFERS_SHOWN - 1
	var shown := mini(keen.size(), room)
	for i in shown:
		var b := keen[i]
		var y := OFFER_ROW_Y + i * OFFER_ROW_H
		var rank := UiTheme.label(_season.rankings_of(b).rank_label(b), UiTheme.BODY, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
		panel.add_child(UiTheme.place(rank, OFFER_COLUMNS[0], y, OFFER_RANK_W, UiTheme.ROW_H))
		panel.add_child(UiTheme.place(UiTheme.label(_short(b), UiTheme.BODY, Palette.UI_TEXT), OFFER_COLUMNS[1], y, OFFER_COLUMNS[2] - OFFER_COLUMNS[1] - 16, UiTheme.ROW_H))
		panel.add_child(UiTheme.place(UiTheme.label("WANTS A FIGHT", UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT), OFFER_COLUMNS[2], y, OFFERS.size.x - PAD - OFFER_COLUMNS[2], UiTheme.ROW_H))
	if shown == 0:
		panel.add_child(UiTheme.place(UiTheme.label("NO OFFERS THIS MONTH", UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, OFFER_ROW_Y, OFFERS.size.x - PAD * 2, UiTheme.ROW_H))
	elif keen.size() > shown:
		var more := "AND %d MORE - SEE SCHEDULE" % (keen.size() - shown)
		panel.add_child(UiTheme.place(UiTheme.label(more, UiTheme.BODY, Palette.UI_TEXT_DIM), OFFER_COLUMNS[1], OFFER_ROW_Y + shown * OFFER_ROW_H, OFFERS.size.x - PAD - OFFER_COLUMNS[1], UiTheme.ROW_H))


func _build_training() -> void:
	var panel := _panel(TRAINING, "TRAINING THIS WEEK")
	var gym: Dictionary = Facilities.TRAINING[_career.training_facility]
	var at := "AT THE %s  -  RENT %s/WEEK" % [str(gym["name"]).to_upper(), Purse.money_text(_career.weekly_costs())]
	panel.add_child(UiTheme.place(UiTheme.label(at, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT), 400, CAPTION_Y, TRAINING.size.x - PAD - 400, UiTheme.CAPTION))
	_build_skills(panel)
	var count := Facilities.SESSIONS.size()
	var gap := (TRAINING.size.x - PAD * 2 - SESSION_SIZE.x * count) / float(count - 1)
	for i in count:
		var s: Array = Facilities.SESSIONS[i]
		var x := PAD + i * (SESSION_SIZE.x + gap)
		var b := Button.new()
		b.text = s[0]
		b.focus_mode = Control.FOCUS_ALL
		UiTheme.place(b, x, SESSION_Y, SESSION_SIZE.x, SESSION_SIZE.y)
		# Tinted, so the sessions read differently from the menu.
		b.add_theme_stylebox_override("normal", UiTheme.box(Palette.UI_TRAIN, Palette.UI_TRAIN_BORDER, 2))
		b.add_theme_stylebox_override("hover", UiTheme.box(Palette.UI_TRAIN.lightened(0.12), Palette.UI_GOLD, 2))
		b.add_theme_stylebox_override("pressed", UiTheme.box(Palette.UI_TRAIN.darkened(0.2), Palette.UI_GOLD, 2))
		b.disabled = _career.trained >= 0
		var fit := i == Facilities.Session.RECOVERY and _career.boxer.condition >= 100.0
		if fit:
			b.disabled = true   # Nothing to recover.
		if _career.trained == i:
			# This week's choice stays lit.
			b.disabled = false
			b.add_theme_stylebox_override("normal", UiTheme.box(Palette.UI_TRAIN.lightened(0.15), Palette.UI_GOLD, 2))
			b.add_theme_color_override("font_color", Palette.UI_GOLD)
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(_train.bind(i))
		panel.add_child(b)
		var note: String = "ALREADY FULLY FIT" if fit else s[5]
		if _career.trained == i and not _gains_text().is_empty():
			note = _gains_text()
		var caption := UiTheme.label(note, UiTheme.CAPTION, Palette.UI_GOLD if _career.trained == i else Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		panel.add_child(UiTheme.place(caption, x, SESSION_CAPTION_Y, SESSION_SIZE.x, UiTheme.CAPTION))
	# The latest news, newest first (and brightest).
	panel.add_child(UiTheme.block(QUIET_BORDER, PAD, NEWS_Y - 8, TRAINING.size.x - PAD * 2, 1))
	panel.add_child(UiTheme.place(UiTheme.label("NEWS", UiTheme.CAPTION, Palette.UI_GOLD), PAD, NEWS_Y, 160, UiTheme.CAPTION))
	for i in mini(_career.news.size(), NEWS_LINES):
		var line := UiTheme.label(_career.news[i], UiTheme.BODY, Palette.UI_TEXT if i == 0 else Palette.UI_TEXT_DIM)
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		panel.add_child(UiTheme.place(line, PAD, NEWS_Y + 16 + i * 32, TRAINING.size.x - PAD * 2, UiTheme.ROW_H))


## His six skills as bars, three to a column, with what this week's
## session added beside each one it trained.
func _build_skills(panel: Control) -> void:
	var b := _career.boxer
	for i in SKILLS_SHOWN.size():
		var skill := SKILLS_SHOWN[i]
		var x: float = SKILL_COLUMN_X[int(i / 3.0)]
		var y := SKILL_Y + (i % 3) * SKILL_ROW_H
		panel.add_child(UiTheme.place(UiTheme.label(BoxerData.skill_label(skill), UiTheme.BODY, Palette.UI_TEXT_DIM), x, y, SKILL_LABEL_W, UiTheme.ROW_H))
		var bar_x := x + SKILL_LABEL_W
		var value: int = b.get(skill)
		panel.add_child(UiTheme.block(Palette.UI_PANEL_DARK, bar_x, y + 6, SKILL_BAR_W, 12))
		panel.add_child(UiTheme.block(Palette.UI_GOOD.darkened(0.25), bar_x, y + 6, SKILL_BAR_W * value / 99.0, 12))
		var number := UiTheme.label(str(value), UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		panel.add_child(UiTheme.place(number, bar_x + SKILL_BAR_W + 8, y, SKILL_VALUE_W, UiTheme.ROW_H))
		var gain: float = _career.last_gains.get(skill, 0.0)
		if gain > 0.0:
			var up := UiTheme.label("+%.1f" % gain, UiTheme.BODY, Palette.UI_GOOD, HORIZONTAL_ALIGNMENT_RIGHT)
			panel.add_child(UiTheme.place(up, bar_x + SKILL_BAR_W + 8 + SKILL_VALUE_W + 8, y, SKILL_GAIN_W, UiTheme.ROW_H))


## What this week's session did that the skills strip doesn't show:
## "RECOVERY +0.6" or "HEALTH +12%" ("" if nothing).
func _gains_text() -> String:
	var parts: Array[String] = []
	for skill in _career.last_gains:
		if SKILLS_SHOWN.has(skill):
			continue
		if skill == "health":
			parts.append("HEALTH +%d%%" % roundi(_career.last_gains[skill]))
		else:
			parts.append("%s +%.1f" % [BoxerData.skill_label(str(skill)), _career.last_gains[skill]])
	return "  ".join(parts)


## The menu down the left (quiet buttons), and NEXT WEEK (or FIGHT NIGHT)
## at its foot, gold.
func _build_menu() -> void:
	var items := [
		["SCHEDULE", _open.bind("res://scenes/schedule.tscn")], ["FIXTURES", _open.bind("res://scenes/fixtures.tscn")],
		["FACILITIES", _open.bind("res://scenes/facilities.tscn")], ["BOXERS", _open.bind("res://scenes/roster.tscn")],
		["NEWS", _news], ["SAVE", _save], ["MAIN MENU", _to_menu],
	]
	for i in items.size():
		var b := Button.new()
		b.text = items[i][0]
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_stylebox_override("normal", UiTheme.box(Palette.UI_PANEL, QUIET_BORDER, 2))
		UiTheme.place(b, MENU_X, MENU_Y + i * (MENU_H + MENU_GAP), MENU_W, MENU_H)
		b.pressed.connect(items[i][1])
		_frame.add_child(b)
		if b.text == "NEWS":
			b.disabled = _season.papers.is_empty()
	var next := Button.new()
	next.text = "FIGHT NIGHT" if _career.fight_week() else "NEXT WEEK"
	next.focus_mode = Control.FOCUS_ALL
	next.add_theme_stylebox_override("normal", UiTheme.box(Palette.UI_GOLD.darkened(0.35), Palette.UI_GOLD, 3))
	next.add_theme_stylebox_override("hover", UiTheme.box(Palette.UI_GOLD.darkened(0.2), Palette.UI_GOLD, 3))
	next.add_theme_stylebox_override("focus", UiTheme.box(Palette.UI_GOLD.darkened(0.2), Palette.UI_TEXT, 3))
	next.add_theme_color_override("font_color", Palette.UI_TEXT)
	next.add_theme_color_override("font_focus_color", Palette.UI_TEXT)
	next.add_theme_color_override("font_hover_color", Palette.UI_TEXT)
	UiTheme.place(next, NEXT_WEEK.position.x, NEXT_WEEK.position.y, NEXT_WEEK.size.x, NEXT_WEEK.size.y)
	next.pressed.connect(_next_week)
	_frame.add_child(next)
	next.grab_focus()


# ============================================================================
#  Actions
# ============================================================================

func _train(session: int) -> void:
	_career.train(session)
	_build()


func _next_week() -> void:
	if _career.fight_week():
		# The month's fights: watch his, have the rest fought, read the paper.
		get_tree().change_scene_to_file("res://scenes/fixtures.tscn")
		return
	_career.end_week()
	_build()


func _news() -> void:
	GameState.paper_index = _season.papers.size() - 1
	get_tree().change_scene_to_file("res://scenes/newspaper.tscn")


func _save() -> void:
	if GameState.save_career():
		_career.news.push_front("CAREER SAVED.")
	_build()


func _open(scene: String) -> void:
	get_tree().change_scene_to_file(scene)


## Saves on the way out.
func _to_menu() -> void:
	GameState.save_career()
	GameState.back_scene = "res://scenes/main_menu.tscn"
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ============================================================================
#  Helpers
# ============================================================================

## A panel with a quiet border and an optional gold caption.
func _panel(rect: Rect2, caption: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(holder, rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	holder.add_child(UiTheme.panel(0, 0, rect.size.x, rect.size.y, Palette.UI_PANEL, QUIET_BORDER, 2))
	if not caption.is_empty():
		holder.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.CAPTION, Palette.UI_GOLD), PAD, CAPTION_Y, 320, UiTheme.CAPTION))
	return holder


## "MAR 2027".
static func _short_date(month: int) -> String:
	return "%s %d" % [Season.short_month(month), Season.START_YEAR + floori(month / 12.0)]


static func _short(b: BoxerData) -> String:
	return "%s. %s" % [b.first_name.substr(0, 1).to_upper(), b.last_name.to_upper()]


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
