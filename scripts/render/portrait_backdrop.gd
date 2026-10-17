class_name PortraitBackdrop
extends Node2D
## The backdrop behind a boxer's portrait on his profile: a dark studio
## fading up from the floor, a spotlight from above and a pool of light on
## the floor where he stands. Drawn in low-resolution pixels like the arena.

var size := Vector2(128, 176)
## Floor line (where the boxer's feet are).
var floor_y := 164.0

const BANDS: Array[Color] = [Color("07080f"), Color("0a0c16"), Color("0d101d"), Color("111526"), Color("151a2f")]
const FLOOR := Color("1b2038")
const FLOOR_EDGE := Color("262c4a")
const SPOT := Color(1.0, 0.95, 0.8, 0.06)
const POOL := Color(1.0, 0.95, 0.8, 0.10)


func _draw() -> void:
	# Wall: darker towards the top, in hard steps (no smooth gradient).
	var band_h := ceilf((floor_y - 12.0) / BANDS.size())
	for i in BANDS.size():
		draw_rect(Rect2(0, i * band_h, size.x, band_h), BANDS[i])
	# Floor.
	var top := floor_y - 12.0
	draw_rect(Rect2(0, top, size.x, size.y - top), FLOOR)
	draw_rect(Rect2(0, top, size.x, 1), FLOOR_EDGE)
	# Spotlight cone from above, and its pool on the floor.
	var cx := size.x / 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 10, 0), Vector2(cx + 10, 0), Vector2(cx + 46, floor_y), Vector2(cx - 46, floor_y),
	]), SPOT)
	var pool := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pool.append(Vector2(cx + cos(a) * 46.0, floor_y + sin(a) * 7.0))
	draw_colored_polygon(pool, POOL)
