extends Control
## The Fixtures screen: the season's calendar.
##
##   THIS MONTH   the fights at the end of this month. Choose one to watch it
##                in the ring; PLAY MONTH has the rest fought (simulated by
##                the same fight engine, on a worker thread so the screen
##                keeps moving) and fills in each result as it comes in. The
##                moment the last one is done the month ends (everyone trains,
##                the paper is written, the career moves on to next month)
##                and READ THE PAPER opens the newspaper.
##
## In a career the fights happen on fight night, the last week of the month
## (PlayerCareer.fight_week): before that they can only be looked at. If the
## player's boxer is on the card his fight comes first and is always fought
## in the ring: the button reads YOUR FIGHT, and PLAY MONTH (which never
## simulates his fight) only appears once it is over.
##   BOOKED       fights arranged for the months after, with their month.
##   LAST MONTH   last month's results.
##
## Layout (1280 x 800 frame): the fight-night board, a column of FightCards
## for each division (its fights, the player's first; scrolls if there are
## more than fit, as on BOOKED).
##   y  16  FIXTURES - JAN 2027            [PAPER] [PLAY MONTH] [BACK]
##   y  80  [THIS MONTH][BOOKED][LAST MONTH]                  hint
##   y 136  LIGHTWEIGHT        MIDDLEWEIGHT        HEAVYWEIGHT
##   y 176  [card]             [card]              [card]
##          [card]             [card]              [card]  ...

enum Tab { THIS_MONTH, BOOKED, LAST_MONTH }

const FRAME_SIZE := Vector2(1280, 800)
const TAB_Y := 80
const TAB_X := 16
const TAB_SIZE := Vector2(256, 40)
const TAB_GAP := 16
const TAB_NAMES: Array[String] = ["THIS MONTH", "BOOKED", "LAST MONTH"]
const HINT_X := 832
const BUTTON_H := 48
## The board: a column per division, lightest first.
const COLUMN_X: Array[int] = [16, 440, 864]
const COLUMN_HEAD_Y := 136
const CARDS_Y := 176
const CARDS_H := 608
const CARD_GAP := 16
const HINT := "CHOOSE A FIGHT TO WATCH IT, OR PLAY MONTH TO HAVE THEM ALL FOUGHT"
const HINT_YOUR_FIGHT := "YOUR FIGHT IS ON THE CARD - FIGHT IT FIRST, THEN PLAY MONTH FOR THE REST"
const HINT_NOT_YET := "THE FIGHTS ARE ON FIGHT NIGHT, THE LAST WEEK OF THE MONTH"
const HINT_DONE := "THE MONTH IS OVER - READ ALL ABOUT IT IN THE PAPER"

var _frame: Control
var _title: Label
var _board: Control
var _tabs: Array[Button] = []
var _tab: Tab = Tab.THIS_MONTH
var _play: Button
var _paper: Button
var _back: Button
var _hint: Label
var _month_over := false             ## The month ended on this visit.

# Playing the month on a worker thread.
var _thread: Thread
var _mutex := Mutex.new()
var _fought: Array[Fixture] = []     ## Finished on the thread, not yet recorded.
var _playing := false


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

	_title = UiTheme.label("", UiTheme.TITLE, Palette.UI_GOLD)
	_frame.add_child(UiTheme.place(_title, 24, 24, 640, UiTheme.TITLE))
	_back = _button("BACK", 1104, 16, 160, BUTTON_H, _go_back)
	_play = _button("PLAY MONTH", 864, 16, 224, BUTTON_H, _on_play)
	_paper = _button("PAPER", 688, 16, 160, BUTTON_H, _open_paper)

	for i in TAB_NAMES.size():
		var tab := _button(TAB_NAMES[i], TAB_X + i * (TAB_SIZE.x + TAB_GAP), TAB_Y, TAB_SIZE.x, TAB_SIZE.y, _select.bind(i))
		_tabs.append(tab)
	# The hint, two lines on the right of the tabs.
	_hint = UiTheme.label(HINT, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.clip_text = false
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.add_theme_constant_override("line_spacing", 6)
	_frame.add_child(UiTheme.place(_hint, HINT_X, TAB_Y, FRAME_SIZE.x - 16 - HINT_X, TAB_SIZE.y))

	_board = Control.new()
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_board, 0, 0, FRAME_SIZE.x, FRAME_SIZE.y))

	_select(int(GameState.options.get("tab", Tab.THIS_MONTH)))
	# Back from the ring with the last fight of the night done.
	_end_month_if_done()
	_tabs[_tab].grab_focus()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "fixtures":
		_capture(GameState.options["capture"])


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()


