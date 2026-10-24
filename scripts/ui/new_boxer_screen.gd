extends Control
## Creating the boxer for a new career.
##
## He starts with a random look, name and hometown, and every skill at
## BoxerGenerator.player_start_skill() for his division (a lightweight is
## quicker, a heavyweight hits harder). PlayerCareer.START_POOL more points
## go where the player likes: + takes a point from the pool, - gives it back
## (down to MIN_SKILL, up to MAX_SKILL). The points he has spent stay with
## him if he changes division.
##
## Layout (1280 x 800 frame):
##   y  16  NEW BOXER                          [START CAREER]  [BACK]
##   y  80  +-portrait-+  +-- BOXER (448 x 368) --+  +-- SKILLS (432 x 368) --+
##          | 336 x 704|  | name, skin, hair,      |  | six skills, - and +,   |
##          |          |  | trunks, gloves, boots  |  | points left            |
##   y 464  |  OVERALL |  +-- NICKNAME (x 320) --+  +-- FROM (x 320) --------+
##          | DIVISION |  | ten to choose, or none |  | country list           |
##          |  STYLE   |  |                        |  | city list              |
##   y 784  +----------+  +------------------------+  +------------------------+
## The two columns share their rows: POINTS AVAILABLE sits level with NAME
## and SURNAME, and the six skills line up with the six pickers (SKIN to
## BOOTS). DIVISION and STYLE sit under the portrait.

const FRAME_SIZE := Vector2(1280, 800)
const PAD := 16
const PORTRAIT := Rect2(16, 80, 336, 704)
const BOXER := Rect2(368, 80, 448, 368)
const NICKNAME := Rect2(368, 464, 448, 320)
const SKILLS := Rect2(832, 80, 432, 368)
const FROM := Rect2(832, 464, 432, 320)
const CAPTION_Y := 10
## The portrait panel: the picture, OVERALL and his size, then DIVISION and
## STYLE (a caption over each < value > picker).
const PICTURE_VIEW := Vector2i(104, 152)
const PICTURE_FIGURE := 1.22
const PICTURE_FEET := 141.0
const OVERALL_Y := 480
const SIZE_Y := 512
const SIDE_PICKERS_Y: Array[int] = [568, 632]
const SIDE_CAPTION_GAP := 16
## Scrolling lists: a frame LIST_INSET bigger all round than the list,
## which shows a whole number of LIST_ROW_H rows and clips the rest, so no
## row is ever cut in half.
const LIST_INSET := 8
const LIST_ROW_H := 24
## NICKNAME panel: ten rows shown (the eleventh choice scrolls), its frame
## level with the country list's top and the city list's bottom.
const NICKNAME_Y := 48
const NICKNAME_ROWS := 10
## FROM panel: the country and city lists, four rows each.
const COUNTRY_Y := 48
const CITY_Y := 192
const PLACE_ROWS := 4

# BOXER panel rows: label, then a text box or a < value > selector.
const ROW_Y := 32
const ROW_STEP := 40
const LABEL_W := 128
const PICKER_X := 152
const ARROW_W := 32
const VALUE_W := 192
const SWATCH := Vector2(96, 16)

# SKILLS panel rows.
const SKILL_ROW_Y := ROW_Y + 2 * ROW_STEP
const SKILL_STEP := ROW_STEP
const SKILL_LABEL_W := 208
const MINUS_X := 232
const SKILL_VALUE_X := 280
const SKILL_VALUE_W := 64
const PLUS_X := 352
const STEP_W := 40
const POOL_Y := ROW_Y + 16
const MIN_SKILL := 10
const MAX_SKILL := 65

const SKILLS_SHOWN := [
	["POWER", "power"], ["SPEED", "speed"], ["STAMINA", "stamina"],
	["CHIN", "chin"], ["STRENGTH", "strength"], ["INTELLIGENCE", "intelligence"],
]
const NICKNAME_CHOICES := 10
const NO_NICKNAME := "NO NICKNAME"

