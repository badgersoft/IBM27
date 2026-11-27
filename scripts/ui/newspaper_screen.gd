extends Control
## The monthly newspaper, THE RINGSIDE GAZETTE (written by Newspaper), drawn
## as a newspaper: dark ink on an off-white sheet.
##
##   FRONT PAGE  the masthead between double rules (issue number, date and
##               price), the headline, a sepia "photo" of the main fight
##               beside its story, and the round-up; down the side column
##               the other stories (more title fights, features, the build-up
##               to a grudge match) and IN BRIEF: rankings climbers in the
##               player's division, retirements and new faces.
##   RESULTS     every fight of the month: winner, loser, how and when, the
##               purse and its excitement rating.
##
## In a career the player's own fight has a story marked YOUR FIGHT, and his
## name is picked out in red ink wherever the paper mentions him.
##
## Layout (1280 x 800 frame):
##   y  16  [FRONT PAGE][RESULTS]                                [CONTINUE]
##   y  72  the sheet (1248 x 712):
##            THE RINGSIDE GAZETTE
##            ====== NO. 3 ======= MARCH 2027 ======= 25 CENTS ======
##            HEADLINE                               | SIDE STORIES
##            [photo] story                          |
##            ROUND-UP                               | IN BRIEF
##
## CONTINUE goes back to the Fixtures screen (or the career page).

const FRAME_SIZE := Vector2(1280, 800)
const SHEET := Rect2(16, 72, 1248, 712)
const TAB_Y := 16
const TAB_SIZE := Vector2(256, 40)
const TAB_GAP := 16
const PAD := 16
## Paper and ink.
const PAPER := Color("efe6cf")
const PAPER_SHADE := Color("e2d6b8")
const INK := Color("1e1b17")
const INK_DIM := Color("5e564a")
const INK_RED := Color("9a1f1f")      ## The player's name, and YOUR FIGHT.
## The masthead and dateline.
const MASTHEAD_Y := 12
const RULE_Y := 72
const DATELINE_Y := 80
const DOUBLE_RULE_Y := 104
const PRICE := "25 CENTS"
## The front page: the main column (headline, photo and story, round-up) and
## the side column, with a rule between.
const BODY_Y := 120
const MAIN_W := 792
const SIDE_X := 840
const SIDE_W := 392
const PHOTO_VIEW := Vector2i(180, 100)
const PHOTO_SCALE := 2
const STORY_GAP := 24
## Extra space between wrapped lines, so a paragraph doesn't read as a block.
const LINE_SPACING := 8
## The results page: [caption, x, width, alignment].
const RESULT_COLUMNS := [
	["DIV",      16,  48, HORIZONTAL_ALIGNMENT_LEFT],
	["WINNER",   80, 320, HORIZONTAL_ALIGNMENT_LEFT],
	["",        400,  48, HORIZONTAL_ALIGNMENT_CENTER],
	["LOSER",   456, 320, HORIZONTAL_ALIGNMENT_LEFT],
	["RESULT",  784, 128, HORIZONTAL_ALIGNMENT_CENTER],
	["RDS",     920,  64, HORIZONTAL_ALIGNMENT_RIGHT],
	["PURSE",  1000, 112, HORIZONTAL_ALIGNMENT_RIGHT],
	["RATING", 1128,  88, HORIZONTAL_ALIGNMENT_RIGHT],
]
const RESULTS_Y := 128
## The front page's round-up shows this many lines (the rest are on
## RESULTS), fewer (ROUNDUP_SHORT) under a long lead story: one over
## LONG_STORY_LINES lines beside the photo.
const ROUNDUP_SHOWN := 6
const ROUNDUP_SHORT := 4
const LONG_STORY_LINES := 9
const RESULT_ROW_H := 52
const DIVISION_SHORT: Array[String] = ["LW", "MW", "HW"]
## The photo: greyed, then warmed to sepia.
const SEPIA_SHADER := """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.30, 0.59, 0.11));
	COLOR = vec4(vec3(g * 1.07, g * 0.94, g * 0.74) * 0.92 + vec3(0.05, 0.04, 0.02), c.a);
}
"""

