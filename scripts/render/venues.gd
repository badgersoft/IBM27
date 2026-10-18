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
##   scale   - drawing size of the spectators in that row. The gyms are small
##             rooms, so their few spectators sit close and look bigger; in
##             the hall the crowd is further back and smaller.
##   dim     - how much the row is darkened (rows further back are darker)
##   x_range - left and right ends of the row in arena pixels

enum Id { SMALL_GYM, CITY_GYM, BOXING_HALL, GRAND_ARENA }

const LIST: Array = [
	{
		"name": "Small Town Gym",
		"short": "TOWN GYM",
		"canvas":       [Color("b4a68c"), Color("9a8c72"), Color("c8bca4")],  # base, shade, light
		"apron":        [Color("6a4a30"), Color("4c3220")],
		"ropes":        [Color("c8c4b8"), Color("c8c4b8"), Color("c8c4b8")],
		"rope_tape":    Color("a03030"),
		"post":         [Color("4a4a50"), Color("2c2c30"), Color("6e6e76")],
		"pads":         [Color("a83434"), Color("3a5aa8"), Color("c8c4b8")],  # red, blue, neutral
		"crowd": [
			{"seat_y": 110, "count":  3, "fill": 1.00, "stand": 1.00, "scale": 1.70, "dim": 0.08, "x_range": [148, 292]},
			{"seat_y": 110, "count":  5, "fill": 0.90, "stand": 0.00, "scale": 1.75, "dim": 0.00, "x_range": [108, 320]},
		],
	},
	{
		"name": "City Gym",
		"short": "CITY GYM",
		"canvas":       [Color("c4c6cc"), Color("a8aab2"), Color("d8dade")],
		"apron":        [Color("243a6a"), Color("182850")],
		"ropes":        [Color("eeeeee"), Color("eeeeee"), Color("eeeeee")],
		"rope_tape":    Color("c03030"),
		"post":         [Color("8a8e96"), Color("5e626a"), Color("c4c8d0")],
		"pads":         [Color("c83030"), Color("3060c8"), Color("e8e8e8")],
		"crowd": [
			{"seat_y":  84, "count": 10, "fill": 0.75, "stand": 0.20, "scale": 1.20, "dim": 0.24, "x_range": [ 70, 354]},
			{"seat_y":  97, "count": 10, "fill": 0.70, "stand": 0.10, "scale": 1.32, "dim": 0.12, "x_range": [ 62, 362]},
			{"seat_y": 110, "count":  9, "fill": 0.80, "stand": 0.00, "scale": 1.45, "dim": 0.00, "x_range": [ 56, 368]},
		],
	},
	{
		"name": "Boxing Hall",
		"short": "BOXING HALL",
		"canvas":       [Color("3a64c8"), Color("2a4c9c"), Color("5a82e0")],
		"apron":        [Color("141a34"), Color("0c1022")],
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
	{
		# The big one: an upper balcony above a six-row lower bowl, a screen
		# hanging over the ring, spotlights and camera flashes.
		"name": "Grand Arena",
		"short": "GRAND ARENA",
		"canvas":       [Color("dfe2ec"), Color("b8bccc"), Color("f4f6fa")],
		"apron":        [Color("0c0c10"), Color("060608")],
		"ropes":        [Color("e0b43c"), Color("f4f4f4"), Color("e0b43c")],
		"rope_tape":    Color("e0b43c"),
		"post":         [Color("2a2a30"), Color("141418"), Color("5a5a64")],
		"pads":         [Color("d82c2c"), Color("2c5ce0"), Color("1c1c22")],
		"crowd": [
			{"seat_y":  25, "count": 46, "fill": 0.90, "stand": 0.04, "scale": 0.50, "dim": 0.60, "x_range": [  4, 420], "upper": true},
			{"seat_y":  32, "count": 45, "fill": 0.92, "stand": 0.04, "scale": 0.53, "dim": 0.56, "x_range": [  5, 419], "upper": true},
			{"seat_y":  39, "count": 44, "fill": 0.94, "stand": 0.04, "scale": 0.56, "dim": 0.52, "x_range": [  6, 418], "upper": true},
			{"seat_y":  62, "count": 40, "fill": 0.92, "stand": 0.05, "scale": 0.62, "dim": 0.46, "x_range": [  6, 418]},
			{"seat_y":  71, "count": 38, "fill": 0.93, "stand": 0.05, "scale": 0.68, "dim": 0.38, "x_range": [  7, 417]},
			{"seat_y":  80, "count": 37, "fill": 0.94, "stand": 0.06, "scale": 0.74, "dim": 0.30, "x_range": [  8, 416]},
			{"seat_y":  89, "count": 35, "fill": 0.95, "stand": 0.06, "scale": 0.80, "dim": 0.22, "x_range": [  9, 415]},
			{"seat_y":  98, "count": 34, "fill": 0.96, "stand": 0.06, "scale": 0.86, "dim": 0.14, "x_range": [ 10, 414]},
			{"seat_y": 107, "count": 32, "fill": 0.97, "stand": 0.05, "scale": 0.92, "dim": 0.06, "x_range": [ 12, 412]},
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
