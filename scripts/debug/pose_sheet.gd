extends Control
## Developer tool: every boxer pose in a labelled grid, plus a row showing the
## range of skin tones, hair, heights and weights, at the real in-game pixel
## scale.
##
## Run it from the editor (scenes/debug/pose_sheet.tscn) or from the command
## line. Pass "--capture=<file.png>" after "--" to save a picture and quit:
##   godot --path . scenes/debug/pose_sheet.tscn -- --capture=/tmp/poses.png

const COLUMNS := 7
const CELL := Vector2(88, 120)
const SHEET_SIZE := Vector2i(616, 480)   # 7 x 88 wide, 4 x 120 tall.
const SCALE := 2
const FONT := preload("res://assets/fonts/PressStart2P.woff2")

## [label, animation, which step to freeze on (-1 = last)].
const POSES := [
	["RELAXED", "relaxed", 0], ["READY", "ready", 0], ["STANCE", "stance", 0],
	["GUARD", "guard", 0], ["FORWARD", "move_forward", 0], ["BACK", "move_back", 0],
	["JAB", "jab", 1], ["CROSS", "cross", 1], ["HOOK", "hook", 1],
	["UPPERCUT", "uppercut", 1], ["BODY", "body", 1], ["HIT HEAD", "hurt", 0],
	["HIT BODY", "hurt_body", 0], ["ROPES", "ropes", 0], ["CLINCH", "clinch", 0],
	["KNEE", "to_knee", 0], ["FLOORED", "knockdown", -1], ["TAUNT 1", "taunt_skip", 0],
	["TAUNT 2", "taunt_one", 0], ["VICTORY", "victory", 0], ["DEJECTED", "dejected", 0],
]

var _viewport: SubViewport


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SHEET_SIZE
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)

	var labels := Node2D.new()
	labels.draw.connect(_draw_labels.bind(labels))
	var bg := ColorRect.new()
	bg.color = Color("2c3148")
	bg.size = SHEET_SIZE
	_viewport.add_child(bg)

	var gen := BoxerGenerator.new(7)
	var model := gen.generate_boxer()
	model.height_cm = 184
	model.hair_index = 4
	for i in POSES.size():
		var cell := Vector2(i % COLUMNS, i / COLUMNS) * CELL
		var x_offset := 12.0 if POSES[i][1] == "knockdown" else 0.0
		_add_rig(model, cell + Vector2(CELL.x * 0.5 + x_offset, CELL.y - 22), POSES[i][1], POSES[i][2], i % 2)

	# Bottom row: every skin tone and hair colour, shortest to tallest.
	for i in COLUMNS:
		var b := gen.generate_boxer()
		b.skin_index = i % 5
		b.hair_index = (i + 1) % 6 if i < 6 else 0
		b.hair_style = i % 4
		b.trunks_index = i
		b.height_cm = 170 + i * 28 / (COLUMNS - 1)
		b.weight_lb = 154 + i
		_add_rig(b, Vector2(i * CELL.x + CELL.x * 0.5, 3 * CELL.y + CELL.y - 22), "stance", 0, i % 2)

	_viewport.add_child(labels)

	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.size = SHEET_SIZE * SCALE
	add_child(view)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture(arg.trim_prefix("--capture="))


func _add_rig(boxer: BoxerData, pos: Vector2, anim: String, step: int, corner: int) -> void:
	var rig := BoxerRig.new()
	_viewport.add_child(rig)
	rig.setup(boxer, corner)
	rig.position = pos
	rig.facing = 1
	rig.snap_to(anim)
	rig.set_process(false)   # Freeze on one pose.
	var steps: Array = BoxerPoses.ANIMS[anim]["steps"]
	rig._pose = BoxerPoses.get_pose(steps[step][0]).duplicate()
	rig.queue_redraw()


func _draw_labels(c: CanvasItem) -> void:
	for i in POSES.size():
		var cell := Vector2(i % COLUMNS, i / COLUMNS) * CELL
		c.draw_string(FONT, cell + Vector2(0, CELL.y - 6), POSES[i][0], HORIZONTAL_ALIGNMENT_CENTER, CELL.x, 8, Color("e8e4d8"))
	for i in COLUMNS:
		var cell := Vector2(i * CELL.x, 3 * CELL.y)
		var cm := 170 + i * 28 / (COLUMNS - 1)
		c.draw_string(FONT, cell + Vector2(0, CELL.y - 6), "%d CM" % cm, HORIZONTAL_ALIGNMENT_CENTER, CELL.x, 8, Color("8a90aa"))


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	img.resize(SHEET_SIZE.x * SCALE, SHEET_SIZE.y * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("Saved pose sheet to ", path)
	get_tree().quit()
