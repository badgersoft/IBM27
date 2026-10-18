extends Control
## A boxer's profile, opened from the Boxers list: a portrait and everything
## about him, including all six skills. PREV and NEXT step through his
## division; BACK returns to the list on the same tab.
##
## Layout (1280 x 800 frame):
##   y  16  BOBBY WALKER [belt]            [< PREV] [NEXT >] [  BACK  ]
##   y  72  "THE OUTLAW"                          HEAVYWEIGHT  -  1 OF 30
##   y 112  +-- portrait --+  +-- details (832 x 240) ------------------+
##          |  400 x 672   |  +-- career  (832 x 136) ------------------+
##          |              |  +-- skills  (832 x 264) ------------------+
##   y 784  +--------------+
##
## The portrait is drawn at the same pixel scale for everyone (x3, like the
## arena), so a heavyweight fills more of the frame than a lightweight.

const FRAME_SIZE := Vector2(1280, 800)

const PORTRAIT := Rect2(16, 112, 400, 672)
const PORTRAIT_VIEW := Vector2i(128, 200)    ## Low-res pixels, shown at x3.
const PORTRAIT_SCALE := 3
const FIGURE_SIZE := 1.6                     ## Drawn larger than in the ring.
const FEET_Y := 186.0

const DETAILS := Rect2(432, 112, 832, 240)
const CAREER := Rect2(432, 368, 832, 136)
const SKILLS := Rect2(432, 520, 832, 264)
const PAD := 16
const CAPTION_Y := 10

# Details: the hometown across the panel, then two columns of label / value
# pairs, then the style's one-line description. Every value is 16 px text,
# and each column is wide enough for its longest possible value
# ("SANTIAGO DE CUBA, CUB", "5' 10\"  (178 CM)", "24  (100%)").
const DETAIL_ROW_Y := 36
const DETAIL_ROW_H := 32
const FROM_LABEL_W := 128
## Each column's labels get just the room they need ("EARNINGS" and "KNOCKOUTS"
## are the longest), leaving the left values room for "5' 10\"  (177 CM)".
const DETAIL_LABEL_W := [144, 176]
const DETAIL_COLUMN_X := [PAD, 432]
const DETAIL_COLUMN_END := [416, 816]
const BLURB_Y := 200
const MONSTER_BLURB := "Knockout artist: few men hear the final bell."

# Career: ranking and level, earnings and manager (same columns as the
# details), then what sort of manager he has.
const MANAGER_Y := 100

# Skills: label, bar, value.
const SKILL_ROW_Y := 28
const SKILL_ROW_H := 32
const SKILL_LABEL_W := 224
const BAR_X := 256
const BAR_W := 448
const BAR_H := 16
const VALUE_X := 720
const VALUE_W := 96

const SKILLS_SHOWN := [
	["POWER", "power"], ["SPEED", "speed"], ["STAMINA", "stamina"],
	["CHIN", "chin"], ["STRENGTH", "strength"], ["INTELLIGENCE", "intelligence"],
]

var _frame: Control
var _content: Control
var _division := 0
var _index := 0


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

	var back := _button("BACK", FRAME_SIZE.x - 16 - 192, 192, _go_back)
	var next := _button("NEXT >", back.position.x - 16 - 128, 128, _step.bind(1))
	_button("< PREV", next.position.x - 16 - 128, 128, _step.bind(-1))
	back.grab_focus()

	_division = GameState.profile_division
	_index = GameState.profile_index
	_show()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "profile":
		_capture(GameState.options["capture"])


func _button(text: String, x: float, w: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, 16, w, 48)
	b.pressed.connect(action)
	_frame.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _go_back() -> void:
	GameState.roster_tab = _division
	GameState.roster_page = floori(float(_index) / RosterScreen.PAGE_SIZE)   # The page he is on.
	get_tree().change_scene_to_file("res://scenes/roster.tscn")


## Moves to the previous (-1) or next (+1) boxer in the division, wrapping.
func _step(dir: int) -> void:
	var count := GameState.boxers_in(_division).size()
	_index = posmod(_index + dir, count)
	GameState.profile_index = _index
	_show()


