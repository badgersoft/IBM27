class_name BeltIcon
extends Control
## The IBC title belt, drawn as a little pixel-art icon beside a champion's
## name: a black strap with a big silver plate in the middle and a smaller
## silver plate either side.
##
## The art is 24 x 8 "belt pixels", drawn at [member pixel] screen pixels
## each (2 = 48 x 16 for 16 px text, 3 = 72 x 24 for bigger text).
##
##   x  0         3  6 8      15 17 20       23
##      . . . . . o--o o------o  o--o . . . .    row 0 - 7
##      strap      side  centre   side   strap

const ART_W := 24
const ART_H := 8

const STRAP := Color("141414")
const STRAP_EDGE := Color("3a3a40")      ## Stitching along the strap's edges.
const PLATE := Color("c8ccd4")
const PLATE_LIGHT := Color("f2f4f8")
const PLATE_DARK := Color("868c98")
const PLATE_RIM := Color("4a4e58")

var pixel := 2


func _init(pixel_size: int = 2) -> void:
	pixel = pixel_size
	custom_minimum_size = Vector2(ART_W, ART_H) * pixel
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Width on screen for [param pixel_size].
static func width_for(pixel_size: int) -> int:
	return ART_W * pixel_size


func _draw() -> void:
	# Strap, with a lighter stitched edge top and bottom.
	_rect(0, 2, ART_W, 4, STRAP)
	_rect(0, 2, ART_W, 1, STRAP_EDGE)
	_rect(0, 5, ART_W, 1, STRAP_EDGE)
	# Side plates, then the centre plate over the middle.
	_plate(3, 1, 4, 6)
	_plate(17, 1, 4, 6)
	_plate(8, 0, 8, 8)
	# A raised boss in the middle of the centre plate.
	_rect(11, 3, 2, 2, PLATE_DARK)
	_rect(11, 3, 1, 1, PLATE_LIGHT)


## A plate with its rim's corners cut off, so it reads as rounded.
func _plate(x: int, y: int, w: int, h: int) -> void:
	_rect(x + 1, y, w - 2, h, PLATE_RIM)
	_rect(x, y + 1, w, h - 2, PLATE_RIM)
	_rect(x + 1, y + 1, w - 2, h - 2, PLATE)
	_rect(x + 1, y + 1, w - 2, 1, PLATE_LIGHT)      # Light catching the top...
	_rect(x + 1, y + 1, 1, h - 2, PLATE_LIGHT)      # ...and the left edge.
	_rect(x + 1, y + h - 2, w - 2, 1, PLATE_DARK)   # Shade along the bottom.


func _rect(x: int, y: int, w: int, h: int, colour: Color) -> void:
	draw_rect(Rect2(x * pixel, y * pixel, w * pixel, h * pixel), colour)
