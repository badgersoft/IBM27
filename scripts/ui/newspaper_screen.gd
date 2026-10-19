extends Control
## The monthly newspaper, THE RINGSIDE GAZETTE (written by Newspaper).
##
##   FRONT PAGE  the headline and its story, then the other stories (more
##               title fights, and features on the great fights) down the
##               left; IN BRIEF down the right: rankings climbers in the
##               player's division, retirements and new faces.
##   RESULTS     every fight of the month, with its excitement rating.
##
## Layout (1280 x 800 frame):
##   y   8  THE RINGSIDE GAZETTE (48 px, centred)
##   y  64  dateline
##   y  80  [FRONT PAGE][RESULTS]   [<] 1 - 10 OF 14 [>]       [CONTINUE]
##   y 120  page panel (1248 x 664)
##
## CONTINUE goes back to the Fixtures screen.

const FRAME_SIZE := Vector2(1280, 800)
const PAGE := Rect2(16, 120, 1248, 664)
const TAB_Y := 80
const TAB_SIZE := Vector2(256, 40)
const TAB_GAP := 16
const PAD := 16
## Front page columns, inside the page panel.
const MAIN_W := 792
const BRIEF_X := 840
const BRIEF_W := 392
const STORY_GAP := 24
## Extra space between wrapped lines, so a paragraph doesn't read as a block.
const LINE_SPACING := 8
## The results pager (shown on the RESULTS page only), after the tabs.
const PAGER_X := 560
const PAGER_BUTTON_W := 96
const PAGER_LABEL_W := 208

var _frame: Control
var _page: Control
var _tabs: Array[Button] = []
var _paper: Dictionary = {}
var _results: Array[Fixture] = []
var _results_page := 0
var _pager: Control
var _page_label: Label
var _pager_buttons: Array[Button] = []


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

	var papers := GameState.season.papers
	if not papers.is_empty():
		_paper = papers[clampi(GameState.paper_index, 0, papers.size() - 1)]
	_results.assign(_paper.get("results", []))

	var masthead := UiTheme.label(Newspaper.NAME, UiTheme.HUGE, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_frame.add_child(UiTheme.place(masthead, 0, 8, FRAME_SIZE.x, UiTheme.HUGE))
	var dateline := "%s  -  MONTHLY EDITION  -  ALL THE IBC RESULTS INSIDE" % _paper.get("date", "")
	_frame.add_child(UiTheme.place(UiTheme.label(dateline, UiTheme.CAPTION, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), 0, 64, FRAME_SIZE.x, UiTheme.CAPTION))

	for i in 2:
		var tab := Button.new()
		tab.text = ["FRONT PAGE", "RESULTS"][i]
		tab.focus_mode = Control.FOCUS_ALL
		UiTheme.place(tab, PAGE.position.x + i * (TAB_SIZE.x + TAB_GAP), TAB_Y, TAB_SIZE.x, TAB_SIZE.y)
		tab.pressed.connect(_show.bind(i))
		_frame.add_child(tab)
		_tabs.append(tab)
	var go_on := Button.new()
	go_on.text = "CONTINUE"
	go_on.focus_mode = Control.FOCUS_ALL
	UiTheme.place(go_on, PAGE.end.x - 256, TAB_Y, 256, TAB_SIZE.y)
	go_on.pressed.connect(_continue)
	_frame.add_child(go_on)

	_pager = Control.new()
	_pager.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_pager, 0, 0, FRAME_SIZE.x, FRAME_SIZE.y))
	_pager_button("<", PAGER_X, -1)
	_page_label = UiTheme.label("", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var label_x := PAGER_X + PAGER_BUTTON_W + 16
	_pager.add_child(UiTheme.place(_page_label, label_x, TAB_Y + (TAB_SIZE.y - UiTheme.ROW_H) / 2.0, PAGER_LABEL_W, UiTheme.ROW_H))
	_pager_button(">", label_x + PAGER_LABEL_W + 16, 1)

	_show(int(GameState.options.get("tab", 0)))
	go_on.grab_focus()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "paper":
		_capture(GameState.options["capture"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_continue()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_continue()


## Back to the fixtures, or in a career to the boxer's home page once the
## month's paper is read.
func _continue() -> void:
	if GameState.career != null:
		get_tree().change_scene_to_file("res://scenes/career_home.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/fixtures.tscn")


func _pager_button(text: String, x: float, dir: int) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, TAB_Y, PAGER_BUTTON_W, TAB_SIZE.y)
	b.pressed.connect(_turn.bind(dir))
	_pager.add_child(b)
	_pager_buttons.append(b)


func _turn(dir: int) -> void:
	var page := clampi(_results_page + dir, 0, FixtureTable.page_count(_results.size()) - 1)
	if page != _results_page:
		_results_page = page
		_show(1)


func _show(which: int) -> void:
	for i in _tabs.size():
		_style_tab(_tabs[i], i == which)
	if _page != null:
		_page.queue_free()
	_pager.visible = which == 1
	if which == 1:
		var table := FixtureTable.new()
		table.position = PAGE.position
		table.show_page(_results, _results_page, GameState.rankings, false, false, "NO FIGHTS THIS MONTH")
		var first := _results_page * FixtureTable.PAGE_SIZE
		_page_label.text = "%d - %d OF %d" % [mini(first + 1, _results.size()), mini(first + FixtureTable.PAGE_SIZE, _results.size()), _results.size()]
		_pager_buttons[0].disabled = _results_page == 0
		_pager_buttons[1].disabled = _results_page >= FixtureTable.page_count(_results.size()) - 1
		_page = table
		_frame.add_child(table)
		return
	_page = Control.new()
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_page, PAGE.position.x, PAGE.position.y, PAGE.size.x, PAGE.size.y))
	_page.add_child(UiTheme.panel(0, 0, PAGE.size.x, PAGE.size.y))
	_build_front_page()


