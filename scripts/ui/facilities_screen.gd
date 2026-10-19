extends Control
## The career's Facilities: where the boxer trains, where he recovers, and
## his sponsors.
##
##   TRAINING   the gyms, the Local Gym free and the rest rented by the
##              week; a better gym makes every training session count for
##              more (BOOST).
##   RECOVERY   the same for getting over fights: a better one gets his
##              health back faster.
##   SPONSORS   his sponsor if he has one, otherwise this month's offers:
##              a one-off payment for 3, 6 or 12 months. One at a time.
##
## A facility can only be chosen if he can pay its first week; the rent is
## paid at the end of each week (PlayerCareer).
##
## Layout (1280 x 800 frame):
##   y  16  FACILITIES                           MONEY $20K   [BACK]
##   y  80  [TRAINING][RECOVERY][SPONSORS]
##   y 120  panel (1248 x 664): one row per facility or offer

enum Tab { TRAINING, RECOVERY, SPONSORS }

const FRAME_SIZE := Vector2(1280, 800)
const PANEL := Rect2(16, 120, 1248, 664)
const PAD := 16
const TAB_Y := 80
const TAB_SIZE := Vector2(256, 40)
const TAB_GAP := 16
const TAB_NAMES: Array[String] = ["TRAINING", "RECOVERY", "SPONSORS"]
const HEADER_Y := 24
const FIRST_ROW_Y := 48
const ROW_H := 120
const NAME_Y := 24
const BLURB_Y := 64
## Columns inside the panel: [caption, x, width].
const COST_COL := ["COST", 624, 208]
const BOOST_COL := ["BOOST", 848, 160]
const ACTION_X := 1040
const ACTION_SIZE := Vector2(192, 48)

