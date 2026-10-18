class_name RosterScreen
extends Control
## The Boxers screen: one tab per weight division, each listing that
## division's thirty boxers ten to a page, best first by overall rating or
## (ORDER button) in ranking order. Each row shows the boxer's ranking (C for
## the champion, who also has the IBC belt beside his name) and level.
## Choosing a boxer opens his profile (all his skills and a portrait).
## Records shown include any fights played this session.
##
## Layout (1280 x 800 frame):
##   y  16  THE BOXERS               size range  [ ORDER: OVR ]  [ BACK ]
##   y  80  [ LIGHTWEIGHT ][ MIDDLEWEIGHT ][ HEAVYWEIGHT ]  [<] 1-10 OF 30 [>]
##   y 120  table panel (1248 x 664), joined to the selected tab
##
## After the name and belt, the columns are 80 px cells on an even rhythm.
## Every value is centred under its heading, so W, L, D and KO each sit
## squarely beneath their letter. Each row has the name on its first line and
## any nickname under it, with plenty of room either side.

const FRAME_SIZE := Vector2(1280, 800)
const PANEL := Rect2(16, 120, 1248, 664)
const ROW_H := 60
const FIRST_ROW_Y := 56          # Inside the panel.
## Group caption ("RECORD") and its rule. An 8 px caption label draws its
## capitals 7 px below its top, so the rule sits 3 px under the letters.
const GROUP_Y := 10
const GROUP_RULE_Y := 27
const HEADER_Y := 32             # Column captions.
## Inside a row: the main line (a 24 px label, so the 16 px capitals sit on
## rows 16 - 29) and the nickname under it (capitals on rows 37 - 43), which
## leaves 16 px above the name and below the nickname.
const VALUE_Y := 12
const NICK_Y := 30

# --- Tabs ----------------------------------------------------------------------------
const TAB_Y := 80
const TAB_SIZE := Vector2(256, 40)
const TAB_GAP := 16

# --- Pages: [< PREV] 11 - 20 OF 30 [NEXT >] to the right of the tabs ----------------
const PAGE_SIZE := 10
const PAGER_X := 832
const PAGER_BUTTON_W := 96
const PAGER_LABEL_W := 208      ## Between the buttons, 16 px either side.

## [caption, x, width] - x and width are inside the panel. Everything after
## the name is centred in its cell.
const CELL := 80
const COLUMNS := [
	["RANK",    24,  32],
	["NAME",    72, 360],
	["FROM",   440, CELL],
	["AGE",    520, CELL],
	["W",      600, CELL],
	["L",      680, CELL],
	["D",      760, CELL],
	["KO",     840, CELL],
	["STYLE",  920, CELL],
	["LB",    1000, CELL],
	["LEVEL", 1080, CELL],
	["OVR",   1160, CELL],
]
const COL_RANK := 0
const COL_NAME := 1
const COL_FROM := 2
const COL_LEVEL := 10
const COL_OVERALL := 11
## The champion's belt follows his name (BeltIcon at x3: 96 x 36), so his
## name is kept to CHAMPION_NAME_CHARS to leave room for it.
const BELT_PIXEL := 3
const BELT_GAP := 16
## Each level's colour in the LEVEL column: Amateur, Semi-Pro, Professional.
const LEVEL_COLOURS: Array[Color] = [Palette.UI_TEXT_DIM, Palette.UI_TEXT, Palette.UI_GOLD]
## The ORDER button, between the captions and BACK.
const ORDER_W := 224
## Longest name shown in full; longer names are shortened to an initial and
## surname so every name is the same size and clear of the FROM column.
const NAME_CHARS := 18
const CHAMPION_NAME_CHARS := 15