func _show() -> void:
	if _content != null:
		_content.queue_free()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_content, 0, 0, FRAME_SIZE.x, FRAME_SIZE.y))

	var roster := GameState.listed_boxers(_division)
	var b: BoxerData = roster[_index]

	var title := UiTheme.label(b.display_name().to_upper(), UiTheme.TITLE, Palette.UI_GOLD)
	UiTheme.fit(title, 744)
	_content.add_child(UiTheme.place(title, 24, 24, 744, UiTheme.TITLE))
	if GameState.is_champion(b):
		# The belt (x4, 96 x 32) just after the name, level with its capitals.
		var belt := BeltIcon.new(4)
		belt.position = Vector2(24 + b.display_name().length() * UiTheme.TITLE + 16, 24)
		_content.add_child(belt)
	if not b.nickname.is_empty():
		var nick := UiTheme.label("\"%s\"" % b.nickname.to_upper(), UiTheme.BODY, Palette.UI_GOLD)
		_content.add_child(UiTheme.place(nick, 24, 72, 640, UiTheme.ROW_H))
	var where := "%s  -  %d OF %d" % [b.division_name().to_upper(), _index + 1, roster.size()]
	var where_label := UiTheme.label(where, UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_content.add_child(UiTheme.place(where_label, 664, 72, FRAME_SIZE.x - 16 - 664, UiTheme.ROW_H))

	_build_portrait(b)
	_build_details(b)
	_build_career(b)
	_build_skills(b)


# ============================================================================
#  Portrait
# ============================================================================

func _build_portrait(b: BoxerData) -> void:
	_content.add_child(UiTheme.panel(PORTRAIT.position.x, PORTRAIT.position.y, PORTRAIT.size.x, PORTRAIT.size.y))

	var viewport := SubViewport.new()
	viewport.size = PORTRAIT_VIEW
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_content.add_child(viewport)

	var backdrop := PortraitBackdrop.new()
	backdrop.size = Vector2(PORTRAIT_VIEW)
	backdrop.floor_y = FEET_Y
	viewport.add_child(backdrop)
	var rig := FrontRig.new()
	rig.setup_boxer(b, 0, true, FIGURE_SIZE)
	rig.set_glove_tones(Palette.TRUNKS[b.trunks_index]["tones"])   # No corner here.
	rig.position = Vector2(PORTRAIT_VIEW.x / 2.0, FEET_Y)
	viewport.add_child(rig)

	var view_size := Vector2(PORTRAIT_VIEW * PORTRAIT_SCALE)
	var view := TextureRect.new()
	view.texture = viewport.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var x := PORTRAIT.position.x + (PORTRAIT.size.x - view_size.x) / 2.0
	_content.add_child(UiTheme.place(view, x, PORTRAIT.position.y + 8, view_size.x, view_size.y))

	# Height and weight under the picture, centred in the space left below it.
	var below := PORTRAIT.position.y + 8 + view_size.y
	var free_h := PORTRAIT.end.y - below
	var caption := UiTheme.label("%s  -  %d LB" % [b.height_imperial(), b.weight_lb], UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(UiTheme.place(caption, PORTRAIT.position.x, below + (free_h - UiTheme.ROW_H) / 2.0, PORTRAIT.size.x, UiTheme.ROW_H))


# ============================================================================
#  Details
# ============================================================================

func _build_details(b: BoxerData) -> void:
	var panel := _panel(DETAILS, "DETAILS")
	var fights := b.total_fights()
	var ko_share := roundi(100.0 * b.kos / maxf(b.wins, 1.0))
	_detail(panel, PAD, DETAIL_ROW_Y, FROM_LABEL_W, DETAILS.size.x - PAD * 2 - FROM_LABEL_W,
			"FROM", "%s, %s" % [b.city.to_upper(), b.country_code])
	var columns := [
		[["AGE", str(b.age)],
		 ["HEIGHT", "%s  (%d CM)" % [b.height_imperial(), b.height_cm]],
		 ["WEIGHT", "%d LB" % b.weight_lb],
		 ["FIGHTS", str(fights)]],
		[["STYLE", b.style_name().to_upper()],
		 ["RECORD", b.record()],
		 ["KNOCKOUTS", "%d  (%d%%)" % [b.kos, ko_share]],
		 ["RECOVERY", str(b.recovery)]],
	]
	for c in columns.size():
		var x: float = DETAIL_COLUMN_X[c]
		var label_w: float = DETAIL_LABEL_W[c]
		var value_w: float = DETAIL_COLUMN_END[c] - x - label_w
		var rows: Array = columns[c]
		for r in rows.size():
			_detail(panel, x, DETAIL_ROW_Y + (r + 1) * DETAIL_ROW_H, label_w, value_w, rows[r][0], rows[r][1])
	# A monster's reputation goes before him; a glass jaw's weakness doesn't
	# (only his CHIN gives it away).
	var blurb_text := BoxerData.STYLE_BLURBS[b.style]
	if b.special == BoxerData.Special.MONSTER:
		blurb_text = MONSTER_BLURB
	var blurb := UiTheme.label(blurb_text.to_upper(), UiTheme.BODY, Palette.UI_GOLD)
	panel.add_child(UiTheme.place(blurb, PAD, BLURB_Y, DETAILS.size.x - PAD * 2, UiTheme.ROW_H))


func _build_career(b: BoxerData) -> void:
	var panel := _panel(CAREER, "CAREER")
	var table := GameState.rankings_for(b)
	var columns := [
		[["RANKING", table.rank_text(b)],
		 ["EARNINGS", Purse.money_text(b.earnings)]],
		[["LEVEL", Rankings.TIER_NAMES[table.tier_of(b)].to_upper()],
		 ["MANAGER", b.manager.short_name().to_upper()]],
	]
	for c in columns.size():
		var x: float = DETAIL_COLUMN_X[c]
		var label_w: float = DETAIL_LABEL_W[c]
		var value_w: float = DETAIL_COLUMN_END[c] - x - label_w
		var rows: Array = columns[c]
		for r in rows.size():
			_detail(panel, x, DETAIL_ROW_Y + r * DETAIL_ROW_H, label_w, value_w, rows[r][0], rows[r][1])
	var manager := "%s: %s" % [b.manager.type_name().to_upper(), b.manager.type_blurb().to_upper()]
	panel.add_child(UiTheme.place(UiTheme.label(manager, UiTheme.BODY, Palette.UI_GOLD), PAD, MANAGER_Y, CAREER.size.x - PAD * 2, UiTheme.ROW_H))


## One label / value pair, both 16 px.
func _detail(panel: Control, x: float, y: float, label_w: float, value_w: float, label: String, value: String) -> void:
	panel.add_child(UiTheme.place(UiTheme.label(label, UiTheme.BODY, Palette.UI_TEXT_DIM), x, y, label_w, UiTheme.ROW_H))
	panel.add_child(UiTheme.place(UiTheme.label(value, UiTheme.BODY, Palette.UI_TEXT), x + label_w, y, value_w, UiTheme.ROW_H))


# ============================================================================
#  Skills
# ============================================================================

func _build_skills(b: BoxerData) -> void:
	var panel := _panel(SKILLS, "SKILLS")
	for i in SKILLS_SHOWN.size():
		var skill: Array = SKILLS_SHOWN[i]
		_skill_row(panel, SKILL_ROW_Y + i * SKILL_ROW_H, skill[0], int(b.get(skill[1])), Palette.UI_TEXT)
	var rule_y := SKILL_ROW_Y + SKILLS_SHOWN.size() * SKILL_ROW_H + 4
	panel.add_child(UiTheme.block(Color(Palette.UI_TEXT_DIM, 0.4), PAD, rule_y, SKILLS.size.x - PAD * 2, 1))
	_skill_row(panel, rule_y + 4, "OVERALL", b.overall(), Palette.UI_GOLD)


## One row: name, a bar out of 99 coloured by how good it is, and the number.
func _skill_row(panel: Control, y: float, text: String, value: int, colour: Color) -> void:
	var text_y := y + (SKILL_ROW_H - UiTheme.ROW_H) / 2.0
	panel.add_child(UiTheme.place(UiTheme.label(text, UiTheme.BODY, colour), PAD, text_y, SKILL_LABEL_W, UiTheme.ROW_H))
	var bar_y := y + (SKILL_ROW_H - BAR_H) / 2.0
	panel.add_child(UiTheme.panel(BAR_X, bar_y, BAR_W, BAR_H, Palette.UI_PANEL_DARK, Color(Palette.UI_TEXT_DIM, 0.5), 2))
	var fill_w := roundf((BAR_W - 4) * clampf(value / 99.0, 0.0, 1.0))
	panel.add_child(UiTheme.block(_skill_colour(value), BAR_X + 2, bar_y + 2, fill_w, BAR_H - 4))
	var number := UiTheme.label(str(value), UiTheme.BODY, colour, HORIZONTAL_ALIGNMENT_RIGHT)
	panel.add_child(UiTheme.place(number, VALUE_X, text_y, VALUE_W, UiTheme.ROW_H))


static func _skill_colour(value: int) -> Color:
	if value >= 70:
		return Palette.UI_GOOD
	if value >= 50:
		return Palette.UI_WARN
	return Palette.UI_BAD


func _panel(rect: Rect2, caption: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(UiTheme.place(holder, rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	holder.add_child(UiTheme.panel(0, 0, rect.size.x, rect.size.y))
	holder.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.CAPTION, Palette.UI_GOLD), PAD, CAPTION_Y, 240, UiTheme.CAPTION))
	return holder


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
