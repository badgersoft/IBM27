extends Control
## The career's Schedule: arranging the boxer's next fight.
##
## The list is everyone he can fight right now (PlayerCareer.opponents): men
## who have asked to fight him first (OFFERING A FIGHT), then the men ranked
## no more than four places above him or six below in his division, all
## free. Choosing one offers him a purse: five figures, the usual purse in
## the middle with two lower and two higher either side. He needs half the
## purse in the bank to offer it (otherwise it is greyed out); a keen man
## nearly always says yes, an unsure one may need the higher figures.
##
## Once a fight is arranged the list is greyed out and CANCEL FIGHT appears:
## calling it off costs a quarter of the purse.
##
## Layout (1280 x 800 frame):
##   y  16  SCHEDULE                              MONEY $20K   [BACK]
##   y  80  +-- YOUR NEXT FIGHT (1248 x 112) ----------- [CANCEL FIGHT] --+
##   y 208  +-- OPPONENTS (1248 x 576): one row per man --------------------+

const FRAME_SIZE := Vector2(1280, 800)
const PAD := 16
const FIGHT := Rect2(16, 80, 1248, 112)
const LIST := Rect2(16, 208, 1248, 576)
const HEADER_Y := 24
const FIRST_ROW_Y := 48
const ROW_H := 52
const MAX_ROWS := 10
## Opponent columns inside the list: [caption, x, width, alignment].
## VS YOU is the head to head with him (your wins first), "-" if you have
## never met.
const COLUMNS := [
	["RANK",    24,  48, HORIZONTAL_ALIGNMENT_RIGHT],
	["NAME",    96, 256, HORIZONTAL_ALIGNMENT_LEFT],
	["",       360, 176, HORIZONTAL_ALIGNMENT_LEFT],
	["VS YOU", 544, 112, HORIZONTAL_ALIGNMENT_CENTER],
	["RECORD", 664, 168, HORIZONTAL_ALIGNMENT_CENTER],
	["OVR",    840,  80, HORIZONTAL_ALIGNMENT_CENTER],
	["STYLE",  928,  96, HORIZONTAL_ALIGNMENT_CENTER],
	["PURSE", 1040, 176, HORIZONTAL_ALIGNMENT_RIGHT],
]
## The purse offer pop-up (and the answer).
const OFFER_W := 1120
const OFFER_H := 360
const OFFER_MOOD_Y := 80
const OFFER_H2H_Y := 112
const OFFER_BUTTON := Vector2(192, 56)
const OFFER_BUTTON_Y := 152
const OFFER_NAME_Y := 216
const OFFER_RULE_Y := 256
const OFFER_OK_Y := 296
const OFFER_NAMES: Array[String] = ["LOW", "LOWER", "USUAL", "HIGHER", "HIGH"]