var _frame: Control
var _tabs: Array[Button] = []
var _caption: Label
var _content: Control            # Rebuilt whenever the tab changes.
var _rows: Array[Button] = []
var _division := Divisions.Id.MIDDLEWEIGHT
var _page := 0
var _page_label: Label
var _prev: Button
var _next: Button
var _order: Button


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

	_frame.add_child(UiTheme.place(UiTheme.label("THE BOXERS", UiTheme.TITLE, Palette.UI_GOLD), 24, 24, 640, UiTheme.TITLE))
	var back := Button.new()
	back.text = "BACK"
	UiTheme.place(back, FRAME_SIZE.x - 16 - 192, 16, 192, 48)
	back.pressed.connect(_go_back)
	_frame.add_child(back)

	for id in Divisions.count():
		var tab := Button.new()
		tab.text = Divisions.division_name(id).to_upper()
		tab.focus_mode = Control.FOCUS_ALL
		UiTheme.place(tab, PANEL.position.x + id * (TAB_SIZE.x + TAB_GAP), TAB_Y, TAB_SIZE.x, TAB_SIZE.y)
		tab.pressed.connect(_select.bind(id))
		_frame.add_child(tab)
		_tabs.append(tab)
	_order = Button.new()
	_order.focus_mode = Control.FOCUS_ALL
	UiTheme.place(_order, back.position.x - 16 - ORDER_W, 16, ORDER_W, 48)
	_order.pressed.connect(_toggle_order)
	_frame.add_child(_order)
	# Size range and a hint, right-aligned against the ORDER button, level
	# with the title.
	var caption_x := 384.0
	var caption_w := _order.position.x - 16 - caption_x
	_caption = UiTheme.label("", UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_frame.add_child(UiTheme.place(_caption, caption_x, 24, caption_w, UiTheme.CAPTION))
	var hint := UiTheme.label("CHOOSE A BOXER FOR HIS PROFILE", UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_frame.add_child(UiTheme.place(hint, caption_x, 40, caption_w, UiTheme.CAPTION))

	_prev = _pager_button("<", PAGER_X, _turn.bind(-1))
	_page_label = UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var label_x := PAGER_X + PAGER_BUTTON_W + 16
	_frame.add_child(UiTheme.place(_page_label, label_x, TAB_Y + (TAB_SIZE.y - UiTheme.ROW_H) / 2.0, PAGER_LABEL_W, UiTheme.ROW_H))
	_next = _pager_button(">", label_x + PAGER_LABEL_W + 16, _turn.bind(1))

	var start := int(GameState.options.get("tab", GameState.roster_tab))
	_page = int(GameState.options.get("page", GameState.roster_page + 1)) - 1
	_select(clampi(start, 0, Divisions.count() - 1), true)
	_tabs[_division].grab_focus()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "roster":
		_capture(GameState.options["capture"])


func _pager_button(text: String, x: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, TAB_Y, PAGER_BUTTON_W, TAB_SIZE.y)
	b.pressed.connect(action)
	_frame.add_child(b)
	return b


func _page_count() -> int:
	return ceili(GameState.boxers_in(_division).size() / float(PAGE_SIZE))


## Switches between best-first by overall rating and ranking order.
func _toggle_order() -> void:
	if GameState.roster_order == GameState.ListOrder.OVERALL:
		GameState.roster_order = GameState.ListOrder.RANKING
	else:
		GameState.roster_order = GameState.ListOrder.OVERALL
	_page = 0
	_build_page()


## Shows the previous (-1) or next (+1) page of the division.
func _turn(dir: int) -> void:
	var page := clampi(_page + dir, 0, _page_count() - 1)
	if page == _page:
		return
	_page = page
	_build_page()


## Shows one division's tab, from its first page unless [param keep_page].
func _select(id: int, keep_page: bool = false) -> void:
	if not keep_page:
		_page = 0
	_division = id as Divisions.Id
	GameState.roster_tab = id
	for i in _tabs.size():
		_style_tab(_tabs[i], i == id)
	var div := Divisions.get_division(id)
	var h: Array = div["height_cm"]
	var w: Array = div["weight_lb"]
	_caption.text = "%d - %d CM   %d - %d LB" % [h[0], h[1], w[0], w[1]]
	_build_page()


## Rebuilds the table for the current division and page.
func _build_page() -> void:
	_page = clampi(_page, 0, _page_count() - 1)
	GameState.roster_page = _page
	var total := GameState.boxers_in(_division).size()
	var first := _page * PAGE_SIZE
	_page_label.text = "%d - %d OF %d" % [first + 1, mini(first + PAGE_SIZE, total), total]
	_order.text = "ORDER: RANK" if GameState.roster_order == GameState.ListOrder.RANKING else "ORDER: OVR"
	_prev.disabled = _page == 0
	_next.disabled = _page >= _page_count() - 1
	if _content != null:
		_content.queue_free()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_content, 0, 0, FRAME_SIZE.x, FRAME_SIZE.y))
	_build_table(_content)


