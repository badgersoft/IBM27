extends Control
## The Boxers screen: one tab per weight division. Each tab shows that
## division's boxers in a table, with all of them lined up in the ring
## underneath so you can compare their builds.
##
## Layout (1280 x 720 frame):
##   y  16  THE BOXERS                                        [ BACK ]
##   y  80  [ LIGHTWEIGHT ][ MIDDLEWEIGHT ][ HEAVYWEIGHT ]    size range
##
## Records shown include any fights played this session.
##   y 120  table panel (1248 wide), joined to the selected tab
##   y 448  line-up in the ring (848 x 256, arena at x2, cropped)
##
## Table columns are fixed widths on a 16 px grid, each at least one character
## wider than its longest value, so there is always a gap between columns.
## Numbers are right-aligned so every column of figures lines up, and the
## record is split into separate W / L / D / KO columns for the same reason.

const FRAME_SIZE := Vector2(1280, 720)
const PANEL := Rect2(16, 120, 1248, 312)
const ROW_H := 48
const FIRST_ROW_Y := 56          # Inside the panel.
const GROUP_Y := 12              # "RECORD" / "SKILLS" group captions.
const HEADER_Y := 32             # Column captions.

# --- Tabs ----------------------------------------------------------------------------
const TAB_Y := 80
const TAB_SIZE := Vector2(256, 40)
const TAB_GAP := 16

## [caption, x, width, alignment] - x and width are inside the panel.
const L := HORIZONTAL_ALIGNMENT_LEFT
const R := HORIZONTAL_ALIGNMENT_RIGHT
const COLUMNS := [
	["#",      16,  32, L],
	["NAME",   48, 304, L],
	["AGE",   352,  48, R],
	["W",     416,  48, R],
	["L",     464,  48, R],
	["D",     512,  48, R],
	["KO",    560,  48, R],
	["STYLE", 624, 128, L],
	["CM",    752,  64, R],
	["LB",    816,  64, R],
	["POW",   896,  48, R],
	["SPD",   944,  48, R],
	["STA",   992,  48, R],
	["CHN",  1040,  48, R],
	["STR",  1088,  48, R],
	["INT",  1136,  48, R],
	["OVR",  1184,  48, R],
]

# --- Line-up -----------------------------------------------------------------------
const LINEUP_SCALE := 2
const LINEUP_TOP := 34           # Arena rows hidden above the line-up crop.
const LINEUP_SIZE := Vector2i(424, 128)
const LINEUP_Y := 448
const LINEUP_X := [92.0, 152.0, 212.0, 272.0, 332.0]
const BADGE_ARENA_Y := 151       # Numbers sit in a row on the apron.

var _frame: Control
var _tabs: Array[Button] = []
var _caption: Label
var _content: Control            # Rebuilt whenever the tab changes.
var _division := Divisions.Id.MIDDLEWEIGHT


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
	_caption = UiTheme.label("", UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_frame.add_child(UiTheme.place(_caption, 832, TAB_Y + 16, PANEL.end.x - 832, UiTheme.CAPTION))

	var start := int(GameState.options.get("tab", Divisions.Id.MIDDLEWEIGHT))
	_select(clampi(start, 0, Divisions.count() - 1))
	_tabs[_division].grab_focus()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "roster":
		_capture(GameState.options["capture"])


## Shows one division's tab.
func _select(id: int) -> void:
	_division = id as Divisions.Id
	for i in _tabs.size():
		_style_tab(_tabs[i], i == id)
	var div := Divisions.get_division(id)
	var h: Array = div["height_cm"]
	var w: Array = div["weight_lb"]
	_caption.text = "%d - %d CM   %d - %d LB" % [h[0], h[1], w[0], w[1]]
	if _content != null:
		_content.queue_free()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_content, 0, 0, FRAME_SIZE.x, FRAME_SIZE.y))
	_build_table(_content)
	_build_lineup(_content)


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


# ============================================================================
#  Table
# ============================================================================

