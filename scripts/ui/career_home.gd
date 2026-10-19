extends Control
## The career home page: how the player's boxer stands, his next fight and
## any fight offers, this week's training, and the way to everything else.
##
## Layout (1280 x 800 frame):
##   y  16  +-- header (1248 x 232) ------------------------------------------+
##          | portrait | NAME "NICK"                  OVERALL  RANKING  ...   |
##   y 264  +-- NEXT FIGHT (608 x 160) --+  +-- FIGHT OFFERS (624 x 160) -----+
##   y 440  +-- TRAINING THIS WEEK (1248 x 168): four sessions -------------+
##   y 624  [SCHEDULE] [FACILITIES] [FIXTURES] [NEWS]
##   y 696  [BOXERS]   [SAVE]       [MAIN MENU] [NEXT WEEK]
##
## Training: one session a week (WEIGHTS, SPEED, STAMINA or PUNCHING); once
## chosen, the others are greyed out until next week. NEXT WEEK pays the
## rent and moves the calendar on; on the month's last week it goes to fight
## night (the Fixtures screen) instead.

const FRAME_SIZE := Vector2(1280, 800)
const PAD := 16
const HEADER := Rect2(16, 16, 1248, 232)
const NEXT_FIGHT := Rect2(16, 264, 608, 160)
const OFFERS := Rect2(640, 264, 624, 160)
const TRAINING := Rect2(16, 440, 1248, 168)
const MENU_Y := [624, 696]
const MENU_BUTTON := Vector2(288, 56)
const MENU_GAP := 32
const CAPTION_Y := 10
## Header details: two columns of label / value.
const DETAIL_X := [560, 912]
const DETAIL_LABEL_W := [144, 144]
const DETAIL_ROW_Y := 40
const DETAIL_ROW_H := 32
## Training: four session buttons across the panel.
const SESSION_Y := 40
const SESSION_SIZE := Vector2(288, 72)
const MAX_OFFERS_SHOWN := 3

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
	_build_header()
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

func _build_header() -> void:
	var panel := _panel(HEADER, "")
	var b := _career.boxer
	var table := _season.rankings_of(b)
	var portrait := BoxerPortrait.new(Vector2i(64, 104), 2, 0.9, 98.0)
	portrait.position = Vector2(PAD, PAD)
	panel.add_child(portrait)
	var x := PAD + portrait.size.x + 24
	var name_label := UiTheme.label(b.display_name().to_upper(), UiTheme.LARGE, Palette.UI_GOLD)
	UiTheme.fit(name_label, DETAIL_X[0] - x - PAD)
	panel.add_child(UiTheme.place(name_label, x, 40, DETAIL_X[0] - x - PAD, UiTheme.LARGE))
	var nick := "\"%s\"" % b.nickname.to_upper() if not b.nickname.is_empty() else ""
	panel.add_child(UiTheme.place(UiTheme.label(nick, UiTheme.BODY, Palette.UI_GOLD), x, 80, DETAIL_X[0] - x - PAD, UiTheme.ROW_H))
	var line := "%s  -  %s" % [b.division_name().to_upper(), b.style_name().to_upper()]
	panel.add_child(UiTheme.place(UiTheme.label(line, UiTheme.BODY, Palette.UI_TEXT_DIM), x, 112, DETAIL_X[0] - x - PAD, UiTheme.ROW_H))
	panel.add_child(UiTheme.place(UiTheme.label(_career.date_text(_season), UiTheme.BODY, Palette.UI_TEXT), x, 176, DETAIL_X[0] - x - PAD, UiTheme.ROW_H))
	portrait.show_boxer(b)

	var health := Facilities.condition_text(b.condition)
	var columns := [
		[["OVERALL", str(b.overall())],
		 ["RANKING", table.rank_text(b)],
		 ["LEVEL", Rankings.TIER_NAMES[table.tier_of(b)].to_upper()],
		 ["RECORD", b.record()],
		 ["KO", str(b.kos)]],
		[["HEALTH", "%s %d%%" % [health, roundi(b.condition)]],
		 ["MONEY", Purse.money_text(_career.money)],
		 ["EARNED", Purse.money_text(b.earnings)],
		 ["SPONSOR", "%d MONTHS" % int(_career.sponsor["months_left"]) if not _career.sponsor.is_empty() else "NONE"],
		 ["RENT", "%s/WEEK" % Purse.money_text(_career.weekly_costs())]],
	]
	for c in columns.size():
		var lx: float = DETAIL_X[c]
		var lw: float = DETAIL_LABEL_W[c]
		var end: float = HEADER.size.x - PAD if c == 1 else DETAIL_X[1] - PAD
		for r in (columns[c] as Array).size():
			var y := DETAIL_ROW_Y + r * DETAIL_ROW_H - 8
			panel.add_child(UiTheme.place(UiTheme.label(columns[c][r][0], UiTheme.BODY, Palette.UI_TEXT_DIM), lx, y, lw, UiTheme.ROW_H))
			var colour := Palette.UI_TEXT
			if columns[c][r][0] == "HEALTH":
				colour = Palette.UI_GOOD if b.condition >= 95.0 else (Palette.UI_WARN if b.condition >= 50.0 else Palette.UI_BAD)
			var value := UiTheme.label(columns[c][r][1], UiTheme.BODY, colour)
			UiTheme.fit(value, end - lx - lw)
			panel.add_child(UiTheme.place(value, lx + lw, y, end - lx - lw, UiTheme.ROW_H))


