class_name CareerMenu
extends Control
## The CAREER pop-up on the main menu, over a dimmed screen:
##
##   START NEW CAREER        -> the new boxer screen
##   CONTINUE SAVED CAREER   -> (only when there are saves) a list of them
##   CANCEL
##
## Choosing a save and LOAD opens that career's home page.

signal closed

const W := 640
const BUTTON_W := 512
const BUTTON_H := 56
const GAP := 16
const LIST_H := 248

var _panel: Control


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
		_close()
		get_viewport().set_input_as_handled()


func _show_choices() -> void:
	var saves := GameState.list_saves()
	var buttons := [["START NEW CAREER", _new_career], ["CANCEL", _close]]
	if not saves.is_empty():
		buttons.insert(1, ["CONTINUE SAVED CAREER", _show_saves])
	var h := 96 + buttons.size() * (BUTTON_H + GAP) + GAP
	_make_panel("CAREER", h)
	for i in buttons.size():
		var b := _button(buttons[i][0], (W - BUTTON_W) / 2.0, 96 + i * (BUTTON_H + GAP), buttons[i][1])
		if i == 0:
			b.grab_focus()


func _show_saves() -> void:
	var saves := GameState.list_saves()
	_make_panel("SAVED CAREERS", 96 + LIST_H + GAP * 2 + BUTTON_H + GAP)
	var list := ItemList.new()
	for save in saves:
		list.add_item("%s   %s" % [save["title"], save["date"]])
	list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_panel.add_child(UiTheme.place(list, 32, 88, W - 64, LIST_H))
	list.select(0)
	var load_selected := func() -> void:
		var picked := list.get_selected_items()
		if not picked.is_empty() and GameState.load_career(saves[picked[0]]["path"]):
			get_tree().change_scene_to_file("res://scenes/career_home.tscn")
	list.item_activated.connect(func(_i: int) -> void: load_selected.call())
	var y := 88 + LIST_H + GAP * 2
	var half := (W - 64 - GAP) / 2.0
	_button("LOAD", 32, y, load_selected, half).grab_focus()
	_button("BACK", 32 + half + GAP, y, _show_choices, half)


func _make_panel(caption: String, h: float) -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -W / 2.0
	_panel.offset_right = W / 2.0
	_panel.offset_top = -h / 2.0
	_panel.offset_bottom = h / 2.0
	add_child(_panel)
	_panel.add_child(UiTheme.panel(0, 0, W, h, Palette.UI_PANEL, Palette.UI_BORDER, 4))
	_panel.add_child(UiTheme.place(UiTheme.label(caption, UiTheme.TITLE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), 0, 32, W, UiTheme.TITLE))


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