var _frame: Control
var _sheet: Control
var _tabs: Array[Button] = []
var _paper: Dictionary = {}
var _results: Array[Fixture] = []


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
	var index := clampi(GameState.paper_index, 0, maxi(papers.size() - 1, 0))
	if not papers.is_empty():
		_paper = papers[index]
	_results.assign(_paper.get("results", []))

	for i in 2:
		var tab := Button.new()
		tab.text = ["FRONT PAGE", "RESULTS"][i]
		tab.focus_mode = Control.FOCUS_ALL
		UiTheme.place(tab, SHEET.position.x + i * (TAB_SIZE.x + TAB_GAP), TAB_Y, TAB_SIZE.x, TAB_SIZE.y)
		tab.pressed.connect(_show.bind(i))
		_frame.add_child(tab)
		_tabs.append(tab)
	var go_on := Button.new()
	go_on.text = "CONTINUE"
	go_on.focus_mode = Control.FOCUS_ALL
	UiTheme.place(go_on, SHEET.end.x - 256, TAB_Y, 256, TAB_SIZE.y)
	go_on.pressed.connect(_continue)
	_frame.add_child(go_on)

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


## Shows the front page (0) or the results (1) on a fresh sheet.
func _show(which: int) -> void:
	for i in _tabs.size():
		_style_tab(_tabs[i], i == which)
	if _sheet != null:
		_sheet.queue_free()
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_sheet, SHEET.position.x, SHEET.position.y, SHEET.size.x, SHEET.size.y))
	_sheet.add_child(UiTheme.block(Color(0, 0, 0, 0.5), 6, 6, SHEET.size.x, SHEET.size.y))   # Shadow.
	_sheet.add_child(UiTheme.panel(0, 0, SHEET.size.x, SHEET.size.y, PAPER, PAPER_SHADE, 2))
	_build_masthead()
	if which == 1:
		_build_results()
	else:
		_build_front_page()


## THE RINGSIDE GAZETTE, then the issue number, date and price between rules.
func _build_masthead() -> void:
	var w := SHEET.size.x
	_sheet.add_child(UiTheme.place(UiTheme.label(Newspaper.NAME, UiTheme.HUGE, INK, HORIZONTAL_ALIGNMENT_CENTER), 0, MASTHEAD_Y, w, UiTheme.HUGE))
	_sheet.add_child(UiTheme.block(INK, PAD, RULE_Y, w - PAD * 2, 2))
	var issue := GameState.season.papers.find(_paper) + 1
	var parts := [["NO. %d" % maxi(issue, 1), HORIZONTAL_ALIGNMENT_LEFT],
			[str(_paper.get("date", "")), HORIZONTAL_ALIGNMENT_CENTER], [PRICE, HORIZONTAL_ALIGNMENT_RIGHT]]
	for p in parts:
		_sheet.add_child(UiTheme.place(UiTheme.label(p[0], UiTheme.BODY, INK, p[1]), PAD, DATELINE_Y, w - PAD * 2, UiTheme.ROW_H))
	_sheet.add_child(UiTheme.block(INK, PAD, DOUBLE_RULE_Y, w - PAD * 2, 3))
	_sheet.add_child(UiTheme.block(INK, PAD, DOUBLE_RULE_Y + 6, w - PAD * 2, 1))


# ============================================================================
#  Front page
# ============================================================================

