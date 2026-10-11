extends Control
## The Boxers screen: one tab per weight division. Each tab shows that
## division's ten boxers in a table, with all of them lined up face-on in the
## ring underneath (a weigh-in line-up) so you can compare their builds.
## Records shown include any fights played this session.
##
## Layout (1280 x 720 frame):
##   y  16  THE BOXERS                                        [ BACK ]
##   y  80  [ LIGHTWEIGHT ][ MIDDLEWEIGHT ][ HEAVYWEIGHT ]    size range
##   y 120  table panel (1248 x 364), joined to the selected tab
##   y 492  line-up in the ring (848 x 220, arena at x2, cropped)
##
## Table columns are fixed widths on a 16 px grid with at least 16 px between
## the widest values of neighbouring columns, so there is always a clear gap
## (32 px either side of STYLE, which separates the record from the body and
## skills).
## Numbers are right-aligned so every column of figures lines up, and the
## record is split into separate W / L / D / KO columns for the same reason.
## Each row has the name on its first line and any nickname under it.

const FRAME_SIZE := Vector2(1280, 720)
const PANEL := Rect2(16, 120, 1248, 364)
const ROW_H := 30
const FIRST_ROW_Y := 56          # Inside the panel.
const GROUP_Y := 12              # "RECORD" / "SKILLS" group captions.
const HEADER_Y := 32             # Column captions.
## Inside a row: the main line (a 24 px label, so the 16 px capitals sit on
## rows 4 - 17) and the nickname under it (capitals on rows 21 - 27). That
## leaves 3 px between a name and its nickname and 6 px before the next row,
## so a nickname clearly belongs to the name above it.
const VALUE_Y := 0
const NICK_Y := 14

# --- Tabs ----------------------------------------------------------------------------
const TAB_Y := 80
const TAB_SIZE := Vector2(256, 40)
const TAB_GAP := 16

## [caption, x, width, alignment] - x and width are inside the panel.
const L := HORIZONTAL_ALIGNMENT_LEFT
const C := HORIZONTAL_ALIGNMENT_CENTER
const R := HORIZONTAL_ALIGNMENT_RIGHT
const COLUMNS := [
	["#",       16,  32, R],
	["NAME",    64, 256, L],
	["FROM",   336,  48, C],
	["AGE",    400,  32, R],
	["W",      448,  32, R],
	["L",      496,  32, R],
	["D",      544,  32, R],
	["KO",     592,  32, R],
	["STYLE",  656, 112, L],
	["CM",     784,  48, R],
	["LB",     848,  48, R],
	["POW",    912,  32, R],
	["SPD",    960,  32, R],
	["STA",   1008,  32, R],
	["CHN",   1056,  32, R],
	["STR",   1104,  32, R],
	["INT",   1152,  32, R],
	["OVR",   1200,  32, R],
]
## Longest name shown in full (16 characters fill the NAME column); longer
## names are shortened to an initial and surname.
const NAME_CHARS := 16

# --- Line-up -----------------------------------------------------------------------
const LINEUP_SCALE := 2
const LINEUP_Y := 492
const LINEUP_SIZE := Vector2i(424, 110)
const LINEUP_TOP := 42           # Arena rows hidden above the line-up crop.
const LINEUP_FEET_Y := 138.0     # Near the front of the canvas.
const LINEUP_SPAN := Vector2(36.0, 388.0)   # Arena x the line-up fills.
const BADGE_ARENA_Y := 147       # Numbers sit in a row on the apron.

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
	_group(panel, "RECORD", 448, 624)
	_group(panel, "SKILLS", 912, 1184)
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
			str(i + 1), _short_name(b), b.country_code, str(b.age),
			str(b.wins), str(b.losses), str(b.draws), str(b.kos),
			b.style_name().to_upper(), str(b.height_cm), str(b.weight_lb),
			str(b.power), str(b.speed), str(b.stamina), str(b.chin), str(b.strength), str(b.intelligence),
			str(b.overall()),
		]
		for c in COLUMNS.size():
			var col: Array = COLUMNS[c]
			var colour := Palette.UI_TEXT
			if c == 0 or c == COLUMNS.size() - 1:
				colour = Palette.UI_GOLD
			elif c == 2:
				colour = Palette.UI_TEXT_DIM
			var cell := UiTheme.label(values[c], UiTheme.BODY, colour, col[3])
			if c == 1:
				UiTheme.fit(cell, col[2])
			panel.add_child(UiTheme.place(cell, col[1], y + VALUE_Y, col[2], UiTheme.ROW_H))
		if not b.nickname.is_empty():
			var nick := UiTheme.label("\"%s\"" % b.nickname.to_upper(), UiTheme.CAPTION, Palette.UI_GOLD)
			panel.add_child(UiTheme.place(nick, COLUMNS[1][1], y + NICK_Y, COLUMNS[1][2], UiTheme.CAPTION))


## "DANIYAR TULEGENOV" (17) -> "D. TULEGENOV" so every name fits at full size.
func _short_name(b: BoxerData) -> String:
	var full := b.display_name().to_upper()
	if full.length() <= NAME_CHARS:
		return full
	return "%s. %s" % [b.first_name.substr(0, 1).to_upper(), b.last_name.to_upper()]


func _group(panel: Control, text: String, from_x: float, to_x: float) -> void:
	panel.add_child(UiTheme.place(UiTheme.label(text, UiTheme.CAPTION, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), from_x, GROUP_Y, to_x - from_x, UiTheme.CAPTION))
	panel.add_child(UiTheme.block(Color(Palette.UI_BORDER, 0.5), from_x + 8, GROUP_Y + 12, to_x - from_x - 16, 1))


# ============================================================================
#  Line-up
# ============================================================================

## The whole division standing face-on in the City Gym ring, as at a
## weigh-in (hands taped, no gloves), numbered to match the table. They are
## spread so the gaps between neighbours are all the same.
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
	var rigs: Array[FrontRig] = []
	var total_w := 0.0
	for i in roster.size():
		var rig := FrontRig.new()
		rig.setup_boxer(roster[i], i % 2, false)
		arena.fighter_layer.add_child(rig)
		rigs.append(rig)
		total_w += rig.half_width() * 2.0
	var gap := (LINEUP_SPAN.y - LINEUP_SPAN.x - total_w) / maxf(rigs.size() - 1, 1)
	var left := LINEUP_SPAN.x
	for i in rigs.size():
		var rig := rigs[i]
		rig.position = Vector2(roundf(left + rig.half_width()), LINEUP_FEET_Y)
		left += rig.half_width() * 2.0 + gap
		# Number badges in a row on the apron below the boxers, drawn crisp in
		# the UI layer, matching the # column of the table.
		var badge := UiTheme.label(str(i + 1), UiTheme.BODY, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.outline(badge, 8)
		var badge_y := LINEUP_Y + (BADGE_ARENA_Y - LINEUP_TOP) * LINEUP_SCALE - UiTheme.ROW_H / 2.0
		frame.add_child(UiTheme.place(badge, x + rig.position.x * LINEUP_SCALE - 24, badge_y, 48, UiTheme.ROW_H))


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