var _frame: Control
var _content: Control
var _tabs: Array[Button] = []
var _tab: Tab = Tab.TRAINING
var _money: Label
var _career: PlayerCareer


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

	_frame.add_child(UiTheme.place(UiTheme.label("FACILITIES", UiTheme.TITLE, Palette.UI_GOLD), 24, 24, 480, UiTheme.TITLE))
	var back := Button.new()
	back.text = "BACK"
	UiTheme.place(back, FRAME_SIZE.x - 16 - 192, 16, 192, 48)
	back.pressed.connect(_go_back)
	_frame.add_child(back)
	_money = UiTheme.label("", UiTheme.LARGE, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_frame.add_child(UiTheme.place(_money, 512, 28, back.position.x - 32 - 512, UiTheme.LARGE))
	for i in TAB_NAMES.size():
		var tab := Button.new()
		tab.text = TAB_NAMES[i]
		tab.focus_mode = Control.FOCUS_ALL
		UiTheme.place(tab, PANEL.position.x + i * (TAB_SIZE.x + TAB_GAP), TAB_Y, TAB_SIZE.x, TAB_SIZE.y)
		tab.pressed.connect(_select.bind(i))
		_frame.add_child(tab)
		_tabs.append(tab)
	_select(int(GameState.options.get("tab", Tab.TRAINING)))
	_tabs[_tab].grab_focus()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "facilities":
		_capture(GameState.options["capture"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/career_home.tscn")


func _select(tab: int) -> void:
	_tab = clampi(tab, 0, TAB_NAMES.size() - 1) as Tab
	for i in _tabs.size():
		_style_tab(_tabs[i], i == _tab)
	_refresh()


func _refresh() -> void:
	_money.text = "MONEY %s" % Purse.money_text(_career.money)
	if _content != null:
		_content.queue_free()
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_content, PANEL.position.x, PANEL.position.y, PANEL.size.x, PANEL.size.y))
	_content.add_child(UiTheme.panel(0, 0, PANEL.size.x, PANEL.size.y))
	if _tab == Tab.SPONSORS:
		_build_sponsors()
	else:
		_build_facilities(Facilities.Kind.TRAINING if _tab == Tab.TRAINING else Facilities.Kind.RECOVERY)


# ============================================================================
#  Training and recovery
# ============================================================================

func _build_facilities(kind: Facilities.Kind) -> void:
	var list := Facilities.list(kind)
	var in_use := _career.training_facility if kind == Facilities.Kind.TRAINING else _career.recovery_facility
	_header([["", PAD, 320], COST_COL, BOOST_COL])
	for i in list.size():
		var item: Dictionary = list[i]
		var y := FIRST_ROW_Y + i * ROW_H
		if i % 2 == 0:
			_content.add_child(UiTheme.block(Color(1, 1, 1, 0.04), 8, y, PANEL.size.x - 16, ROW_H))
		var current := i == in_use
		_content.add_child(UiTheme.place(UiTheme.label(str(item["name"]).to_upper(), UiTheme.LARGE, Palette.UI_GOLD if current else Palette.UI_TEXT), PAD, y + NAME_Y, 592, UiTheme.LARGE))
		_content.add_child(UiTheme.place(UiTheme.label(str(item["blurb"]).to_upper(), UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, y + BLURB_Y, 592, UiTheme.ROW_H))
		var cost: int = item["cost"]
		var cost_text := "FREE" if cost == 0 else "%s/WEEK" % Purse.money_text(cost)
		_cell(COST_COL, y, cost_text)
		_cell(BOOST_COL, y, "X%.1f" % float(item["boost"]))
		var action := Button.new()
		action.focus_mode = Control.FOCUS_ALL
		UiTheme.place(action, ACTION_X, y + (ROW_H - ACTION_SIZE.y) / 2.0, ACTION_SIZE.x, ACTION_SIZE.y)
		if current:
			action.text = "IN USE"
			action.disabled = true
		else:
			action.text = "USE"
			action.disabled = cost > _career.money
			action.pressed.connect(func() -> void:
				_career.set_facility(kind, i)
				_refresh())
		_content.add_child(action)


# ============================================================================
#  Sponsors
# ============================================================================

func _build_sponsors() -> void:
	if not _career.sponsor.is_empty():
		var s := _career.sponsor
		_content.add_child(UiTheme.place(UiTheme.label("YOUR SPONSOR", UiTheme.CAPTION, Palette.UI_GOLD), PAD, 10, 320, UiTheme.CAPTION))
		_content.add_child(UiTheme.place(UiTheme.label(str(s["name"]).to_upper(), UiTheme.TITLE, Palette.UI_GOLD), PAD, 48, PANEL.size.x - PAD * 2, UiTheme.TITLE))
		var line := "PAID %s  -  %d MONTH%s LEFT" % [Purse.money_text(s["pay"]), s["months_left"], "S" if int(s["months_left"]) != 1 else ""]
		_content.add_child(UiTheme.place(UiTheme.label(line, UiTheme.BODY, Palette.UI_TEXT), PAD, 104, PANEL.size.x - PAD * 2, UiTheme.ROW_H))
		_content.add_child(UiTheme.place(UiTheme.label("ONE SPONSOR AT A TIME: NEW OFFERS COME WHEN THIS DEAL ENDS.", UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, 152, PANEL.size.x - PAD * 2, UiTheme.ROW_H))
		return
	if _career.sponsor_offers.is_empty():
		_content.add_child(UiTheme.place(UiTheme.label("NO OFFERS THIS MONTH", UiTheme.LARGE, Palette.UI_TEXT), PAD, 48, PANEL.size.x - PAD * 2, UiTheme.LARGE))
		_content.add_child(UiTheme.place(UiTheme.label("WIN FIGHTS AND CLIMB THE RANKINGS TO CATCH THEIR EYE.", UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, 96, PANEL.size.x - PAD * 2, UiTheme.ROW_H))
		return
	_header([["OFFERS THIS MONTH", PAD, 320], ["PAYMENT", COST_COL[1], COST_COL[2]], ["LENGTH", BOOST_COL[1], BOOST_COL[2]]])
	var tiers := ["LOCAL", "REGIONAL", "NATIONAL", "GLOBAL"]
	for i in _career.sponsor_offers.size():
		var offer: Dictionary = _career.sponsor_offers[i]
		var y := FIRST_ROW_Y + i * ROW_H
		if i % 2 == 0:
			_content.add_child(UiTheme.block(Color(1, 1, 1, 0.04), 8, y, PANEL.size.x - 16, ROW_H))
		_content.add_child(UiTheme.place(UiTheme.label(str(offer["name"]).to_upper(), UiTheme.LARGE, Palette.UI_TEXT), PAD, y + NAME_Y, 592, UiTheme.LARGE))
		_content.add_child(UiTheme.place(UiTheme.label("%s SPONSOR" % tiers[int(offer["tier"])], UiTheme.BODY, Palette.UI_TEXT_DIM), PAD, y + BLURB_Y, 592, UiTheme.ROW_H))
		_cell(COST_COL, y, Purse.money_text(offer["pay"]))
		_cell(BOOST_COL, y, "%d MONTHS" % offer["months"])
		var accept := Button.new()
		accept.text = "ACCEPT"
		accept.focus_mode = Control.FOCUS_ALL
		UiTheme.place(accept, ACTION_X, y + (ROW_H - ACTION_SIZE.y) / 2.0, ACTION_SIZE.x, ACTION_SIZE.y)
		accept.pressed.connect(func() -> void:
			_career.accept_sponsor(i)
			_refresh())
		_content.add_child(accept)


# ============================================================================
#  Helpers
# ============================================================================

## Column captions: [caption, x, width] each (the first left-aligned).
func _header(columns: Array) -> void:
	for i in columns.size():
		var col: Array = columns[i]
		var align := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_content.add_child(UiTheme.place(UiTheme.label(col[0], UiTheme.CAPTION, Palette.UI_TEXT_DIM, align), col[1], HEADER_Y, col[2], UiTheme.CAPTION))


## A right-aligned value in column [param col] of the row at [param y].
func _cell(col: Array, y: float, text: String) -> void:
	_content.add_child(UiTheme.place(UiTheme.label(text, UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT), col[1], y + (ROW_H - UiTheme.ROW_H) / 2.0, col[2], UiTheme.ROW_H))


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