## The selected tab looks like part of the panel below it; the others are dim.
func _style_tab(tab: Button, selected: bool) -> void:
	var bg := Palette.UI_PANEL if selected else Palette.UI_PANEL_DARK
	var border := Palette.UI_BORDER if selected else Color(Palette.UI_TEXT_DIM, 0.5)
	var text := Palette.UI_GOLD if selected else Palette.UI_TEXT_DIM
	for state in ["normal", "hover", "pressed"]:
		var box := UiTheme.box(bg if state != "hover" else bg.lightened(0.08), border, 2)
		tab.add_theme_stylebox_override(state, box)
	tab.add_theme_color_override("font_color", text)
	tab.add_theme_color_override("font_hover_color", Palette.UI_GOLD)
	tab.add_theme_color_override("font_focus_color", text)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
	elif event is InputEventKey and event.pressed and not event.echo:
		# Page Up / Page Down turn the pages from anywhere on the screen.
		match (event as InputEventKey).keycode:
			KEY_PAGEUP:
				_turn(-1)
			KEY_PAGEDOWN:
				_turn(1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


## Opens boxer [param index]'s profile (his place in the whole division).
func _open_profile(index: int) -> void:
	GameState.profile_division = _division
	GameState.profile_index = index
	get_tree().change_scene_to_file("res://scenes/profile.tscn")


# ============================================================================
#  Table
# ============================================================================

func _build_table(frame: Control) -> void:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(UiTheme.place(panel, PANEL.position.x, PANEL.position.y, PANEL.size.x, PANEL.size.y))
	panel.add_child(UiTheme.panel(0, 0, PANEL.size.x, PANEL.size.y))

	_group(panel, "RECORD", COLUMNS[4][1], COLUMNS[7][1] + CELL)
	for c in COLUMNS.size():
		var col: Array = COLUMNS[c]
		var h := UiTheme.label(col[0], UiTheme.CAPTION, Palette.UI_TEXT_DIM, _align(c))
		panel.add_child(UiTheme.place(h, col[1], HEADER_Y, col[2], UiTheme.CAPTION))

	_rows.clear()
	var roster := GameState.listed_boxers(_division)
	var table := GameState.rankings[_division]
	var first := _page * PAGE_SIZE
	for i in range(first, mini(first + PAGE_SIZE, roster.size())):
		var b: BoxerData = roster[i]
		var y := FIRST_ROW_Y + (i - first) * ROW_H
		if i % 2 == 0:
			panel.add_child(UiTheme.block(Color(1, 1, 1, 0.04), 8, y, PANEL.size.x - 16, ROW_H))
		_rows.append(_row_button(panel, i, y))
		var level := table.tier_of(b)
		var champion := table.is_champion(b)
		var name_text := _short_name(b, CHAMPION_NAME_CHARS if champion else NAME_CHARS)
		var values := [
			table.rank_label(b), name_text, b.country_code, str(b.age),
			str(b.wins), str(b.losses), str(b.draws), str(b.kos),
			b.style_short(), str(b.weight_lb), Rankings.TIER_SHORT[level], str(b.overall()),
		]
		if champion:
			# Centred on the name's capitals (rows 16 - 29 of the row).
			var belt := BeltIcon.new(BELT_PIXEL)
			belt.position = Vector2(COLUMNS[COL_NAME][1] + name_text.length() * UiTheme.CHAR_W + BELT_GAP, y + VALUE_Y + 4 + 8 - belt.size.y / 2.0)
			panel.add_child(belt)
		for c in COLUMNS.size():
			var col: Array = COLUMNS[c]
			var colour := Palette.UI_TEXT
			if c == COL_RANK or c == COL_OVERALL:
				colour = Palette.UI_GOLD
			elif c == COL_FROM:
				colour = Palette.UI_TEXT_DIM
			elif c == COL_LEVEL:
				colour = LEVEL_COLOURS[level]
			var cell := UiTheme.label(values[c], UiTheme.BODY, colour, _align(c))
			if c == COL_NAME:
				UiTheme.fit(cell, col[2])
			panel.add_child(UiTheme.place(cell, col[1], y + VALUE_Y, col[2], UiTheme.ROW_H))
		if not b.nickname.is_empty():
			var nick := UiTheme.label("\"%s\"" % b.nickname.to_upper(), UiTheme.CAPTION, Palette.UI_GOLD)
			panel.add_child(UiTheme.place(nick, COLUMNS[COL_NAME][1], y + NICK_Y, COLUMNS[COL_NAME][2], UiTheme.CAPTION))


## A see-through button over a whole row: it highlights on hover or focus and
## opens the boxer's profile when pressed.
func _row_button(panel: Control, index: int, y: float) -> Button:
	var row := Button.new()
	row.focus_mode = Control.FOCUS_ALL
	row.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var lit := UiTheme.box(Color(1, 1, 1, 0.07), Palette.UI_BORDER, 2)
	for state in ["hover", "focus", "pressed"]:
		row.add_theme_stylebox_override(state, lit)
	UiTheme.place(row, 8, y, PANEL.size.x - 16, ROW_H)
	row.pressed.connect(_open_profile.bind(index))
	panel.add_child(row)
	return row


func _align(column: int) -> HorizontalAlignment:
	match column:
		COL_RANK:
			return HORIZONTAL_ALIGNMENT_RIGHT
		COL_NAME:
			return HORIZONTAL_ALIGNMENT_LEFT
		_:
			return HORIZONTAL_ALIGNMENT_CENTER


## "DANIYAR TULEGENOV" (17) -> "D. TULEGENOV" so every name fits at full
## size in [param chars] characters.
func _short_name(b: BoxerData, chars: int) -> String:
	var full := b.display_name().to_upper()
	if full.length() <= chars:
		return full
	return "%s. %s" % [b.first_name.substr(0, 1).to_upper(), b.last_name.to_upper()]


func _group(panel: Control, text: String, from_x: float, to_x: float) -> void:
	panel.add_child(UiTheme.place(UiTheme.label(text, UiTheme.CAPTION, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), from_x, GROUP_Y, to_x - from_x, UiTheme.CAPTION))
	panel.add_child(UiTheme.block(Color(Palette.UI_BORDER, 0.5), from_x + 8, GROUP_RULE_Y, to_x - from_x - 16, 1))


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