func _build_front_page() -> void:
	var height := SHEET.size.y - BODY_Y - PAD
	# The main column: headline, photo and story, round-up.
	var main := _column(PAD, BODY_Y, MAIN_W, height)
	if _paper.get("headline_player", false):
		main.add_child(_text("YOUR FIGHT", UiTheme.CAPTION, INK_RED, MAIN_W))
	main.add_child(_text(_paper.get("headline", ""), UiTheme.TITLE, INK, MAIN_W))
	var lead := HBoxContainer.new()
	lead.add_theme_constant_override("separation", PAD * 2)
	var photo := _photo()
	var story_w := MAIN_W
	if photo != null:
		lead.add_child(photo)
		story_w = MAIN_W - PHOTO_VIEW.x * PHOTO_SCALE - PAD * 2
	var standfirst := VBoxContainer.new()
	standfirst.custom_minimum_size.x = story_w
	_add_body(standfirst, _paper.get("standfirst", ""), _paper.get("headline_player", false), story_w)
	lead.add_child(standfirst)
	main.add_child(lead)
	var roundup: Array = _paper.get("roundup", [])
	if not roundup.is_empty():
		main.add_child(_gap(8))
		main.add_child(_rule(MAIN_W, 2))
		main.add_child(_text("THE ROUND-UP", UiTheme.LARGE, INK, MAIN_W))
		var story_lines := ceili(str(_paper.get("standfirst", "")).length() / floorf(story_w / UiTheme.BODY))
		var lines := mini(roundup.size(), ROUNDUP_SHORT if story_lines > LONG_STORY_LINES else ROUNDUP_SHOWN)
		main.add_child(_text("\n".join(roundup.slice(0, lines)), UiTheme.BODY, INK, MAIN_W))
		if roundup.size() > lines:
			main.add_child(_text("MORE RESULTS INSIDE.", UiTheme.CAPTION, INK_DIM, MAIN_W))

	# The rule between the columns, then the side column.
	_sheet.add_child(UiTheme.block(INK, SIDE_X - PAD - 1, BODY_Y, 1, height))
	var side := _column(SIDE_X, BODY_Y, SIDE_W, height)
	var stories: Array = _paper.get("stories", [])
	for i in stories.size():
		var story: Dictionary = stories[i]
		if i > 0:
			side.add_child(_gap(8))
			side.add_child(_rule(SIDE_W, 1))
		if story.get("player", false):
			side.add_child(_text("YOUR FIGHT", UiTheme.CAPTION, INK_RED, SIDE_W))
		side.add_child(_text(story["title"], UiTheme.LARGE, INK, SIDE_W))
		_add_body(side, story["text"], story.get("player", false), SIDE_W)
	if not stories.is_empty():
		side.add_child(_gap(8))
		side.add_child(_rule(SIDE_W, 2))
	side.add_child(_text("IN BRIEF", UiTheme.LARGE, INK, SIDE_W))
	var notes: Array = _paper.get("notes", [])
	if notes.is_empty():
		notes = ["NOTHING ELSE TO REPORT THIS MONTH."]
	for i in notes.size():
		if i > 0:
			side.add_child(_rule(SIDE_W, 1, 0.25))
		_add_body(side, notes[i], false, SIDE_W)


## The front-page photo of the main fight (the paper's "photo": the winner
## with his arms up and the loser hanging his head, two men who drew, or
## two rivals squaring up before a grudge match), in sepia, with a caption.
## Null if there is nobody to show.
func _photo() -> Control:
	var data: Dictionary = _paper.get("photo", {})
	if data.is_empty():
		var lead := Newspaper._lead_fight(_results)
		if lead == null:
			return null
		data = Newspaper.photo_of(lead)
	var a := _find_boxer(int(data["a"]))
	var b := _find_boxer(int(data["b"]))
	if a == null or b == null:
		return null
	var kind: String = data.get("kind", "win")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var viewport := SubViewport.new()
	viewport.size = PHOTO_VIEW
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	box.add_child(viewport)
	# A plain backdrop: the crowd in shadow, the ropes, the canvas.
	var backdrop := ColorRect.new()
	backdrop.color = Color("3a3d4a")
	backdrop.size = Vector2(PHOTO_VIEW)
	viewport.add_child(backdrop)
	for i in 3:
		var rope := ColorRect.new()
		rope.color = Color("c8c8c8")
		rope.position = Vector2(0, 34 + i * 12)
		rope.size = Vector2(PHOTO_VIEW.x, 1)
		viewport.add_child(rope)
	var canvas := ColorRect.new()
	canvas.color = Color("9a9a9a")
	canvas.position = Vector2(0, PHOTO_VIEW.y - 16)
	canvas.size = Vector2(PHOTO_VIEW.x, 16)
	viewport.add_child(canvas)
	var anims := ["victory", "dejected"]
	if kind == "draw":
		anims = ["ready", "ready"]
	elif kind == "faceoff":
		anims = ["guard", "guard"]
	_photo_rig(viewport, a, Vector2(62, PHOTO_VIEW.y - 8), 1, anims[0], 0)
	_photo_rig(viewport, b, Vector2(118, PHOTO_VIEW.y - 8), -1, anims[1], 1)
	var picture := TextureRect.new()
	picture.texture = viewport.get_texture()
	picture.custom_minimum_size = Vector2(PHOTO_VIEW * PHOTO_SCALE)
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shader := Shader.new()
	shader.code = SEPIA_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	picture.material = material
	var framed := PanelContainer.new()
	framed.add_theme_stylebox_override("panel", UiTheme.box(PAPER, INK, 2, 4))
	framed.add_child(picture)
	box.add_child(framed)
	var caption := "%s (LEFT) CELEBRATES HIS WIN OVER %s" % [a.last_name.to_upper(), b.last_name.to_upper()]
	if kind == "draw":
		caption = "%s AND %s: NOTHING IN IT" % [a.last_name.to_upper(), b.last_name.to_upper()]
	elif kind == "faceoff":
		caption = "%s AND %s FACE OFF" % [a.last_name.to_upper(), b.last_name.to_upper()]
	box.add_child(_text(caption, UiTheme.CAPTION, INK_DIM, PHOTO_VIEW.x * PHOTO_SCALE + 8))
	return box


