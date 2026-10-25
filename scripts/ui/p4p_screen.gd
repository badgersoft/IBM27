extends Control
## The pound-for-pound top ten: the best boxers in the IBC whatever their
## weight (PoundForPound has how they are rated). Opened from the Boxers
## screen; BACK returns there.
##
## Layout (1280 x 800 frame):
##   y  16  POUND FOR POUND                                       [BACK]
##   y  80  panel (1248 x 704):
##            #  NAME            DIV  RANK  RECORD  KO  BEST WIN   SCORE
##            ten rows, then how the list is worked out

const FRAME_SIZE := Vector2(1280, 800)
const PANEL := Rect2(16, 80, 1248, 704)
const PAD := 16
const HEADER_Y := 24
const FIRST_ROW_Y := 48
const ROW_H := 56
const VALUE_Y := 8               ## The main line of a row...
const SUB_Y := 30                ## ...and the caption line under it.
const COUNT := 10
## [caption, x, width, alignment]
const COLUMNS := [
	["#",          24,  48, HORIZONTAL_ALIGNMENT_RIGHT],
	["NAME",       96, 352, HORIZONTAL_ALIGNMENT_LEFT],
	["DIV",       464,  64, HORIZONTAL_ALIGNMENT_CENTER],
	["RANK",      544,  80, HORIZONTAL_ALIGNMENT_CENTER],
	["RECORD",    640, 176, HORIZONTAL_ALIGNMENT_CENTER],
	["KO",        832,  64, HORIZONTAL_ALIGNMENT_RIGHT],
	["BEST WIN",  928, 208, HORIZONTAL_ALIGNMENT_LEFT],
	["SCORE",    1144,  80, HORIZONTAL_ALIGNMENT_RIGHT],
]
const DIVISION_SHORT: Array[String] = ["LW", "MW", "HW"]
const NOTE := "RATED ON THEIR RECORDS (WINS AND KNOCKOUTS COUNT, LOSSES COST) AND THIS SEASON'S FIGHTS:\nA WIN OR A KNOCKOUT OVER A HIGHER-RANKED MAN IS WORTH MORE, A LOSS TO A LOWER-RANKED ONE COSTS MORE."

var _frame: Control


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

	_frame.add_child(UiTheme.place(UiTheme.label("POUND FOR POUND", UiTheme.TITLE, Palette.UI_GOLD), 24, 24, 640, UiTheme.TITLE))
	var back := Button.new()
	back.text = "BACK"
	back.focus_mode = Control.FOCUS_ALL
	UiTheme.place(back, FRAME_SIZE.x - 16 - 192, 16, 192, 48)
	back.pressed.connect(_go_back)
	_frame.add_child(back)
	back.grab_focus()
	_build_table()

	if GameState.options.has("capture") and GameState.options.get("show", "") == "p4p":
		_capture(GameState.options["capture"])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _go_back() -> void:
	GameState.picking = false
	get_tree().change_scene_to_file("res://scenes/roster.tscn")


func _build_table() -> void:
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(panel, PANEL.position.x, PANEL.position.y, PANEL.size.x, PANEL.size.y))
	panel.add_child(UiTheme.panel(0, 0, PANEL.size.x, PANEL.size.y))
	for col in COLUMNS:
		panel.add_child(UiTheme.place(UiTheme.label(col[0], UiTheme.CAPTION, Palette.UI_TEXT_DIM, col[3]), col[1], HEADER_Y, col[2], UiTheme.CAPTION))
	var list := PoundForPound.top(GameState.rankings, GameState.season, COUNT)
	var player := GameState.season.player
	for i in list.size():
		var entry: Dictionary = list[i]
		var b: BoxerData = entry["boxer"]
		var table: Rankings = GameState.rankings[b.division]
		var y := FIRST_ROW_Y + i * ROW_H
		if i % 2 == 0:
			panel.add_child(UiTheme.block(Color(1, 1, 1, 0.04), 8, y, PANEL.size.x - 16, ROW_H))
		var mine := player != null and b == player
		var name_colour := Palette.UI_GOLD if mine or table.is_champion(b) else Palette.UI_TEXT
		var values := [
			str(i + 1), b.display_name().to_upper(), DIVISION_SHORT[b.division], table.rank_label(b),
			b.record(), str(b.kos), _best_win_name(entry["best_win"]), "%.1f" % entry["score"],
		]
		var colours := [Palette.UI_GOLD, name_colour, Palette.UI_TEXT_DIM, Palette.UI_GOLD,
				Palette.UI_TEXT, Palette.UI_TEXT, Palette.UI_TEXT, Palette.UI_GOLD]
		for c in COLUMNS.size():
			var col: Array = COLUMNS[c]
			panel.add_child(UiTheme.place(UiTheme.label(values[c], UiTheme.BODY, colours[c], col[3]), col[1], y + VALUE_Y, col[2], UiTheme.ROW_H))
		# Captions: his nickname (or IBC CHAMPION) and how the best win went.
		var under_name := "IBC %s CHAMPION" % b.division_name().to_upper() if table.is_champion(b) else ("\"%s\"" % b.nickname.to_upper() if not b.nickname.is_empty() else "")
		panel.add_child(UiTheme.place(UiTheme.label(under_name, UiTheme.CAPTION, Palette.UI_GOLD if table.is_champion(b) else Palette.UI_TEXT_DIM), COLUMNS[1][1], y + SUB_Y, COLUMNS[1][2], UiTheme.CAPTION))
		panel.add_child(UiTheme.place(UiTheme.label(_best_win_how(entry["best_win"]), UiTheme.CAPTION, Palette.UI_TEXT_DIM), COLUMNS[6][1], y + SUB_Y, COLUMNS[6][2], UiTheme.CAPTION))
	var note := UiTheme.label(NOTE, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	note.clip_text = false
	note.add_theme_constant_override("line_spacing", 8)
	panel.add_child(UiTheme.place(note, PAD, FIRST_ROW_Y + COUNT * ROW_H + 24, PANEL.size.x - PAD * 2, 32))


## "COTE", or "-" if he has no win this season.
static func _best_win_name(best: Dictionary) -> String:
	if best.is_empty():
		return "-"
	return (best["opponent"] as BoxerData).last_name.to_upper()


## "WAS C - BY KO", "WAS NO. 4 - ON POINTS".
static func _best_win_how(best: Dictionary) -> String:
	if best.is_empty():
		return "NONE THIS SEASON"
	var place: int = best["place"]
	var rank := "C" if place == 0 else ("NO. %d" % place if place > 0 else "UNRANKED")
	return "WAS %s - %s" % [rank, "BY KO" if best["ko"] else "ON POINTS"]


func _capture(path: String) -> void:
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
