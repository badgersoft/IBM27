class_name CareerMenu
extends Control
## The CAREER pop-up on the main menu, over a dimmed screen:
##
##   START NEW CAREER        -> the new boxer screen
##   CONTINUE SAVED CAREER   -> (only when there are saves) a list of them
##   CANCEL
##
## Choosing a save and LOAD opens that career's home page. RENAME gives the
## save a name of the player's choosing (kept by later saves of it) and
## DELETE removes it for good, after asking.

signal closed

const W := 640
const SAVES_W := 896             ## The saved careers panels are wider.
const BUTTON_W := 512
const BUTTON_H := 56
const GAP := 16
const PAD := 32
const NAME_LENGTH := 32
## The list of saves: a frame LIST_INSET bigger all round than LIST_ROWS
## rows of LIST_ROW_H (more scroll); each row has the name on the left and
## the date right-aligned in DATE_W.
const LIST_ROWS := 7
const LIST_ROW_H := 32
const LIST_INSET := 8
const LIST_H := LIST_ROWS * LIST_ROW_H + LIST_INSET * 2
const DATE_W := 224
## The rename and delete panels.
const ASK_H := 264
const ASK_TEXT_Y := 96
const ASK_BUTTONS_Y := 176

var _panel: Control
## What Esc does on the panel showing: back a step, or close the menu.
var _back := Callable()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := UiTheme.block(Color(0, 0, 0, 0.6), 0, 0, 0, 0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)


func _ready() -> void:
	_show_choices()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _back.is_valid():
			_back.call()
		else:
			_close()
		get_viewport().set_input_as_handled()


func _show_choices() -> void:
	var saves := GameState.list_saves()
	var buttons := [["START NEW CAREER", _new_career], ["CANCEL", _close]]
	if not saves.is_empty():
		buttons.insert(1, ["CONTINUE SAVED CAREER", _show_saves])
	var h := 96 + buttons.size() * (BUTTON_H + GAP) + GAP
	_make_panel("CAREER", h)
	_back = Callable()
	for i in buttons.size():
		var b := _button(buttons[i][0], (W - BUTTON_W) / 2.0, 96 + i * (BUTTON_H + GAP), buttons[i][1])
		if i == 0:
			b.grab_focus()


## The list of saves, [LOAD] [RENAME] / [DELETE] [BACK] under it, with
## save [param selected] chosen.
func _show_saves(selected: int = 0) -> void:
	var saves := GameState.list_saves()
	if saves.is_empty():
		_show_choices()
		return
	selected = clampi(selected, 0, saves.size() - 1)
	var y := 88 + LIST_H + GAP * 2
	var w := SAVES_W
	_make_panel("SAVED CAREERS", y + BUTTON_H * 2 + GAP * 2, w)
	var rows := _save_rows(saves, w - PAD * 2)
	var group: ButtonGroup = rows[0].button_group
	rows[selected].button_pressed = true
	var picked := func() -> int:
		var row := group.get_pressed_button()
		return rows.find(row) if row != null else -1
	var load_selected := func() -> void:
		var i: int = picked.call()
		if i >= 0 and GameState.load_career(saves[i]["path"]):
			get_tree().change_scene_to_file("res://scenes/career_home.tscn")
	for row in rows:
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.double_click:
				load_selected.call())
	var half := (w - PAD * 2 - GAP) / 2.0
	_button("LOAD", PAD, y, load_selected, half).grab_focus()
	rows[selected].grab_focus.call_deferred()
	var rename := func() -> void:
		var i: int = picked.call()
		if i >= 0:
			_ask_rename(saves[i], i)
	var delete := func() -> void:
		var i: int = picked.call()
		if i >= 0:
			_ask_delete(saves[i], i)
	_button("RENAME", PAD + half + GAP, y, rename, half)
	_button("DELETE", PAD, y + BUTTON_H + GAP, delete, half)
	_button("BACK", PAD + half + GAP, y + BUTTON_H + GAP, _show_choices, half)
	_back = _show_choices