func _photo_rig(viewport: SubViewport, b: BoxerData, feet: Vector2, facing: int, anim: String, corner: int) -> void:
	var rig := BoxerRig.new()
	viewport.add_child(rig)
	rig.setup(b, corner)
	rig.position = feet
	rig.facing = facing
	rig.snap_to(anim)
	rig.set_process(false)   # Frozen, like a photograph.
	var steps: Array = BoxerPoses.ANIMS[anim]["steps"]
	rig._pose = BoxerPoses.get_pose(steps[0][0]).duplicate()
	rig.queue_redraw()


## The boxer with [param id], ranked or retired, or null.
static func _find_boxer(id: int) -> BoxerData:
	for table in GameState.rankings:
		for b in table.boxers:
			if b.id == id:
				return b
	for b in GameState.season.retired:
		if b.id == id:
			return b
	return null


# ============================================================================
#  Results
# ============================================================================

## Every fight of the month: WINNER bt LOSER (or DREW WITH), how, rounds,
## purse and rating; the player's fight in red ink.
func _build_results() -> void:
	var w := SHEET.size.x
	_sheet.add_child(UiTheme.place(UiTheme.label("THIS MONTH'S RESULTS", UiTheme.LARGE, INK), PAD, BODY_Y, 640, UiTheme.LARGE))
	for col in RESULT_COLUMNS:
		_sheet.add_child(UiTheme.place(UiTheme.label(col[0], UiTheme.CAPTION, INK_DIM, col[3]), col[1], RESULTS_Y + 28, col[2], UiTheme.CAPTION))
	_sheet.add_child(UiTheme.block(INK, PAD, RESULTS_Y + 40, w - PAD * 2, 2))
	if _results.is_empty():
		_sheet.add_child(UiTheme.place(UiTheme.label("NO FIGHTS THIS MONTH", UiTheme.BODY, INK_DIM), PAD, RESULTS_Y + 56, 640, UiTheme.ROW_H))
		return
	var player := GameState.season.player
	var list := _results.duplicate()
	list.sort_custom(func(x: Fixture, y: Fixture) -> bool:
		if x.title != y.title:
			return x.title
		return x.division > y.division)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet.add_child(UiTheme.place(scroll, 0, RESULTS_Y + 48, w, SHEET.size.y - RESULTS_Y - 48 - PAD))
	var rows := Control.new()
	rows.custom_minimum_size = Vector2(w - 16, list.size() * RESULT_ROW_H)
	scroll.add_child(rows)
	for i in list.size():
		var f: Fixture = list[i]
		var y := i * RESULT_ROW_H
		if i % 2 == 1:
			rows.add_child(UiTheme.block(Color(PAPER_SHADE, 0.6), PAD, y, w - PAD * 2, RESULT_ROW_H))
		var mine := player != null and f.involves(player)
		var ink := INK_RED if mine else INK
		var winner := f.winner()
		var first := winner if winner != null else f.red
		var second := f.opponent_of(first)
		var values := [DIVISION_SHORT[f.division], first.display_name().to_upper(), "DREW" if winner == null else "BT",
				second.display_name().to_upper(), f.result_text() if f.is_done() else "-", str(f.rounds),
				Purse.money_text(f.purse), "%.1f" % f.excitement if f.is_done() else ""]
		var colours := [INK_DIM, ink, INK_DIM, INK_DIM if winner != null and not mine else ink, ink, INK, INK, INK]
		for c in RESULT_COLUMNS.size():
			var col: Array = RESULT_COLUMNS[c]
			var cell := UiTheme.label(values[c], UiTheme.BODY, colours[c], col[3])
			cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			rows.add_child(UiTheme.place(cell, col[1], y + 8, col[2], UiTheme.ROW_H))
		# Under the names: title fight, and the kind of result.
		var under := "IBC %s TITLE" % Divisions.division_name(f.division).to_upper() if f.title else ""
		rows.add_child(UiTheme.place(UiTheme.label(under, UiTheme.CAPTION, INK_RED if f.title else INK_DIM), RESULT_COLUMNS[1][1], y + 32, 320, UiTheme.CAPTION))
		var res: Array = RESULT_COLUMNS[4]
		rows.add_child(UiTheme.place(UiTheme.label(f.verdict_text(), UiTheme.CAPTION, INK_DIM, HORIZONTAL_ALIGNMENT_CENTER), res[1], y + 32, res[2], UiTheme.CAPTION))


