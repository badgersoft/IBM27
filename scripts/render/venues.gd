class_name Venues
extends RefCounted
## Data for the three fight venues.
##
## The ring is the SAME size in every venue (see ArenaRenderer for its
## geometry); only its finish changes. As the venue gets bigger the canvas gets
## cleaner, the ropes brighter and the apron smarter.
##
## Crowd rows are listed back to front:
##   seat_y  - arena pixel row the spectators sit on
##   count   - how many seats in the row
##   fill    - chance a seat is taken (0 - 1)
##   stand   - chance a spectator is standing
##   scale   - drawing size of the spectators in that row
##   dim     - how much the row is darkened (rows further back are darker)
##   x_range - left and right ends of the row in arena pixels

enum Id { SMALL_GYM, CITY_GYM, BOXING_HALL }

const LIST: Array = [
	{
		"name": "Small Town Gym",
		"short": "TOWN GYM",
		"canvas":       [Color("b4a68c"), Color("9a8c72"), Color("c8bca4")],  # base, shade, light
		"apron":        [Color("6a4a30"), Color("4c3220")],
		"apron_text":   "",
		"ropes":        [Color("c8c4b8"), Color("c8c4b8"), Color("c8c4b8")],
		"rope_tape":    Color("a03030"),
		"post":         [Color("4a4a50"), Color("2c2c30"), Color("6e6e76")],
		"pads":         [Color("a83434"), Color("3a5aa8"), Color("c8c4b8")],  # red, blue, neutral
		"crowd": [
			{"seat_y": 110, "count":  3, "fill": 1.00, "stand": 1.00, "scale": 1.00, "dim": 0.08, "x_range": [150, 290]},
			{"seat_y": 110, "count":  5, "fill": 0.90, "stand": 0.00, "scale": 1.00, "dim": 0.00, "x_range": [104, 324]},
		],
	},
	{
		"name": "City Gym",
		"short": "CITY GYM",
		"canvas":       [Color("c4c6cc"), Color("a8aab2"), Color("d8dade")],
		"apron":        [Color("243a6a"), Color("182850")],
		"apron_text":   "CITY BOXING CLUB",
		"ropes":        [Color("eeeeee"), Color("eeeeee"), Color("eeeeee")],
		"rope_tape":    Color("c03030"),
		"post":         [Color("8a8e96"), Color("5e626a"), Color("c4c8d0")],
		"pads":         [Color("c83030"), Color("3060c8"), Color("e8e8e8")],
		"crowd": [
			{"seat_y":  88, "count": 13, "fill": 0.75, "stand": 0.25, "scale": 0.86, "dim": 0.28, "x_range": [ 64, 360]},
			{"seat_y":  99, "count": 13, "fill": 0.70, "stand": 0.10, "scale": 0.93, "dim": 0.14, "x_range": [ 58, 366]},
			{"seat_y": 110, "count": 13, "fill": 0.80, "stand": 0.00, "scale": 1.00, "dim": 0.00, "x_range": [ 52, 372]},
		],
	},
	{
		"name": "Boxing Hall",
		"short": "BOXING HALL",
		"canvas":       [Color("3a64c8"), Color("2a4c9c"), Color("5a82e0")],
		"apron":        [Color("141a34"), Color("0c1022")],
		"apron_text":   "BADGER-SOFT   IBM 2027   BADGER-SOFT",
		"ropes":        [Color("e03434"), Color("f0f0f0"), Color("3460e0")],
		"rope_tape":    Color("f0f0f0"),
		"post":         [Color("b8bcc4"), Color("7c8088"), Color("eef0f4")],
		"pads":         [Color("d82c2c"), Color("2c5ce0"), Color("f4f4f4")],
		"crowd": [
			{"seat_y":  66, "count": 34, "fill": 0.85, "stand": 0.05, "scale": 0.76, "dim": 0.50, "x_range": [  6, 418]},
			{"seat_y":  77, "count": 33, "fill": 0.88, "stand": 0.05, "scale": 0.81, "dim": 0.40, "x_range": [  8, 416]},
			{"seat_y":  88, "count": 32, "fill": 0.90, "stand": 0.06, "scale": 0.87, "dim": 0.30, "x_range": [ 10, 414]},
			{"seat_y":  99, "count": 31, "fill": 0.92, "stand": 0.06, "scale": 0.93, "dim": 0.18, "x_range": [ 12, 412]},
			{"seat_y": 110, "count": 30, "fill": 0.95, "stand": 0.04, "scale": 1.00, "dim": 0.06, "x_range": [ 14, 410]},
		],
	},
]

## Clothing colours for spectators - deliberately muted so the boxers stand out.
const SHIRTS: Array = [
	Color("8a3a3a"), Color("3a5a8a"), Color("5a7a4a"), Color("8a7a4a"), Color("6a4a7a"),
	Color("9a9a90"), Color("4a4a50"), Color("a06a3a"), Color("3a6a6a"), Color("7a5a4a"),
	Color("b0a890"), Color("2e3a52"),
]


static func count() -> int:
	return LIST.size()


static func get_venue(id: int) -> Dictionary:
	return LIST[clampi(id, 0, LIST.size() - 1)]


static func venue_name(id: int) -> String:
	return get_venue(id)["name"]
