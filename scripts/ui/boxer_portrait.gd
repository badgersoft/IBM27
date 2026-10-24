class_name BoxerPortrait
extends Control
## A boxer standing face-on in the studio spotlight, drawn in a small
## low-res viewport and shown at [member pixel_scale] (as on the profile).
## show_boxer() redraws him after any change to his looks.

var view_size := Vector2i(104, 190)
var pixel_scale := 3
var figure_size := 1.6
var feet_y := 176.0

var _viewport: SubViewport
var _rig: FrontRig


## [param view] low-res pixels, shown at [param scale_by]; the figure drawn
## [param figure] times his ring size with his feet at [param feet].
func _init(view: Vector2i, scale_by: int, figure: float, feet: float) -> void:
	view_size = view
	pixel_scale = scale_by
	figure_size = figure
	feet_y = feet
	size = Vector2(view_size * pixel_scale)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	_viewport.size = view_size
	_viewport.disable_3d = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)
	var backdrop := PortraitBackdrop.new()
	backdrop.size = Vector2(view_size)
	backdrop.floor_y = feet_y
	_viewport.add_child(backdrop)
	_rig = FrontRig.new()
	_rig.position = Vector2(view_size.x / 2.0, feet_y)
	_viewport.add_child(_rig)

	var picture := TextureRect.new()
	picture.texture = _viewport.get_texture()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.place(picture, 0, 0, size.x, size.y))


## Draws [param b] (in his own gloves if he has them, otherwise gloves in
## his trunks' colour; there is no corner here).
func show_boxer(b: BoxerData) -> void:
	_rig.setup_boxer(b, 0, true, figure_size)
	var gloves := b.gloves_index if b.gloves_index >= 0 else b.trunks_index
	_rig.set_glove_tones(Palette.TRUNKS[gloves]["tones"])
	_rig.queue_redraw()