## The saves as rows in a framed, scrolling list [param w] wide: one
## button each (one chosen at a time), the name on the left and the date
## right-aligned. Returns the rows.
func _save_rows(saves: Array[Dictionary], w: float) -> Array[Button]:
	_panel.add_child(UiTheme.panel(PAD, 88, w, LIST_H, Palette.UI_PANEL_DARK, Color(Palette.UI_TEXT_DIM, 0.6), 2))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_panel.add_child(UiTheme.place(scroll, PAD + LIST_INSET, 88 + LIST_INSET, w - LIST_INSET * 2, LIST_ROWS * LIST_ROW_H))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var group := ButtonGroup.new()
	var row_w := w - LIST_INSET * 2
	var rows: Array[Button] = []
	for save in saves:
		var row := Button.new()
		row.toggle_mode = true
		row.button_group = group
		row.focus_mode = Control.FOCUS_ALL
		row.custom_minimum_size = Vector2(row_w, LIST_ROW_H)
		row.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		row.add_theme_stylebox_override("hover", UiTheme.box(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 0))
		var lit := UiTheme.box(Color(1, 1, 1, 0.1), Palette.UI_BORDER, 2)
		for state in ["pressed", "hover_pressed"]:
			row.add_theme_stylebox_override(state, lit)
		row.add_theme_stylebox_override("focus", UiTheme.box(Color(0, 0, 0, 0), Color(Palette.UI_TEXT_DIM, 0.8), 2))
		var name_label := UiTheme.label(save["name"], UiTheme.BODY, Palette.UI_TEXT)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(UiTheme.place(name_label, 8, 4, row_w - DATE_W - 24, UiTheme.ROW_H))
		var date_label := UiTheme.label(save["date"], UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(UiTheme.place(date_label, row_w - DATE_W - 8, 4, DATE_W, UiTheme.ROW_H))
		row.toggled.connect(func(on: bool) -> void:
			name_label.add_theme_color_override("font_color", Palette.UI_GOLD if on else Palette.UI_TEXT))
		column.add_child(row)
		rows.append(row)
	return rows


## RENAME: type a new name (empty puts back the boxer's name).
func _ask_rename(save: Dictionary, index: int) -> void:
	var w := SAVES_W
	_make_panel("RENAME CAREER", ASK_H, w)
	var caption := UiTheme.label("NEW NAME - LEAVE IT EMPTY FOR THE BOXER'S NAME", UiTheme.CAPTION, Palette.UI_TEXT_DIM)
	_panel.add_child(UiTheme.place(caption, PAD, ASK_TEXT_Y - 16, w - PAD * 2, UiTheme.CAPTION))
	var field := LineEdit.new()
	field.text = save["name"]
	field.max_length = NAME_LENGTH
	field.select_all_on_focus = true
	field.add_theme_font_override("font", UiTheme.FONT)
	field.add_theme_font_size_override("font_size", UiTheme.BODY)
	_panel.add_child(UiTheme.place(field, PAD, ASK_TEXT_Y, w - PAD * 2, 48))
	var done := func() -> void:
		var typed := field.text.strip_edges()
		GameState.rename_save(save["path"], "" if typed.to_upper() == save["title"] else typed)
		_show_saves(index)
	field.text_submitted.connect(func(_t: String) -> void: done.call())
	var half := (w - PAD * 2 - GAP) / 2.0
	_button("OK", PAD, ASK_BUTTONS_Y, done, half)
	_button("CANCEL", PAD + half + GAP, ASK_BUTTONS_Y, _show_saves.bind(index), half)
	field.grab_focus()
	_back = _show_saves.bind(index)


## DELETE: are you sure?
func _ask_delete(save: Dictionary, index: int) -> void:
	var w := SAVES_W
	_make_panel("DELETE CAREER?", ASK_H, w)
	var name_label := UiTheme.label(save["name"], UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_panel.add_child(UiTheme.place(name_label, PAD, ASK_TEXT_Y, w - PAD * 2, UiTheme.ROW_H))
	var warn := UiTheme.label("%s  -  THIS CANNOT BE UNDONE" % save["date"], UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_panel.add_child(UiTheme.place(warn, PAD, ASK_TEXT_Y + 32, w - PAD * 2, UiTheme.ROW_H))
	var half := (w - PAD * 2 - GAP) / 2.0
	var delete := func() -> void:
		GameState.delete_save(save["path"])
		_show_saves(index)
	_button("DELETE", PAD, ASK_BUTTONS_Y, delete, half).add_theme_color_override("font_color", Palette.UI_BAD)
	_button("CANCEL", PAD + half + GAP, ASK_BUTTONS_Y, _show_saves.bind(index), half).grab_focus()
	_back = _show_saves.bind(index)


func _make_panel(caption: String, h: float, w: float = W) -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -w / 2.0
	_panel.offset_right = w / 2.0
	_panel.offset_top = -h / 2.0
	_panel.offset_bottom = h / 2.0
	add_child(_panel)
	_panel.add_child(UiTheme.panel(0, 0, w, h, Palette.UI_PANEL, Palette.UI_BORDER, 4))
	_panel.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.TITLE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), 0, 32, w, UiTheme.TITLE))


func _button(text: String, x: float, y: float, action: Callable, w: float = BUTTON_W) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, y, w, BUTTON_H)
	b.pressed.connect(action)
	_panel.add_child(b)
	return b


func _new_career() -> void:
	get_tree().change_scene_to_file("res://scenes/new_boxer.tscn")


func _close() -> void:
	closed.emit()
	queue_free()