func _build_next_fight() -> void:
	var panel := _panel(NEXT_FIGHT, "NEXT FIGHT")
	var f := _season.booking(_career.boxer)
	if f == null:
		var why := "NONE ARRANGED"
		var hint := "SEE SCHEDULE TO FIND AN OPPONENT"
		if not _career.can_arrange(_season):
			hint = "YOU CAN ARRANGE ONE FROM %s" % Season.date_text(_career.free_from(_season))
		panel.add_child(UiTheme.place(UiTheme.label(why, UiTheme.LARGE, Palette.UI_TEXT), PAD, 48, NEXT_FIGHT.size.x - PAD * 2, UiTheme.LARGE))
		panel.add_child(UiTheme.place(UiTheme.label(hint, UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, 96, NEXT_FIGHT.size.x - PAD * 2, UiTheme.ROW_H))
		return
	var other := f.opponent_of(_career.boxer)
	var table := _season.rankings_of(other)
	var lines := [
		["V " + other.display_name().to_upper(), UiTheme.LARGE, Palette.UI_GOLD],
		["%s  %s  %s" % [table.rank_text(other), other.record(), "OVR %d" % other.overall()], UiTheme.BODY, Palette.UI_TEXT],
		["END OF %s  -  %d ROUNDS  -  %s" % [Season.date_text(f.month), f.rounds, Purse.money_text(f.purse)], UiTheme.BODY, Palette.UI_TEXT_DIM],
	]
	if f.title:
		lines[2][0] = "END OF %s  -  IBC TITLE  -  %s" % [Season.date_text(f.month), Purse.money_text(f.purse)]
	for i in lines.size():
		var l := UiTheme.label(lines[i][0], lines[i][1], lines[i][2])
		UiTheme.fit(l, NEXT_FIGHT.size.x - PAD * 2)
		panel.add_child(UiTheme.place(l, PAD, 40 + i * 36, NEXT_FIGHT.size.x - PAD * 2, maxi(lines[i][1], UiTheme.ROW_H)))


func _build_offers() -> void:
	var panel := _panel(OFFERS, "FIGHT OFFERS")
	# Three lines at most: offers, or two and "AND n MORE".
	var keen := _career.live_requests(_season)
	var room := MAX_OFFERS_SHOWN if keen.size() <= MAX_OFFERS_SHOWN else MAX_OFFERS_SHOWN - 1
	var shown := mini(keen.size(), room)
	for i in shown:
		var b := keen[i]
		var text := "%s  %s  WANTS A FIGHT" % [_season.rankings_of(b).rank_label(b), _short(b)]
		panel.add_child(UiTheme.place(UiTheme.label(text, UiTheme.BODY, Palette.UI_TEXT), PAD, 40 + i * 32, OFFERS.size.x - PAD * 2, UiTheme.ROW_H))
	if shown == 0:
		panel.add_child(UiTheme.place(UiTheme.label("NO OFFERS THIS MONTH", UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, 40, OFFERS.size.x - PAD * 2, UiTheme.ROW_H))
	elif keen.size() > shown:
		var more := "AND %d MORE - SEE SCHEDULE" % (keen.size() - shown)
		panel.add_child(UiTheme.place(UiTheme.label(more, UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, 40 + shown * 32, OFFERS.size.x - PAD * 2, UiTheme.ROW_H))


func _build_training() -> void:
	var panel := _panel(TRAINING, "TRAINING THIS WEEK")
	var gym: Dictionary = Facilities.TRAINING[_career.training_facility]
	var at := "AT THE %s" % str(gym["name"]).to_upper()
	panel.add_child(UiTheme.place(UiTheme.label(at, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT), 400, CAPTION_Y, TRAINING.size.x - PAD - 400, UiTheme.CAPTION))
	for i in Facilities.SESSIONS.size():
		var s: Array = Facilities.SESSIONS[i]
		var x := PAD + i * (SESSION_SIZE.x + (TRAINING.size.x - PAD * 2 - SESSION_SIZE.x * 4) / 3.0)
		var b := Button.new()
		b.text = s[0]
		b.focus_mode = Control.FOCUS_ALL
		UiTheme.place(b, x, SESSION_Y, SESSION_SIZE.x, SESSION_SIZE.y - 24)
		b.disabled = _career.trained >= 0
		if _career.trained == i:
			# This week's choice stays lit.
			b.disabled = false
			b.add_theme_stylebox_override("normal", UiTheme.box(Palette.UI_PANEL.lightened(0.15), Palette.UI_GOLD, 4))
			b.add_theme_color_override("font_color", Palette.UI_GOLD)
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(_train.bind(i))
		panel.add_child(b)
		var note: String = s[5]
		if _career.trained == i:
			note = _gains_text()
		var caption := UiTheme.label(note, UiTheme.CAPTION, Palette.UI_GOLD if _career.trained == i else Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		panel.add_child(UiTheme.place(caption, x, SESSION_Y + SESSION_SIZE.y - 12, SESSION_SIZE.x, UiTheme.CAPTION))
	var news := _career.news[0] if not _career.news.is_empty() else ""
	panel.add_child(UiTheme.place(UiTheme.label(news, UiTheme.BODY, Palette.UI_TEXT), PAD, TRAINING.size.y - 40, TRAINING.size.x - PAD * 2, UiTheme.ROW_H))


## "STRENGTH +2.6  CHIN +1.3"
func _gains_text() -> String:
	var parts: Array[String] = []
	for skill in _career.last_gains:
		parts.append("%s +%.1f" % [str(skill).to_upper(), _career.last_gains[skill]])
	return "  ".join(parts)


func _build_menu() -> void:
	var rows := [
		[["SCHEDULE", _open.bind("res://scenes/schedule.tscn")], ["FACILITIES", _open.bind("res://scenes/facilities.tscn")],
		 ["FIXTURES", _open.bind("res://scenes/fixtures.tscn")], ["NEWS", _news]],
		[["BOXERS", _open.bind("res://scenes/roster.tscn")], ["SAVE", _save],
		 ["MAIN MENU", _to_menu], ["NEXT WEEK", _next_week]],
	]
	for r in rows.size():
		for i in (rows[r] as Array).size():
			var b := Button.new()
			b.text = rows[r][i][0]
			b.focus_mode = Control.FOCUS_ALL
			UiTheme.place(b, PAD + i * (MENU_BUTTON.x + MENU_GAP), MENU_Y[r], MENU_BUTTON.x, MENU_BUTTON.y)
			b.pressed.connect(rows[r][i][1])
			_frame.add_child(b)
			if b.text == "NEWS":
				b.disabled = _season.papers.is_empty()
			if b.text == "NEXT WEEK":
				b.text = "FIGHT NIGHT" if _career.fight_week() else "NEXT WEEK"
				b.add_theme_color_override("font_color", Palette.UI_GOLD)
				b.grab_focus()


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

func _panel(rect: Rect2, caption: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(holder, rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	holder.add_child(UiTheme.panel(0, 0, rect.size.x, rect.size.y))
	if not caption.is_empty():
		holder.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.CAPTION, Palette.UI_GOLD), PAD, CAPTION_Y, 320, UiTheme.CAPTION))
	return holder


static func _short(b: BoxerData) -> String:
	return "%s. %s" % [b.first_name.substr(0, 1).to_upper(), b.last_name.to_upper()]


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