func _build_front_page() -> void:
	var main := _column(PAD, PAD, MAIN_W, PAGE.size.y - PAD * 2)
	main.add_child(_text(_paper.get("headline", ""), UiTheme.TITLE, Palette.UI_GOLD, MAIN_W))
	main.add_child(_text(_paper.get("standfirst", ""), UiTheme.BODY, Palette.UI_TEXT, MAIN_W))
	for story in _paper.get("stories", []):
		main.add_child(_gap(STORY_GAP))
		main.add_child(_rule(MAIN_W))
		main.add_child(_gap(STORY_GAP - 8))
		main.add_child(_text(story["title"], UiTheme.LARGE, Palette.UI_GOLD, MAIN_W))
		main.add_child(_text(story["text"], UiTheme.BODY, Palette.UI_TEXT, MAIN_W))
	var roundup: Array = _paper.get("roundup", [])
	if not roundup.is_empty():
		main.add_child(_gap(STORY_GAP))
		main.add_child(_rule(MAIN_W))
		main.add_child(_gap(STORY_GAP - 8))
		main.add_child(_text("ROUND-UP", UiTheme.LARGE, Palette.UI_GOLD, MAIN_W))
		for line in roundup:
			main.add_child(_text(line, UiTheme.BODY, Palette.UI_TEXT, MAIN_W))

	# A rule between the columns, then IN BRIEF.
	_page.add_child(UiTheme.block(Color(Palette.UI_TEXT_DIM, 0.4), BRIEF_X - PAD - 1, PAD, 1, PAGE.size.y - PAD * 2))
	_page.add_child(UiTheme.place(UiTheme.label("IN BRIEF", UiTheme.CAPTION, Palette.UI_GOLD), BRIEF_X, 10, 240, UiTheme.CAPTION))
	var brief := _column(BRIEF_X, 32, BRIEF_W, PAGE.size.y - 32 - PAD)
	var notes: Array = _paper.get("notes", [])
	if notes.is_empty():
		notes = ["NOTHING ELSE TO REPORT THIS MONTH."]
	for i in notes.size():
		if i > 0:
			brief.add_child(_gap(PAD))
		brief.add_child(_text(notes[i], UiTheme.BODY, Palette.UI_TEXT, BRIEF_W))


## A scrolling column of text blocks inside the page.
func _column(x: float, y: float, w: float, h: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page.add_child(UiTheme.place(scroll, x, y, w, h))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size.x = w
	scroll.add_child(column)
	return column


## A wrapping block of text [param width] wide.
static func _text(text: String, size: int, colour: Color, width: float) -> Label:
	var l := UiTheme.label(text, size, colour)
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.add_theme_constant_override("line_spacing", LINE_SPACING)
	return l


## A thin dividing line in a column.
static func _rule(width: float) -> ColorRect:
	var line := UiTheme.block(Color(Palette.UI_TEXT_DIM, 0.4), 0, 0, width, 1)
	line.custom_minimum_size = Vector2(width, 1)
	return line


static func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _style_tab(tab: Button, selected: bool) -> void:
	var bg := Palette.UI_PANEL if selected else Palette.UI_PANEL_DARK
	var border := Palette.UI_BORDER if selected else Color(Palette.UI_TEXT_DIM, 0.5)
	var text := Palette.UI_GOLD if selected else Palette.UI_TEXT_DIM
	for state in ["normal", "hover", "pressed"]:
		tab.add_theme_stylebox_override(state, UiTheme.box(bg if state != "hover" else bg.lightened(0.08), border, 2))
	tab.add_theme_color_override("font_color", text)
	tab.add_theme_color_override("font_hover_color", Palette.UI_GOLD)
	tab.add_theme_color_override("font_focus_color", text)


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