func _build_table(frame: Control) -> void:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(UiTheme.place(panel, PANEL.position.x, PANEL.position.y, PANEL.size.x, PANEL.size.y))
	panel.add_child(UiTheme.panel(0, 0, PANEL.size.x, PANEL.size.y))

	# Group captions over the record and skill columns.
	_group(panel, "RECORD", 416, 608)
	_group(panel, "SKILLS", 896, 1184)
	for col in COLUMNS:
		var h := UiTheme.label(col[0], UiTheme.CAPTION, Palette.UI_TEXT_DIM, col[3])
		panel.add_child(UiTheme.place(h, col[1], HEADER_Y, col[2], UiTheme.CAPTION))

	var roster := GameState.boxers_in(_division)
	for i in roster.size():
		var b: BoxerData = roster[i]
		var y := FIRST_ROW_Y + i * ROW_H
		if i % 2 == 0:
			panel.add_child(UiTheme.block(Color(1, 1, 1, 0.04), 8, y, PANEL.size.x - 16, ROW_H))
		var values := [
			str(i + 1), b.display_name().to_upper(), str(b.age),
			str(b.wins), str(b.losses), str(b.draws), str(b.kos),
			b.style_name().to_upper(), str(b.height_cm), str(b.weight_lb),
			str(b.power), str(b.speed), str(b.stamina), str(b.chin), str(b.strength), str(b.intelligence),
			str(b.overall()),
		]
		for c in COLUMNS.size():
			var col: Array = COLUMNS[c]
			var colour := Palette.UI_TEXT
			if c == 0:
				colour = Palette.UI_GOLD
			elif c == COLUMNS.size() - 1:
				colour = Palette.UI_GOLD
			var cell := UiTheme.label(values[c], UiTheme.BODY, colour, col[3])
			if c == 1:
				UiTheme.fit(cell, col[2])
			panel.add_child(UiTheme.place(cell, col[1], y + 4, col[2], UiTheme.ROW_H))
		# Second line under the name: nickname and hometown.
		var line := "\"%s\"  -  %s" % [b.nickname.to_upper(), b.hometown().to_upper()] if not b.nickname.is_empty() else b.hometown().to_upper()
		panel.add_child(UiTheme.place(UiTheme.label(line, UiTheme.CAPTION, Palette.UI_TEXT_DIM), 48, y + 30, 384, UiTheme.CAPTION))


func _group(panel: Control, text: String, from_x: float, to_x: float) -> void:
	panel.add_child(UiTheme.place(UiTheme.label(text, UiTheme.CAPTION, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), from_x, GROUP_Y, to_x - from_x, UiTheme.CAPTION))
	panel.add_child(UiTheme.block(Color(Palette.UI_BORDER, 0.5), from_x + 8, GROUP_Y + 12, to_x - from_x - 16, 1))


# ============================================================================
#  Line-up
# ============================================================================

## All five boxers standing in the City Gym ring (a weigh-in look), numbered to
## match the table.
func _build_lineup(frame: Control) -> void:
	var viewport := SubViewport.new()
	viewport.size = LINEUP_SIZE
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	frame.add_child(viewport)   # Freed with the tab's content.

	var arena := ArenaRenderer.new()
	arena.position.y = -LINEUP_TOP
	arena.show_apron_text = false
	viewport.add_child(arena)
	arena.setup(Venues.Id.CITY_GYM)

	var size := Vector2(LINEUP_SIZE * LINEUP_SCALE)
	var x := (FRAME_SIZE.x - size.x) / 2.0
	frame.add_child(UiTheme.panel(x - 4, LINEUP_Y - 4, size.x + 8, size.y + 8, Palette.UI_PANEL_DARK, Palette.UI_BORDER, 2))
	var view := TextureRect.new()
	view.texture = viewport.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(UiTheme.place(view, x, LINEUP_Y, size.x, size.y))

	var roster := GameState.boxers_in(_division)
	for i in mini(roster.size(), LINEUP_X.size()):
		var b: BoxerData = roster[i]
		var rig := BoxerRig.new()
		arena.fighter_layer.add_child(rig)
		rig.setup(b, i % 2)
		rig.facing = 1 if LINEUP_X[i] <= 212.0 else -1
		rig.position = Vector2(LINEUP_X[i], ArenaRenderer.FIGHT_Y)
		rig.play("relaxed")
		# Number badges in a row on the apron below the boxers, drawn crisp in
		# the UI layer, matching the # column of the table.
		var badge := UiTheme.label(str(i + 1), UiTheme.BODY, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.outline(badge, 8)
		var badge_y := LINEUP_Y + (BADGE_ARENA_Y - LINEUP_TOP) * LINEUP_SCALE - UiTheme.ROW_H / 2.0
		frame.add_child(UiTheme.place(badge, x + LINEUP_X[i] * LINEUP_SCALE - 24, badge_y, 48, UiTheme.ROW_H))


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