# ============================================================================
#  Type
# ============================================================================

## A scrolling column of type inside the sheet.
func _column(x: float, y: float, w: float, h: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sheet.add_child(UiTheme.place(scroll, x, y, w + 8, h))
	# A thin ink scroll bar, for the odd column that runs long.
	var bar := scroll.get_v_scroll_bar()
	bar.add_theme_stylebox_override("scroll", UiTheme.box(PAPER_SHADE, PAPER_SHADE, 0))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, UiTheme.box(INK_DIM, INK_DIM, 0))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size.x = w
	scroll.add_child(column)
	return column


## A wrapping block of type [param width] wide.
static func _text(text: String, size: int, colour: Color, width: float) -> Label:
	var l := UiTheme.label(text, size, colour)
	l.clip_text = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.add_theme_constant_override("line_spacing", LINE_SPACING)
	return l


## Adds a wrapping block of body type [param width] wide to [param column],
## with the player's name in red ink (in his own story, [param his], his
## surname too).
func _add_body(column: Control, text: String, his: bool, width: float) -> void:
	var player := GameState.season.player if GameState.season != null else null
	var name := player.display_name().to_upper() if player != null else ""
	var surname := player.last_name.to_upper() if player != null else ""
	if player == null or not (text.contains(name) or (his and text.contains(surname))):
		column.add_child(_text(text, UiTheme.BODY, INK, width))
		return
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("normal_font", UiTheme.FONT)
	l.add_theme_font_size_override("normal_font_size", UiTheme.BODY)
	l.add_theme_color_override("default_color", INK)
	l.add_theme_constant_override("line_separation", LINE_SPACING)
	var red := "[color=#%s]%%s[/color]" % INK_RED.to_html(false)
	var shown := text.replace("[", "[lb]").replace(name, "\u0001")
	if his:
		shown = shown.replace(surname, red % surname)
	l.text = shown.replace("\u0001", red % name)
	column.add_child(l)


## A rule across a column.
static func _rule(width: float, thickness: int = 1, alpha: float = 1.0) -> ColorRect:
	var line := UiTheme.block(Color(INK, alpha), 0, 0, width, thickness)
	line.custom_minimum_size = Vector2(width, thickness)
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