func _button(text: String, x: float, y: float, w: float, h: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, y, w, h)
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
	if _playing:
		return
	get_tree().change_scene_to_file(GameState.back_scene)


# ============================================================================
#  The table
# ============================================================================

func _list() -> Array[Fixture]:
	var season := GameState.season
	match _tab:
		Tab.BOOKED:
			return season.upcoming()
		Tab.LAST_MONTH:
			return season.fixtures_in(season.month - 1)
	return season.fixtures_in(season.month)


func _select(tab: int) -> void:
	_tab = clampi(tab, 0, TAB_NAMES.size() - 1) as Tab
	for i in _tabs.size():
		_style_tab(_tabs[i], i == _tab)
	_refresh()


## The board: for each division its name and number of fights, then its
## fights as cards (the player's first), scrolling if they don't all fit.
func _build_board(list: Array[Fixture], empty: String) -> void:
	for child in _board.get_children():
		child.queue_free()
	var season := GameState.season
	var clickable := _tab == Tab.THIS_MONTH and not _playing and _fight_night()
	var me := season.player
	for d in Divisions.count():
		var x: float = COLUMN_X[d]
		var mine: Array[Fixture] = []
		for f in list:
			if f.division == d:
				mine.append(f)
		mine.sort_custom(func(a: Fixture, b: Fixture) -> bool:
			var am := me != null and a.involves(me)
			var bm := me != null and b.involves(me)
			if am != bm:
				return am
			if a.month != b.month:
				return a.month < b.month
			if a.title != b.title:
				return a.title
			return _best_place(a) < _best_place(b))
		var head := UiTheme.label(Divisions.division_name(d).to_upper(), UiTheme.LARGE, Palette.UI_GOLD)
		_board.add_child(UiTheme.place(head, x, COLUMN_HEAD_Y, FightCard.W, UiTheme.LARGE))
		var count := "%d FIGHT%s" % [mine.size(), "" if mine.size() == 1 else "S"]
		_board.add_child(UiTheme.place(UiTheme.label(count, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT),
				x, COLUMN_HEAD_Y + 10, FightCard.W, UiTheme.CAPTION))
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		_board.add_child(UiTheme.place(scroll, x, CARDS_Y, FightCard.W + 8, CARDS_H))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", CARD_GAP)
		scroll.add_child(column)
		if mine.is_empty():
			var none := UiTheme.label(empty, UiTheme.BODY, Palette.UI_TEXT_DIM)
			none.custom_minimum_size = Vector2(FightCard.W, UiTheme.ROW_H)
			column.add_child(none)
		for f in mine:
			var card := FightCard.new(f, GameState.rankings, clickable, _tab == Tab.BOOKED, me != null and f.involves(me))
			card.pressed.connect(_watch)
			column.add_child(card)


## The better-ranked man's place (for the order of a division's fights).
static func _best_place(f: Fixture) -> int:
	var a := GameState.rankings[f.red.division].index_of(f.red)
	var b := GameState.rankings[f.blue.division].index_of(f.blue)
	return mini(a if a >= 0 else 99, b if b >= 0 else 99)


func _refresh() -> void:
	var season := GameState.season
	_title.text = "FIXTURES - %s %d" % [Season.short_month(season.month), Season.START_YEAR + floori(season.month / 12.0)]
	var list := _list()
	var empty := "NO FIGHTS ARRANGED"
	if _tab == Tab.LAST_MONTH:
		empty = "NO FIGHTS LAST MONTH"
	_build_board(list, empty)
	_paper.disabled = season.papers.is_empty() or _playing
	_play.remove_theme_color_override("font_color")
	_play.disabled = false
	_hint.text = HINT
	if _playing:
		var done := 0
		for f in season.fixtures_in(season.month):
			done += 1 if f.is_done() else 0
		_play.text = "%d / %d" % [done, season.fixtures_in(season.month).size()]
		_play.disabled = true
	elif _month_over:
		_play.text = "READ THE PAPER"
		_hint.text = HINT_DONE
	elif not _fight_night():
		_play.text = "PLAY MONTH"
		_play.disabled = true
		_hint.text = HINT_NOT_YET
	elif _players_fight() != null:
		_play.text = "YOUR FIGHT"
		_play.add_theme_color_override("font_color", Palette.UI_GOLD)
		_hint.text = HINT_YOUR_FIGHT
	else:
		_play.text = "PLAY MONTH"
	_back.disabled = _playing


