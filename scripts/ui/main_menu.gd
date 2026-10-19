extends Control
## Main menu: title, a window onto the Boxing Hall with two boxers from the
## roster squaring up, and three buttons: an EXHIBITION (pick any two boxers,
## or let the computer pick), a CAREER (start one or carry on a saved one), or
## look at the BOXERS.
##
## Vertical rhythm (1280 x 800 frame, all on the 8 px grid):
##   y  40  "BADGER-SOFT PRESENTS"          body, dim
##   y  72  "INTERNATIONAL BOXING MANAGER"  title
##   y 112  "2027"                          96 px, gold
##   y 248  arena window                    848 x 336 (arena at x2)
##   y 632  [EXHIBITION] [CAREER] [BOXERS]  288 x 64 each, 32 apart
##   y 752  version line                    caption

const FRAME_SIZE := Vector2(1280, 800)
const BUTTON_SIZE := Vector2(288, 64)
const BUTTON_GAP := 32
const ARENA_SCALE := 2
const ARENA_Y := 248
const BUTTON_Y := 632

var _view: ArenaView
var _start: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := UiTheme.block(Palette.UI_BACKGROUND, 0, 0, 0, 0)
	add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -FRAME_SIZE.x / 2.0
	frame.offset_top = -FRAME_SIZE.y / 2.0
	frame.offset_right = FRAME_SIZE.x / 2.0
	frame.offset_bottom = FRAME_SIZE.y / 2.0
	add_child(frame)

	GameState.leave_career()
	_build_backdrop(frame)

	var presents := UiTheme.label("BADGER-SOFT PRESENTS", UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	frame.add_child(UiTheme.place(presents, 0, 40, FRAME_SIZE.x, 24))

	var title := UiTheme.label("INTERNATIONAL BOXING MANAGER", UiTheme.TITLE, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.outline(title, 12)
	title.clip_text = false
	frame.add_child(UiTheme.place(title, 0, 72, FRAME_SIZE.x, 32))

	var year := UiTheme.label("2027", UiTheme.HUGE * 2, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.outline(year, 16)
	year.clip_text = false
	frame.add_child(UiTheme.place(year, 0, 112, FRAME_SIZE.x, 96))

	var left := (FRAME_SIZE.x - BUTTON_SIZE.x * 3 - BUTTON_GAP * 2) / 2.0
	_start = _menu_button(frame, "EXHIBITION", left, _on_exhibition)
	_menu_button(frame, "CAREER", left + BUTTON_SIZE.x + BUTTON_GAP, _on_career)
	_menu_button(frame, "BOXERS", left + (BUTTON_SIZE.x + BUTTON_GAP) * 2, _on_boxers)
	_start.grab_focus()

	var version := "VERSION %s  -  PROTOTYPE BUILD  -  2027 BADGER-SOFT" % ProjectSettings.get_setting("application/config/version", "0.1")
	frame.add_child(UiTheme.place(UiTheme.label(version, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), 0, 752, FRAME_SIZE.x, 12))

	var show: String = GameState.options.get("show", "")
	if GameState.options.has("capture") and show in ["menu", "career_menu"]:
		if show == "career_menu":
			_on_career()
		_capture(GameState.options["capture"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not OS.has_feature("mobile"):
		get_tree().quit()


## The ring at the boxing hall, framed, with two boxers from the roster.
func _build_backdrop(frame: Control) -> void:
	_view = ArenaView.new()
	add_child(_view)
	var middleweights := GameState.boxers_in(Divisions.Id.MIDDLEWEIGHT)
	_view.setup(Venues.Id.BOXING_HALL, middleweights[0], middleweights[1])
	_view.place(0, 176)
	_view.place(1, 248)
	_view.rigs[0].play("stance")
	_view.rigs[1].play("guard")

	var size := Vector2(ArenaRenderer.SIZE * ARENA_SCALE)
	var x := (FRAME_SIZE.x - size.x) / 2.0
	frame.add_child(UiTheme.panel(x - 4, ARENA_Y - 4, size.x + 8, size.y + 8, Palette.UI_PANEL_DARK, Palette.UI_BORDER, 2))
	var arena := TextureRect.new()
	arena.texture = _view.get_texture()
	arena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(UiTheme.place(arena, x, ARENA_Y, size.x, size.y))


func _menu_button(frame: Control, text: String, x: float, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", UiTheme.LARGE)
	UiTheme.place(b, x, BUTTON_Y, BUTTON_SIZE.x, BUTTON_SIZE.y)
	b.pressed.connect(action)
	frame.add_child(b)
	return b


func _on_career() -> void:
	var menu := CareerMenu.new()
	menu.closed.connect(func() -> void: _start.grab_focus())
	add_child(menu)


func _on_boxers() -> void:
	GameState.picking = false
	get_tree().change_scene_to_file("res://scenes/roster.tscn")


func _on_exhibition() -> void:
	GameState.picking = true
	get_tree().change_scene_to_file("res://scenes/roster.tscn")


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
