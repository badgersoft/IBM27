extends Control
## Main menu: title, a window onto the Boxing Hall with two boxers from the
## roster squaring up, and a single START button.
##
## Vertical rhythm (1280 x 720 frame, all on the 8 px grid):
##   y  32  "BADGER-SOFT PRESENTS"          body, dim
##   y  64  "INTERNATIONAL BOXING MANAGER"  title
##   y 104  "2027"                          96 px, gold
##   y 232  arena window                    848 x 336 (arena at x2)
##   y 600  [ START ]                       320 x 64
##   y 688  version line                    caption

const FRAME_SIZE := Vector2(1280, 720)
const BUTTON_SIZE := Vector2(320, 64)
const ARENA_SCALE := 2
const ARENA_Y := 232

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

	_build_backdrop(frame)

	var presents := UiTheme.label("BADGER-SOFT PRESENTS", UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	frame.add_child(UiTheme.place(presents, 0, 32, FRAME_SIZE.x, 24))

	var title := UiTheme.label("INTERNATIONAL BOXING MANAGER", UiTheme.TITLE, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.outline(title, 12)
	title.clip_text = false
	frame.add_child(UiTheme.place(title, 0, 64, FRAME_SIZE.x, 32))

	var year := UiTheme.label("2027", UiTheme.HUGE * 2, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.outline(year, 16)
	year.clip_text = false
	frame.add_child(UiTheme.place(year, 0, 104, FRAME_SIZE.x, 96))

	_start = Button.new()
	_start.text = "START"
	_start.add_theme_font_size_override("font_size", UiTheme.LARGE)
	UiTheme.place(_start, (FRAME_SIZE.x - BUTTON_SIZE.x) / 2.0, 600, BUTTON_SIZE.x, BUTTON_SIZE.y)
	_start.pressed.connect(_on_start)
	frame.add_child(_start)
	_start.grab_focus()

	var version := "VERSION %s  -  PROTOTYPE BUILD  -  2027 BADGER-SOFT" % ProjectSettings.get_setting("application/config/version", "0.1")
	frame.add_child(UiTheme.place(UiTheme.label(version, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), 0, 688, FRAME_SIZE.x, 12))

	if GameState.options.has("capture") and GameState.options.get("show", "") == "menu":
		_capture(GameState.options["capture"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not OS.has_feature("mobile"):
		get_tree().quit()


## The ring at the boxing hall, framed, with two boxers from the roster.
func _build_backdrop(frame: Control) -> void:
	_view = ArenaView.new()
	add_child(_view)
	_view.setup(Venues.Id.BOXING_HALL, GameState.roster[0], GameState.roster[1])
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


func _on_start() -> void:
	GameState.new_fight()
	get_tree().change_scene_to_file("res://scenes/fight.tscn")


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
