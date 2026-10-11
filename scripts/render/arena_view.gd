class_name ArenaView
extends SubViewport
## The low-resolution "game screen" that holds the venue and both boxers.
##
## It renders at ArenaRenderer.SIZE (424 x 168) and is shown on screen through
## a TextureRect with nearest-neighbour filtering, which is what gives the
## chunky Amiga-style pixels. UI text is NOT drawn in here - it lives in normal
## Controls at full resolution so it stays sharp and readable.

## Where the boxers and referee stand for the verdict: the middle of the
## canvas, in the centre of the ring.
const CEREMONY_Y := 130.0

var arena: ArenaRenderer
var rigs: Array[BoxerRig] = []
var ceremony: Ceremony


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


## Swaps the side-on fight for the face-on line-up waiting for the verdict.
func show_ceremony(red: BoxerData, blue: BoxerData, ref_skin: int) -> Ceremony:
	for rig in rigs:
		rig.visible = false
	arena.hide_corner_advice()
	ceremony = Ceremony.new()
	ceremony.position = Vector2(ArenaRenderer.SIZE.x / 2.0, CEREMONY_Y)
	arena.fighter_layer.add_child(ceremony)
	ceremony.setup(red, blue, ref_skin)
	return ceremony
