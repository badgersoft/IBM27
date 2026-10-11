extends Control
## Developer tool: shows each venue with two random boxers squaring up.
##
##   godot --path . scenes/debug/venue_preview.tscn -- --venue=2 --capture=/tmp/hall.png

const SCALE := 3

var _view: ArenaView


func _ready() -> void:
	var venue := 0
	var capture := ""
	var seed_value := 42
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--venue="):
			venue = int(arg.trim_prefix("--venue="))
		elif arg.begins_with("--capture="):
			capture = arg.trim_prefix("--capture=")
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))

	var gen := BoxerGenerator.new(seed_value)
	var roster := gen.generate_roster(5)
	_view = ArenaView.new()
	add_child(_view)
	_view.setup(venue, roster[0], roster[1])
	_view.place(0, 180)
	_view.place(1, 226)
	_view.rigs[0].play("stance")
	_view.rigs[1].play("jab")

	var rect := TextureRect.new()
	rect.texture = _view.get_texture()
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.size = Vector2(ArenaRenderer.SIZE * SCALE)
	add_child(rect)

	if not capture.is_empty():
		await get_tree().create_timer(0.6).timeout
		var img := _view.get_texture().get_image()
		img.resize(ArenaRenderer.SIZE.x * SCALE, ArenaRenderer.SIZE.y * SCALE, Image.INTERPOLATE_NEAREST)
		img.save_png(capture)
		get_tree().quit()