## The selected tab looks joined to the table; the others are dim.
func _style_tab(tab: Button, selected: bool) -> void:
	var bg := Palette.UI_PANEL if selected else Palette.UI_PANEL_DARK
	var border := Palette.UI_BORDER if selected else Color(Palette.UI_TEXT_DIM, 0.5)
	var text := Palette.UI_GOLD if selected else Palette.UI_TEXT_DIM
	for state in ["normal", "hover", "pressed"]:
		tab.add_theme_stylebox_override(state, UiTheme.box(bg if state != "hover" else bg.lightened(0.08), border, 2))
	tab.add_theme_color_override("font_color", text)
	tab.add_theme_color_override("font_hover_color", Palette.UI_GOLD)
	tab.add_theme_color_override("font_focus_color", text)


# ============================================================================
#  Watching and playing
# ============================================================================

## Fights can be fought now: always outside a career, on fight night in one.
func _fight_night() -> bool:
	return GameState.career == null or GameState.career.fight_week()


## The player's fight this month, if it hasn't been fought yet.
func _players_fight() -> Fixture:
	var me := GameState.season.player
	if me == null:
		return null
	for f in GameState.season.fixtures_in(GameState.season.month):
		if f.involves(me) and not f.is_done():
			return f
	return null


## Once the last fight of fight night is done the month ends at once: the
## season moves on (training, the paper) and so does the career. The results
## stay on screen under LAST MONTH.
func _end_month_if_done() -> void:
	var season := GameState.season
	if _month_over or not _fight_night() or not season.month_finished():
		return
	GameState.paper_index = season.papers.size()
	season.finish_month()
	if GameState.career != null:
		GameState.career.end_month(season)
		GameState.save_career()
	_month_over = true
	_select(Tab.LAST_MONTH)
	_play.grab_focus()


func _watch(f: Fixture) -> void:
	if _playing or f.is_done() or not _fight_night():
		return
	GameState.watch_fixture(f)
	get_tree().change_scene_to_file("res://scenes/fight.tscn")


func _on_play() -> void:
	var season := GameState.season
	if _month_over:
		_open_paper()
		return
	if not _fight_night():
		return
	var mine := _players_fight()
	if mine != null:
		_watch(mine)   # His fight is fought in the ring, never simulated.
		return
	var todo: Array[Fixture] = []
	var seeds: Array[int] = []
	for f in season.fixtures_in(season.month):
		if not f.is_done() and not (season.player != null and f.involves(season.player)):
			todo.append(f)
			seeds.append(season.fight_seed(f))
	_playing = true
	_select(Tab.THIS_MONTH)
	_thread = Thread.new()
	_thread.start(_fight_all.bind(todo, seeds))


## Worker thread: fights each fixture in turn and hands it back.
func _fight_all(todo: Array[Fixture], seeds: Array[int]) -> void:
	for i in todo.size():
		Season.run_fight(todo[i], seeds[i])
		_mutex.lock()
		_fought.append(todo[i])
		_mutex.unlock()


func _process(_delta: float) -> void:
	if not _playing:
		return
	_mutex.lock()
	var ready := _fought.duplicate()
	_fought.clear()
	_mutex.unlock()
	if ready.is_empty():
		return
	for f in ready:
		GameState.season.complete(f, f.sim)
	if GameState.season.month_finished():
		_thread.wait_to_finish()
		_thread = null
		_playing = false
		_play.grab_focus()
		_end_month_if_done()
	_refresh()


func _open_paper() -> void:
	GameState.paper_index = GameState.season.papers.size() - 1
	get_tree().change_scene_to_file("res://scenes/newspaper.tscn")


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
