class_name ArenaView
extends SubViewport
## The low-resolution "game screen" that holds the venue and both boxers.
##
## It renders at ArenaRenderer.SIZE (424 x 168) and is shown on screen through
## a TextureRect with nearest-neighbour filtering, which is what gives the
## chunky Amiga-style pixels. UI text is NOT drawn in here - it lives in normal
## Controls at full resolution so it stays sharp and readable.

var arena: ArenaRenderer
var rigs: Array[BoxerRig] = []


func _init() -> void:
	size = ArenaRenderer.SIZE
	disable_3d = true
	transparent_bg = false
	snap_2d_transforms_to_pixel = true
	snap_2d_vertices_to_pixel = true
	canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Builds the venue and places both boxers in their corners.
func setup(venue_id: int, red: BoxerData, blue: BoxerData) -> void:
	for child in get_children():
		child.queue_free()
	rigs.clear()

	arena = ArenaRenderer.new()
	arena.name = "Arena"
	add_child(arena)
	arena.setup(venue_id)

	var boxers := [red, blue]
	for corner in 2:
		var rig := BoxerRig.new()
		rig.name = "Red" if corner == 0 else "Blue"
		arena.fighter_layer.add_child(rig)
		rig.setup(boxers[corner], corner)
		rig.facing = 1 if corner == 0 else -1
		rig.position = Vector2(ArenaRenderer.CORNER_X[corner], ArenaRenderer.FIGHT_Y)
		rigs.append(rig)


## Places a boxer at arena x, keeping him on the canvas line.
func place(corner: int, x: float) -> void:
	rigs[corner].position = Vector2(roundf(x), ArenaRenderer.FIGHT_Y)
