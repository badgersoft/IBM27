extends Control
## Developer tool: shows every boxer pose side by side, plus the full range of
## skin tones, hair colours and body sizes, at the real in-game pixel scale.
##
## Run it from the editor (scenes/debug/pose_sheet.tscn) or from the command
## line. Pass "--capture=<file.png>" after "--" to save a picture and quit:
##   godot --path . scenes/debug/pose_sheet.tscn -- --capture=/tmp/poses.png

const SHEET_SIZE := Vector2i(640, 300)
const SCALE := 3

const POSE_ROW := [
	"relaxed", "ready", "stance", "guard", "move_forward", "move_back",
	"jab", "cross", "hook", "uppercut", "body", "hurt", "ropes", "clinch",
]
const POSE_ROW_2 := ["to_knee", "knockdown", "stand_up", "taunt_skip", "taunt_one", "victory", "dejected"]

var _viewport: SubViewport


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = SHEET_SIZE
	_viewport.transparent_bg = false
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)

	var bg := ColorRect.new()
	bg.color = Color("3a4058")
	bg.size = SHEET_SIZE
	_viewport.add_child(bg)

	var gen := BoxerGenerator.new(7)
	# Row 1: one boxer in every pose (the punch poses are frozen at impact).
	var model := gen.generate_boxer()
	model.height_cm = 184
	model.hair_index = 4
	for i in POSE_ROW.size():
		_add_rig(model, Vector2(24 + i * 44, 96), POSE_ROW[i], i % 2)
	for i in POSE_ROW_2.size():
		_add_rig(model, Vector2(40 + i * 80, 196), POSE_ROW_2[i], 0)

	# Row 3: every skin tone and hair colour, shortest to tallest, light to heavy.
	for i in 6:
		var b := gen.generate_boxer()
		b.skin_index = i % 5
		b.hair_index = i
		b.hair_style = i % 4
		b.trunks_index = i
		b.height_cm = 170 + i * 5 + (3 if i == 5 else 0)
		b.weight_lb = 154 + i
		_add_rig(b, Vector2(40 + i * 60, 292), "stance", 0)
	for i in 5:
		var b := gen.generate_boxer()
		b.skin_index = 4 - i
		b.hair_index = (i + 2) % 6
		b.hair_style = (i + 1) % 4
		b.trunks_index = 6 + i % 4
		b.height_cm = 198 - i * 7
		b.weight_lb = 160 - i
		_add_rig(b, Vector2(400 + i * 50, 292), "guard", 1)

	var view := TextureRect.new()
	view.texture = _viewport.get_texture()
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.size = SHEET_SIZE * 2
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(view)

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			_capture(arg.trim_prefix("--capture="))


func _add_rig(boxer: BoxerData, pos: Vector2, anim: String, corner: int) -> void:
	var rig := BoxerRig.new()
	_viewport.add_child(rig)
	rig.setup(boxer, corner)
	rig.position = pos
	rig.facing = 1
	rig.snap_to(anim)
	rig.set_process(false)   # Freeze on the snapped pose.
	if anim in ["jab", "cross", "hook", "uppercut", "body"]:
		# Show the punch at the moment of impact rather than the recovery.
		var steps: Array = BoxerPoses.ANIMS[anim]["steps"]
		rig._pose = BoxerPoses.get_pose(steps[BoxerPoses.ANIMS[anim]["impact"]][0]).duplicate()
	elif anim in ["move_forward", "move_back", "taunt_skip"]:
		rig._pose = BoxerPoses.get_pose(BoxerPoses.ANIMS[anim]["steps"][0][0]).duplicate()
	rig.queue_redraw()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _viewport.get_texture().get_image()
	img.resize(SHEET_SIZE.x * SCALE, SHEET_SIZE.y * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
	print("Saved pose sheet to ", path)
	get_tree().quit()