var _frame: Control
var _generator := BoxerGenerator.new()
var _boxer: BoxerData
var _pool := PlayerCareer.START_POOL
var _spent := {}                   ## Skill -> points spent (+) or taken off (-).
var _portrait: BoxerPortrait
var _overall: Label
var _size_label: Label
var _values := {}                  ## Picker name -> its value Label.
var _swatches := {}                ## Picker name -> its colour block.
var _skill_labels := {}            ## Skill -> value Label.
var _pool_label: Label
var _first: LineEdit
var _last: LineEdit
var _nicknames: ItemList
var _nickname_options: Array[String] = []
var _countries: ItemList
var _cities: ItemList
var _country_data: Array = []
var _start: Button


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

	_boxer = _generator.generate_player(Divisions.Id.LIGHTWEIGHT)

	_frame.add_child(UiTheme.place(UiTheme.label("NEW BOXER", UiTheme.TITLE, Palette.UI_GOLD), 24, 24, 480, UiTheme.TITLE))
	var back := _button(_frame, "BACK", 1104, 16, 160, 48, _go_back)
	_start = _button(_frame, "START CAREER", back.position.x - 16 - 288, 16, 288, 48, _start_career)

	_build_portrait()
	_build_boxer()
	_build_nickname()
	_build_skills()
	_build_from()
	_refresh()
	_first.grab_focus()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "new_boxer":
		_capture(GameState.options["capture"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ============================================================================
#  Panels
# ============================================================================

func _build_portrait() -> void:
	var panel := _panel(PORTRAIT, "")
	_portrait = BoxerPortrait.new(PICTURE_VIEW, 3, PICTURE_FIGURE, PICTURE_FEET)
	_portrait.position = Vector2((PORTRAIT.size.x - _portrait.size.x) / 2.0, 8)
	panel.add_child(_portrait)
	_overall = UiTheme.label("", UiTheme.LARGE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(UiTheme.place(_overall, 0, OVERALL_Y, PORTRAIT.size.x, UiTheme.LARGE))
	_size_label = UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(UiTheme.place(_size_label, 0, SIZE_Y, PORTRAIT.size.x, UiTheme.ROW_H))
	_side_picker(panel, SIDE_PICKERS_Y[0], "DIVISION", _cycle_division)
	_side_picker(panel, SIDE_PICKERS_Y[1], "STYLE", _cycle_style)


func _build_boxer() -> void:
	var panel := _panel(BOXER, "BOXER")
	_first = _text_row(panel, 0, "NAME", _boxer.first_name)
	_last = _text_row(panel, 1, "SURNAME", _boxer.last_name)
	_picker_row(panel, 2, "SKIN", _cycle_skin, true)
	_picker_row(panel, 3, "HAIR", _cycle_hair)
	_picker_row(panel, 4, "HAIRCUT", _cycle_haircut)
	_picker_row(panel, 5, "TRUNKS", _cycle_trunks, true)
	_picker_row(panel, 6, "GLOVES", _cycle_gloves, true)
	_picker_row(panel, 7, "BOOTS", _cycle_boots, true)


func _build_nickname() -> void:
	var panel := _panel(NICKNAME, "NICKNAME")
	_nicknames = _list(panel, NICKNAME_Y, NICKNAME.size.x, NICKNAME_ROWS)
	_nicknames.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_nicknames.item_selected.connect(func(i: int) -> void:
		_boxer.nickname = "" if i >= _nickname_options.size() else _nickname_options[i].capitalize())
	_new_nicknames()


func _build_skills() -> void:
	var panel := _panel(SKILLS, "SKILLS")
	for i in SKILLS_SHOWN.size():
		var skill: String = SKILLS_SHOWN[i][1]
		var y := SKILL_ROW_Y + i * SKILL_STEP
		panel.add_child(UiTheme.place(UiTheme.label(SKILLS_SHOWN[i][0], UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, y + 4, SKILL_LABEL_W, UiTheme.ROW_H))
		_button(panel, "-", MINUS_X, y, STEP_W, 32, _change_skill.bind(skill, -1))
		var value := UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		panel.add_child(UiTheme.place(value, SKILL_VALUE_X, y + 4, SKILL_VALUE_W, UiTheme.ROW_H))
		_skill_labels[skill] = value
		_button(panel, "+", PLUS_X, y, STEP_W, 32, _change_skill.bind(skill, 1))
	panel.add_child(UiTheme.block(Color(Palette.UI_TEXT_DIM, 0.4), PAD, SKILL_ROW_Y - 16, SKILLS.size.x - PAD * 2, 1))
	panel.add_child(UiTheme.place(UiTheme.label("POINTS AVAILABLE", UiTheme.BODY, Palette.UI_GOLD), PAD, POOL_Y + 4, SKILL_VALUE_X - PAD - 8, UiTheme.ROW_H))
	_pool_label = UiTheme.label("", UiTheme.LARGE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(UiTheme.place(_pool_label, SKILL_VALUE_X, POOL_Y, SKILL_VALUE_W, UiTheme.LARGE + 8))


func _build_from() -> void:
	# Country above city, each the panel's full width so the longest names
	# ("UNITED KINGDOM", "SANTIAGO DE CUBA") fit.
	var panel := _panel(FROM, "FROM")
	var list_w := FROM.size.x - PAD * 2
	panel.add_child(UiTheme.place(UiTheme.label("COUNTRY", UiTheme.CAPTION, Palette.UI_TEXT_DIM), PAD, 32, list_w, UiTheme.CAPTION))
	panel.add_child(UiTheme.place(UiTheme.label("CITY", UiTheme.CAPTION, Palette.UI_TEXT_DIM), PAD, CITY_Y - 16, list_w, UiTheme.CAPTION))
	_countries = _list(panel, COUNTRY_Y, FROM.size.x, PLACE_ROWS)
	_cities = _list(panel, CITY_Y, FROM.size.x, PLACE_ROWS)
	for list in [_countries, _cities]:
		list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_country_data = _generator.countries()
	var current := 0
	for i in _country_data.size():
		_countries.add_item(str(_country_data[i][1]).to_upper())
		if _country_data[i][0] == _boxer.country_code:
			current = i
	_countries.select(current)
	_countries.ensure_current_is_visible()
	_fill_cities(current, _boxer.city)
	_countries.item_selected.connect(func(i: int) -> void: _fill_cities(i, ""))
	_cities.item_selected.connect(func(i: int) -> void:
		_boxer.city = _cities.get_item_text(i).capitalize()
		_new_nicknames())


func _fill_cities(country: int, city: String) -> void:
	var c: Array = _country_data[country]
	_boxer.country_code = c[0]
	_boxer.country = c[1]
	_cities.clear()
	var pick := 0
	for i in (c[2] as Array).size():
		_cities.add_item(str(c[2][i]).to_upper())
		if c[2][i] == city:
			pick = i
	_cities.select(pick)
	_cities.ensure_current_is_visible()
	_boxer.city = c[2][pick]
	_new_nicknames()


# ============================================================================
#  Choices
# ============================================================================

func _cycle_division(dir: int) -> void:
	_boxer.division = posmod(_boxer.division + dir, Divisions.count()) as Divisions.Id
	_generator.roll_size(_boxer)
	# His division's starting skills, plus whatever he has spent.
	for skill in _skill_labels:
		_boxer.set(skill, clampi(BoxerGenerator.player_start_skill(_boxer.division, skill) + int(_spent.get(skill, 0)), MIN_SKILL, MAX_SKILL))
	_new_nicknames()
	_refresh()


func _cycle_style(dir: int) -> void:
	_boxer.style = posmod(_boxer.style + dir, BoxerData.STYLE_NAMES.size()) as BoxerData.Style
	_new_nicknames()
	_refresh()


func _cycle_skin(dir: int) -> void:
	_boxer.skin_index = posmod(_boxer.skin_index + dir, Palette.SKIN_TONES.size())
	_refresh()


func _cycle_hair(dir: int) -> void:
	_boxer.hair_index = posmod(_boxer.hair_index + dir, Palette.HAIR_TONES.size())
	_refresh()


func _cycle_haircut(dir: int) -> void:
	_boxer.hair_style = posmod(_boxer.hair_style + dir, Palette.HAIR_STYLES.size())
	_refresh()


func _cycle_trunks(dir: int) -> void:
	_boxer.trunks_index = posmod(_boxer.trunks_index + dir, Palette.TRUNKS.size())
	_refresh()


func _cycle_gloves(dir: int) -> void:
	_boxer.gloves_index = posmod(_boxer.gloves_index + dir, Palette.TRUNKS.size())
	_refresh()


func _cycle_boots(dir: int) -> void:
	_boxer.boots_index = posmod(_boxer.boots_index + dir, Palette.BOOTS.size())
	_refresh()


## + takes a point from the pool, - gives one back.
func _change_skill(skill: String, dir: int) -> void:
	var value := int(_boxer.get(skill))
	if dir > 0 and (_pool <= 0 or value >= MAX_SKILL):
		return
	if dir < 0 and value <= MIN_SKILL:
		return
	_boxer.set(skill, value + dir)
	_spent[skill] = int(_spent.get(skill, 0)) + dir
	_pool -= dir
	_refresh()


## Ten nicknames to suit his style, division and hometown, then none.
func _new_nicknames() -> void:
	if _nicknames == null:
		return
	var used: Array[String] = []
	for table in GameState.rankings:
		for b in table.boxers:
			if not b.nickname.is_empty():
				used.append(b.nickname)
	var keep := _boxer.nickname
	_nickname_options = _generator.nickname_choices(_boxer, used, NICKNAME_CHOICES)
	_nicknames.clear()
	var pick := _nickname_options.size()
	for i in _nickname_options.size():
		_nicknames.add_item("\"%s\"" % _nickname_options[i].to_upper())
		if _nickname_options[i].capitalize() == keep:
			pick = i
	_nicknames.add_item(NO_NICKNAME)
	_nicknames.select(pick)
	_nicknames.ensure_current_is_visible()
	_boxer.nickname = "" if pick >= _nickname_options.size() else _nickname_options[pick].capitalize()


func _refresh() -> void:
	_values["DIVISION"].text = _boxer.division_name().to_upper()
	_values["STYLE"].text = _boxer.style_name().to_upper()
	_values["HAIR"].text = Palette.HAIR_NAMES[_boxer.hair_index].to_upper()
	_values["HAIRCUT"].text = Palette.HAIR_STYLES[_boxer.hair_style].to_upper()
	_swatches["SKIN"].color = Palette.SKIN_TONES[_boxer.skin_index][0]
	_swatches["TRUNKS"].color = Palette.TRUNKS[_boxer.trunks_index]["tones"][0]
	_swatches["GLOVES"].color = Palette.TRUNKS[_boxer.gloves_index]["tones"][0]
	_swatches["BOOTS"].color = Palette.BOOTS[_boxer.boots_index][0]
	for skill in _skill_labels:
		_skill_labels[skill].text = str(_boxer.get(skill))
	_pool_label.text = str(_pool)
	_overall.text = "OVERALL %d" % _boxer.overall()
	_size_label.text = "%s  -  %d LB" % [_boxer.height_imperial(), _boxer.weight_lb]
	_portrait.show_boxer(_boxer)


func _start_career() -> void:
	var first := _first.text.strip_edges().capitalize()
	var last := _last.text.strip_edges().capitalize()
	if first.is_empty() or last.is_empty():
		(_first if first.is_empty() else _last).grab_focus()
		return
	_boxer.first_name = first
	_boxer.last_name = last
	_boxer.recovery = BoxerGenerator.PLAYER_START_SKILL
	GameState.start_career(_boxer)
	get_tree().change_scene_to_file("res://scenes/career_home.tscn")


# ============================================================================
#  Helpers
# ============================================================================

## A scrolling list [param rows] rows tall in its own frame, the panel's
## width less PAD each side, with its frame's top at [param y].
func _list(panel: Control, y: float, panel_w: float, rows: int) -> ItemList:
	var w := panel_w - PAD * 2
	var h := rows * LIST_ROW_H
	panel.add_child(UiTheme.panel(PAD, y, w, h + LIST_INSET * 2, Palette.UI_PANEL_DARK, Color(Palette.UI_TEXT_DIM, 0.6), 2))
	var list := ItemList.new()
	list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	list.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	list.clip_contents = true
	panel.add_child(UiTheme.place(list, PAD + LIST_INSET, y + LIST_INSET, w - LIST_INSET * 2, h))
	return list


func _panel(rect: Rect2, caption: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(holder, rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	holder.add_child(UiTheme.panel(0, 0, rect.size.x, rect.size.y))
	if not caption.is_empty():
		holder.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.CAPTION, Palette.UI_GOLD), PAD, CAPTION_Y, 240, UiTheme.CAPTION))
	return holder


func _text_row(panel: Control, row: int, label: String, value: String) -> LineEdit:
	var y := ROW_Y + row * ROW_STEP
	panel.add_child(UiTheme.place(UiTheme.label(label, UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, y + 4, LABEL_W, UiTheme.ROW_H))
	var edit := LineEdit.new()
	edit.text = value.to_upper()
	edit.max_length = 12
	edit.add_theme_font_override("font", UiTheme.FONT)
	edit.add_theme_font_size_override("font_size", UiTheme.BODY)
	panel.add_child(UiTheme.place(edit, PICKER_X, y, ARROW_W * 2 + VALUE_W + 16, 32))
	return edit


## A < value > selector; [param swatch] shows a colour block for the value.
func _picker_row(panel: Control, row: int, label: String, action: Callable, swatch: bool = false) -> void:
	var y := ROW_Y + row * ROW_STEP
	panel.add_child(UiTheme.place(UiTheme.label(label, UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, y + 4, LABEL_W, UiTheme.ROW_H))
	_button(panel, "<", PICKER_X, y, ARROW_W, 32, action.bind(-1))
	var value_x := PICKER_X + ARROW_W + 8
	if swatch:
		var block := UiTheme.block(Color.WHITE, value_x + (VALUE_W - SWATCH.x) / 2.0, y + 8, SWATCH.x, SWATCH.y)
		panel.add_child(UiTheme.panel(block.position.x - 2, block.position.y - 2, SWATCH.x + 4, SWATCH.y + 4, Palette.UI_PANEL_DARK, Palette.OUTLINE, 2))
		panel.add_child(block)
		_swatches[label] = block
	else:
		var value := UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		panel.add_child(UiTheme.place(value, value_x, y + 4, VALUE_W, UiTheme.ROW_H))
		_values[label] = value
	_button(panel, ">", value_x + VALUE_W + 8, y, ARROW_W, 32, action.bind(1))


## A < value > selector under the portrait, its [param caption] over it,
## the full width of the panel.
func _side_picker(panel: Control, y: float, caption: String, action: Callable) -> void:
	panel.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), 0, y, PORTRAIT.size.x, UiTheme.CAPTION))
	var row_y := y + SIDE_CAPTION_GAP
	_button(panel, "<", PAD, row_y, ARROW_W, 32, action.bind(-1))
	_button(panel, ">", PORTRAIT.size.x - PAD - ARROW_W, row_y, ARROW_W, 32, action.bind(1))
	var value := UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	panel.add_child(UiTheme.place(value, PAD + ARROW_W + 8, row_y + 4, PORTRAIT.size.x - (PAD + ARROW_W + 8) * 2, UiTheme.ROW_H))
	_values[caption] = value


func _button(parent: Control, text: String, x: float, y: float, w: float, h: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, y, w, h)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