var _frame: Control
var _content: Control
var _popup: Control
var _money: Label
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

	_frame.add_child(UiTheme.place(UiTheme.label("SCHEDULE", UiTheme.TITLE, Palette.UI_GOLD), 24, 24, 480, UiTheme.TITLE))
	var back := Button.new()
	back.text = "BACK"
	UiTheme.place(back, FRAME_SIZE.x - 16 - 192, 16, 192, 48)
	back.pressed.connect(_go_back)
	_frame.add_child(back)
	_money = UiTheme.label("", UiTheme.LARGE, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_frame.add_child(UiTheme.place(_money, 512, 28, back.position.x - 32 - 512, UiTheme.LARGE))
	_refresh()
	back.grab_focus()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "schedule":
		var list := _career.opponents(_season)
		if GameState.options.has("offer") and not list.is_empty():
			_offer(list[0])
		_capture(GameState.options["capture"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _popup != null:
			_close_popup()
		else:
			_go_back()
		get_viewport().set_input_as_handled()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/career_home.tscn")


func _refresh() -> void:
	_money.text = "MONEY %s" % Purse.money_text(_career.money)
	if _content != null:
		_content.queue_free()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_content, 0, 0, FRAME_SIZE.x, FRAME_SIZE.y))
	_build_fight()
	_build_list()


# ============================================================================
#  Panels
# ============================================================================

func _build_fight() -> void:
	var panel := _panel(FIGHT, "YOUR NEXT FIGHT")
	var f := _season.booking(_career.boxer)
	var keen := _career.live_requests(_season).size()
	var main := "NONE ARRANGED"
	var sub := "PICK AN OPPONENT BELOW"
	if keen > 0:
		sub += "  -  %d OFFERING A FIGHT" % keen
	if f != null:
		var other := f.opponent_of(_career.boxer)
		main = "V %s  -  END OF %s" % [other.display_name().to_upper(), Season.date_text(f.month)]
		sub = "%d ROUNDS  -  PURSE %s%s" % [f.rounds, Purse.money_text(f.purse), "  -  IBC TITLE" if f.title else ""]
		var cancel := Button.new()
		cancel.text = "CANCEL FIGHT"
		UiTheme.place(cancel, FIGHT.size.x - PAD - 288, 32, 288, 48)
		cancel.pressed.connect(_cancel)
		panel.add_child(cancel)
		panel.add_child(UiTheme.place(UiTheme.label("FORFEIT %s" % Purse.money_text(_career.forfeit(_season)), UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), FIGHT.size.x - PAD - 288, 88, 288, UiTheme.CAPTION))
	elif not _career.can_arrange(_season):
		main = "RECOVERING FROM YOUR LAST FIGHT"
		sub = "YOU CAN ARRANGE A NEW FIGHT FROM %s" % Season.date_text(_career.free_from(_season))
	var main_label := UiTheme.label(main, UiTheme.LARGE, Palette.UI_GOLD if f != null else Palette.UI_TEXT)
	UiTheme.fit(main_label, FIGHT.size.x - PAD * 2 - (304 if f != null else 0))
	panel.add_child(UiTheme.place(main_label, PAD, 36, FIGHT.size.x - PAD * 2 - 304, UiTheme.LARGE))
	panel.add_child(UiTheme.place(UiTheme.label(sub, UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, 72, FIGHT.size.x - PAD * 2 - 304, UiTheme.ROW_H))


func _build_list() -> void:
	var panel := _panel(LIST, "OPPONENTS")
	for col in COLUMNS:
		panel.add_child(UiTheme.place(UiTheme.label(col[0], UiTheme.CAPTION, Palette.UI_TEXT_DIM, col[3]), col[1], HEADER_Y, col[2], UiTheme.CAPTION))
	var open := _career.can_arrange(_season)
	var list := _career.opponents(_season)
	if list.is_empty():
		panel.add_child(UiTheme.place(UiTheme.label("NOBODY IS FREE TO FIGHT YOU THIS MONTH", UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), 0, FIRST_ROW_Y + ROW_H, LIST.size.x, UiTheme.ROW_H))
		return
	var table := _season.rankings_of(_career.boxer)
	for i in mini(list.size(), MAX_ROWS):
		var b := list[i]
		var y := FIRST_ROW_Y + i * ROW_H
		if i % 2 == 0:
			panel.add_child(UiTheme.block(Color(1, 1, 1, 0.04), 8, y, LIST.size.x - 16, ROW_H))
		var keen := _career.requests.has(b.id)
		var turned_down := _career.declined.has(b.id)
		var usable := open and not turned_down
		var row := Button.new()
		row.focus_mode = Control.FOCUS_ALL
		row.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		row.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		var lit := UiTheme.box(Color(1, 1, 1, 0.07), Palette.UI_BORDER, 2)
		for state in ["hover", "focus", "pressed"]:
			row.add_theme_stylebox_override(state, lit)
		row.disabled = not usable
		UiTheme.place(row, 8, y, LIST.size.x - 16, ROW_H)
		row.pressed.connect(_offer.bind(b))
		panel.add_child(row)
		var note := "OFFERING A FIGHT" if keen else ""
		if turned_down:
			note = "TURNED YOU DOWN"
		var dim := not usable
		var h := _season.head_to_head(_career.boxer, b)
		var met := h[0] + h[1] + h[2] > 0
		var values := [
			table.rank_label(b), _short(b), note, Season.series_score(h) if met else "-", b.record(),
			str(b.overall()), b.style_short(), Purse.money_text(_career.usual_purse(_season, b)),
		]
		for c in COLUMNS.size():
			var col: Array = COLUMNS[c]
			var colour := Palette.UI_TEXT_DIM if dim else Palette.UI_TEXT
			if c == 0 and not dim:
				colour = Palette.UI_GOLD
			if c == 2:
				colour = Palette.UI_GOLD if keen and not dim else Palette.UI_TEXT_DIM
			if c == 3 and not dim:
				# Gold if you lead him, dim if you have never met.
				colour = Palette.UI_GOLD if h[0] > h[1] else (Palette.UI_TEXT if met else Palette.UI_TEXT_DIM)
			var size := UiTheme.CAPTION if c == 2 else UiTheme.BODY
			var cell := UiTheme.label(values[c], size, colour, col[3])
			panel.add_child(UiTheme.place(cell, col[1], y + (ROW_H - UiTheme.ROW_H) / 2.0, col[2], UiTheme.ROW_H))


# ============================================================================
#  The purse offer
# ============================================================================

func _offer(b: BoxerData) -> void:
	_close_popup()
	var box := _make_popup("OFFER %s A PURSE" % _short(b))
	var offers := _career.purse_offers(_season, b)
	var keen := _career.requests.has(b.id)
	var mood := "HE WANTS THIS FIGHT - ANY FAIR OFFER SHOULD DO." if keen else "HE IS UNSURE - A BIGGER PURSE MAY TEMPT HIM."
	box.add_child(UiTheme.place(UiTheme.label(mood, UiTheme.BODY, Palette.UI_GOLD if keen else Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER), 0, OFFER_MOOD_Y, OFFER_W, UiTheme.ROW_H))
	var h := _season.head_to_head(_career.boxer, b)
	var h2h := "HEAD TO HEAD: " + _series_for_you(h)
	var h2h_colour := Palette.UI_TEXT if h[0] + h[1] + h[2] > 0 else Palette.UI_TEXT_DIM
	box.add_child(UiTheme.place(UiTheme.label(h2h, UiTheme.BODY, h2h_colour, HORIZONTAL_ALIGNMENT_CENTER), 0, OFFER_H2H_Y, OFFER_W, UiTheme.ROW_H))
	var row_w := OFFER_BUTTON.x * 5 + PAD * 4
	var x0 := (OFFER_W - row_w) / 2.0
	var first: Button = null
	for i in offers.size():
		var button := Button.new()
		button.text = Purse.money_text(offers[i])
		button.focus_mode = Control.FOCUS_ALL
		var x := x0 + i * (OFFER_BUTTON.x + PAD)
		UiTheme.place(button, x, OFFER_BUTTON_Y, OFFER_BUTTON.x, OFFER_BUTTON.y)
		button.disabled = not _career.can_offer(offers[i])
		button.pressed.connect(_make_offer.bind(b, i))
		box.add_child(button)
		var name_colour := Palette.UI_GOLD if i == 2 else Palette.UI_TEXT_DIM
		box.add_child(UiTheme.place(UiTheme.label(OFFER_NAMES[i], UiTheme.BODY, name_colour, HORIZONTAL_ALIGNMENT_CENTER), x, OFFER_NAME_Y, OFFER_BUTTON.x, UiTheme.ROW_H))
		if i == 2 and not button.disabled:
			first = button
	var rule := "YOU NEED HALF THE PURSE IN THE BANK TO MAKE AN OFFER."
	box.add_child(UiTheme.place(UiTheme.label(rule, UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), 0, OFFER_RULE_Y, OFFER_W, UiTheme.ROW_H))
	var cancel := _popup_button("CANCEL", (OFFER_W - 256) / 2.0, OFFER_OK_Y, _close_popup)
	(first if first != null else cancel).grab_focus()


## "FIRST MEETING", "YOU LEAD 2-1", "HE LEADS 1-0" or "ALL SQUARE AT 1-1".
static func _series_for_you(h: Array[int]) -> String:
	if h[0] + h[1] + h[2] == 0:
		return "FIRST MEETING"
	if h[0] == h[1]:
		return "ALL SQUARE AT %s" % Season.series_score(h)
	if h[0] > h[1]:
		return "YOU LEAD %s" % Season.series_score(h)
	return "HE LEADS %s" % Season.series_score(h, false)


func _make_offer(b: BoxerData, offer: int) -> void:
	var f := _career.challenge(_season, b, offer)
	_close_popup()
	var box := _make_popup("HE SAYS YES!" if f != null else "HE SAYS NO")
	var text := _career.news[0] if not _career.news.is_empty() else ""
	var line := UiTheme.label(text, UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.fit(line, OFFER_W - PAD * 2)
	box.add_child(UiTheme.place(line, PAD, 128, OFFER_W - PAD * 2, UiTheme.ROW_H))
	_popup_button("OK", (OFFER_W - 256) / 2.0, OFFER_OK_Y, func() -> void:
		_close_popup()
		_refresh()).grab_focus()


func _cancel() -> void:
	_career.cancel_fight(_season)
	_refresh()


func _make_popup(caption: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(holder)
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := UiTheme.block(Color(0, 0, 0, 0.6), 0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	holder.add_child(dim)
	# The box sits in the middle of the frame, which is centred on screen.
	var box := Control.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -OFFER_W / 2.0
	box.offset_right = OFFER_W / 2.0
	box.offset_top = -OFFER_H / 2.0
	box.offset_bottom = OFFER_H / 2.0
	holder.add_child(box)
	holder.size = size
	box.add_child(UiTheme.panel(0, 0, OFFER_W, OFFER_H, Palette.UI_PANEL, Palette.UI_BORDER, 4))
	box.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.TITLE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), 0, 32, OFFER_W, UiTheme.TITLE))
	_popup = holder
	return box


func _popup_button(text: String, x: float, y: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, y, 256, 48)
	b.pressed.connect(action)
	_popup.get_child(-1).add_child(b)   # The box.
	return b


func _close_popup() -> void:
	if _popup != null:
		_popup.queue_free()
		_popup = null


# ============================================================================
#  Helpers
# ============================================================================

func _panel(rect: Rect2, caption: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(UiTheme.place(holder, rect.position.x, rect.position.y, rect.size.x, rect.size.y))
	holder.add_child(UiTheme.panel(0, 0, rect.size.x, rect.size.y))
	holder.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.CAPTION, Palette.UI_GOLD), PAD, 10, 320, UiTheme.CAPTION))
	return holder


static func _short(b: BoxerData) -> String:
	return "%s. %s" % [b.first_name.substr(0, 1).to_upper(), b.last_name.to_upper()]


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
