class_name BeltIcon
extends Control
## The IBC title belt, drawn as a little pixel-art icon beside a champion's
## name: a black strap (lit along its top edge, with silver stitching) with a
## big oval silver plate in the middle, engraved with a ring and a star, and
## a smaller riveted silver plate either side.
##
## The art is ART_W x ART_H "belt pixels" (ART, one letter per pixel, see
## PALETTE), drawn at [member pixel] screen pixels each: x2 (64 x 24) on the
## name plates and the fixtures, x3 (96 x 36) in the Boxers list, x4
## (128 x 48) on the profile. The other designs considered are on the belt
## sheet (scenes/debug/belt_sheet.tscn).

const ART_W := 32
const ART_H := 12

## K strap edge, k strap, z strap shadow, x stitching, o plate rim,
## d plate shade, s plate, w plate highlight, g engraving.
const PALETTE := {
	"K": Color("4a4a54"),
	"k": Color("161618"),
	"z": Color("08080a"),
	"x": Color("8a8a94"),
	"o": Color("3c4048"),
	"d": Color("7e8494"),
	"s": Color("c4c8d2"),
	"w": Color("f4f6fa"),
	"g": Color("5c6270"),
}
const ART: Array[String] = [
	".............oooooo.............",
	"...........oowwwsssoo...........",
	"...oooo...owwwwsssssso...oooo...",
	".KowwwwoKKowwwggggsssoKKowwwwoK.",
	"kkowssdoxowwsgswwsgsssokowssdokk",
	"kkowggdokowsgswwwwsgddokowggdokk",
	"kkowggdokossgswwwwsgddokowggdokk",
	"kkowssdoxosssgswwsgdddokowssdokk",
	".zowdddozzosssggggdddozzowdddoz.",
	"...oooo...osssssdddddo...oooo...",
	"...........oossddddoo...........",
	".............oooooo.............",
]

var pixel := 2


func _init(pixel_size: int = 2) -> void:
	pixel = pixel_size
	custom_minimum_size = Vector2(ART_W, ART_H) * pixel
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Width on screen for [param pixel_size].
static func width_for(pixel_size: int) -> int:
	return ART_W * pixel_size


## Height on screen for [param pixel_size].
static func height_for(pixel_size: int) -> int:
	return ART_H * pixel_size


func _draw() -> void:
	for y in ART.size():
		var row := ART[y]
		for x in row.length():
			var c := row[x]
			if c != ".":
				draw_rect(Rect2(x * pixel, y * pixel, pixel, pixel), PALETTE[c])
