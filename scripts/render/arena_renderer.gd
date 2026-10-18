class_name ArenaRenderer
extends Node2D
## Draws a venue and the ring inside the low-resolution arena viewport.
##
## Layers, back to front (each is a child Node2D that this script draws into):
##   StaticBack  - walls, ceiling, lights. Drawn once.
##   Crowd       - spectators. Redrawn at CROWD_FPS so they can cheer.
##   RingBack    - canvas, back posts, back and side ropes.
##   Fighters    - the two BoxerRigs are added here by ArenaView.
##   RingFront   - semi-transparent front ropes, front posts, apron, floor.
##   Fx          - big-punch flashes, and the trainers' advice bubbles between
##                 rounds (the trainers themselves are off screen).
##
## The ring geometry below is shared by every venue, so the ring is always the
## same size; the venue only changes its colours and finish.

const SIZE := Vector2i(424, 168)

# --- Ring geometry (arena pixels) ---------------------------------------------------
const CANVAS_BACK_Y  := 118.0   ## Far edge of the canvas.
const CANVAS_FRONT_Y := 142.0   ## Near edge of the canvas (top of the apron).
const FIGHT_Y        := 132.0   ## Where the boxers' feet touch the canvas.
const APRON_BOTTOM_Y := 160.0
const POST_FRONT_X   := [28.0, 396.0]
const POST_BACK_X    := [50.0, 374.0]
const POST_FRONT_H   := 60.0
const POST_BACK_H    := 52.0
const ROPE_LEVELS    := [0.30, 0.60, 0.90]   ## Rope heights as a share of post height.
const CANVAS_OVERHANG := 8.0                 ## Canvas visible outside the ropes.

## Furthest left / right a boxer's centre may stand (the ropes at FIGHT_Y).
const RING_MIN_X := 58.0
const RING_MAX_X := 366.0
## Where each corner's boxer rests between rounds (0 = red, 1 = blue).
const CORNER_X := [60.0, 364.0]

const CROWD_FPS := 12.0
## Floor colour around the ring, per venue.
const FLOOR_COLOURS: Array[Color] = [Color("3a2818"), Color("2a2c34"), Color("08080c"), Color("050508")]
## Aisle positions (x) in the tiered venues.
const AISLES: Array[float] = [110.0, 314.0]
## Speech bubbles sit above the tallest boxer's head (which tops out near y 46).
const BUBBLE_TOP := 24.0
const BUBBLE_TAIL_Y := 50.0
const BUBBLE_EDGE := 8.0        ## Gap between a bubble and the screen edge.
const FRONT_ROPE_ALPHA := 0.45
const FLASH_SECONDS := 0.15     ## How long a big punch's impact flash shows.

const FONT := preload("res://assets/fonts/PressStart2P.woff2")
const FONT_SIZE := 8
const GLYPH_H := 7      ## Height of a capital letter at FONT_SIZE.
const GLYPH_DROP := 2   ## Gap between the bottom of a capital and the baseline.

## 0 - 1. Raise it when something exciting happens; it fades by itself.
var excitement := 0.0
var venue_id := 0
var fighter_layer: Node2D

var _venue: Dictionary = {}
var _announcing := false         # Verdict being read out (see set_announcing).
var _crowd: Array = []
var _rope_shake := [0.0, 0.0]
var _time := 0.0
var _flash_rng := RandomNumberGenerator.new()
var _crowd_clock := 0.0
var _advice_text := ["", ""]   # What each trainer is saying ("" = not shown).
var _advice_time := [0.0, 0.0]
var _flash_pos := Vector2.ZERO
var _flash_time := 0.0

var _static_back: Node2D
var _crowd_layer: Node2D
var _ring_back: Node2D
var _ring_front: Node2D
var _fx: Node2D


## Builds the layers for venue [param id] (see Venues.Id).
func setup(id: int) -> void:
	venue_id = clampi(id, 0, Venues.count() - 1)
	_venue = Venues.get_venue(venue_id)
	_build_crowd()

	_static_back = _make_layer("StaticBack", _draw_static_back)
	_crowd_layer = _make_layer("Crowd", _draw_crowd)
	_ring_back = _make_layer("RingBack", _draw_ring_back)
	fighter_layer = Node2D.new()
	fighter_layer.name = "Fighters"
	add_child(fighter_layer)
	_ring_front = _make_layer("RingFront", _draw_ring_front)
	_fx = _make_layer("Fx", _draw_fx)


## Wobbles the ropes on one side: 0 = left (red corner) side, 1 = right.
func shake_ropes(side: int, amount: float = 1.0) -> void:
	_rope_shake[side] = maxf(_rope_shake[side], amount)


## While the verdict is read out the announcement band covers the top of the
## venue, so anything that would peek out under it (the small gym's sign and
## clock, the hall's back banner, the arena's big screen) is taken down.
func set_announcing(on: bool) -> void:
	_announcing = on
	_static_back.queue_redraw()
	_crowd_layer.queue_redraw()
	_ring_front.queue_redraw()


## A white starburst where a big punch lands, gone after a few frames.
func impact_flash(at: Vector2) -> void:
	_flash_pos = at
	_flash_time = FLASH_SECONDS
	_fx.queue_redraw()


## Shows the trainer's advice for [param corner] in a speech bubble.
func show_corner_advice(corner: int, text: String, seconds: float) -> void:
	_advice_text[corner] = text
	_advice_time[corner] = seconds
	_fx.queue_redraw()


func hide_corner_advice() -> void:
	_advice_text = ["", ""]
	_advice_time = [0.0, 0.0]
	_fx.queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	excitement = maxf(excitement - delta * 0.25, 0.0)

	_crowd_clock += delta
	if _crowd_clock >= 1.0 / CROWD_FPS:
		_crowd_clock = 0.0
		_crowd_layer.queue_redraw()

	if _rope_shake[0] > 0.0 or _rope_shake[1] > 0.0:
		_rope_shake[0] = maxf(_rope_shake[0] - delta * 2.5, 0.0)
		_rope_shake[1] = maxf(_rope_shake[1] - delta * 2.5, 0.0)
		_ring_back.queue_redraw()
		_ring_front.queue_redraw()

	if _flash_time > 0.0:
		_flash_time -= delta
		_fx.queue_redraw()

	for corner in 2:
		if _advice_time[corner] > 0.0:
			_advice_time[corner] -= delta
			if _advice_time[corner] <= 0.0:
				_advice_text[corner] = ""
				_fx.queue_redraw()


func _make_layer(layer_name: String, draw_func: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	add_child(layer)
	layer.draw.connect(draw_func.bind(layer))
	return layer


# ============================================================================
#  Crowd
# ============================================================================

## Places every spectator once. A fixed seed per venue keeps the crowd the same
## each time you visit.
func _build_crowd() -> void:
	_crowd.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2027 + venue_id * 97
	for row in _venue["crowd"]:
		var x_from: float = row["x_range"][0]
		var x_to: float = row["x_range"][1]
		var n: int = row["count"]
		var spacing := (x_to - x_from) / maxf(n - 1, 1)
		for i in n:
			if rng.randf() > row["fill"]:
				continue
			var x := x_from + spacing * i + rng.randf_range(-1.5, 1.5)
			if _has_aisles() and _in_aisle(x, 7.0):
				continue   # Leave the aisles clear.
			_crowd.append({
				"pos": Vector2(roundf(x), row["seat_y"]),
				"scale": row["scale"] * rng.randf_range(0.92, 1.08),
				"dim": row["dim"],
				"stand": rng.randf() < row["stand"],
				"skin": Palette.SKIN_TONES[rng.randi_range(0, 4)][0],
				"hair": Palette.HAIR_TONES[rng.randi_range(1, 5)][0] if rng.randf() < 0.8 else Color(0, 0, 0, 0),
				"shirt": Venues.SHIRTS[rng.randi_range(0, Venues.SHIRTS.size() - 1)],
				"phase": rng.randf() * TAU,
				"cheer": rng.randf() < 0.55,
			})


func _draw_crowd(c: CanvasItem) -> void:
	match venue_id:
		Venues.Id.SMALL_GYM:
			_draw_bench(c, 110.0, 92.0, 340.0, Color("6a4a30"))
		Venues.Id.CITY_GYM:
			for row in _venue["crowd"]:
				_draw_bleacher(c, row["seat_y"], row["dim"])
		Venues.Id.BOXING_HALL:
			for row in _venue["crowd"]:
				_draw_tier(c, row["seat_y"], row["dim"])
		Venues.Id.GRAND_ARENA:
			for row in _venue["crowd"]:
				if row.get("upper", false):
					_draw_tier(c, row["seat_y"], row["dim"], 7.0, 4.0, 8.0)
				else:
					_draw_tier(c, row["seat_y"], row["dim"], 9.0, 6.0, 10.0)
	for s in _crowd:
		_draw_spectator(c, s)
	if venue_id == Venues.Id.BOXING_HALL or venue_id == Venues.Id.GRAND_ARENA:
		# Ringside barrier between the front row and the ring.
		c.draw_rect(Rect2(0, 112, SIZE.x, 6), Color("10101a"))
		c.draw_rect(Rect2(0, 112, SIZE.x, 1), Color("c8a020"))
	if venue_id == Venues.Id.GRAND_ARENA:
		_draw_balcony(c)
		_draw_camera_flashes(c)
		_draw_spotlight_beams(c)
		if not _announcing:
			_draw_big_screen(c)


## A very simple spectator: legs (if standing), shirt, head, hair, and arms
## thrown up in the air when the crowd gets excited.
func _draw_spectator(c: CanvasItem, s: Dictionary) -> void:
	var k: float = s["scale"]
	var dim: float = s["dim"]
	var x: float = s["pos"].x
	var base: float = s["pos"].y
	var cheering: bool = s["cheer"] and excitement > 0.35
	var bob := 0.0
	if excitement > 0.2:
		bob = -roundf(absf(sin(_time * 9.0 + s["phase"])) * 2.0 * excitement * k)

	var torso_w := roundf(8.0 * k)
	var torso_h := roundf(10.0 * k)
	var top := base - torso_h + bob
	if s["stand"]:
		top -= roundf(11.0 * k)
		var legs := Rect2(x - torso_w * 0.4, top + torso_h, torso_w * 0.8, base - (top + torso_h))
		c.draw_rect(legs, Palette.darken(Color("2a2a34"), dim))
	var shirt: Color = Palette.darken(s["shirt"], dim)
	var skin: Color = Palette.darken(s["skin"], dim)
	c.draw_rect(Rect2(x - torso_w * 0.5, top, torso_w, torso_h), shirt)
	c.draw_rect(Rect2(x - torso_w * 0.5, top, torso_w, 1), shirt.lightened(0.15))

	var head := Vector2(x, top - 3.0 * k)
	var r := maxf(3.0 * k, 1.5)
	var hair: Color = s["hair"]
	if hair.a > 0.0:
		c.draw_circle(head + Vector2(0, -0.8 * k), r, Palette.darken(hair, dim))
		c.draw_circle(head + Vector2(0, 0.5 * k), r * 0.9, skin)
	else:
		c.draw_circle(head, r, skin)
	if k >= 1.2:
		# Close enough to see a neck and a pair of eyes watching the ring.
		c.draw_rect(Rect2(x - k, top - 1.0, 2.0 * k, 1.0), skin.darkened(0.2))
		var eye_y := roundf(head.y + 0.6 * k)
		c.draw_rect(Rect2(roundf(x - 1.5 * k), eye_y, 1, 1), Palette.darken(Palette.EYE, 0.0))
		c.draw_rect(Rect2(roundf(x + 1.0 * k), eye_y, 1, 1), Palette.darken(Palette.EYE, 0.0))

	if cheering:
		var lift := 1.0 + absf(sin(_time * 7.0 + s["phase"])) * 2.0
		for side in [-1.0, 1.0]:
			var shoulder := Vector2(x + side * torso_w * 0.45, top + 1.0)
			var hand := shoulder + Vector2(side * 2.0 * k, -(5.0 + lift) * k)
			c.draw_line(shoulder, hand, shirt, maxf(2.0 * k, 1.0))
			c.draw_circle(hand, maxf(1.2 * k, 1.0), skin)


func _draw_bench(c: CanvasItem, y: float, x_from: float, x_to: float, wood: Color) -> void:
	c.draw_rect(Rect2(x_from, y, x_to - x_from, 3), wood)
	c.draw_rect(Rect2(x_from, y, x_to - x_from, 1), wood.lightened(0.2))
	for leg_x in [x_from + 4.0, (x_from + x_to) * 0.5, x_to - 6.0]:
		c.draw_rect(Rect2(leg_x, y + 3, 2, 6), wood.darkened(0.3))


## Wooden bleacher step for the City Gym.
func _draw_bleacher(c: CanvasItem, y: float, dim: float) -> void:
	var wood := Palette.darken(Color("8a6440"), dim)
	c.draw_rect(Rect2(40, y + 1, 344, 10), Palette.darken(Color("3a3440"), dim))
	c.draw_rect(Rect2(40, y, 344, 3), wood)
	c.draw_rect(Rect2(40, y, 344, 1), wood.lightened(0.2))


## Seating tier: a dark riser with red seat backs and aisle steps.
## Rows further away use a lower riser and smaller, closer-packed seats.
func _draw_tier(c: CanvasItem, y: float, dim: float, riser: float = 11.0,
		seat_w: float = 7.0, seat_step: float = 12.0) -> void:
	c.draw_rect(Rect2(0, y, SIZE.x, riser), Palette.darken(Color("221c30"), dim))
	c.draw_rect(Rect2(0, y, SIZE.x, 1), Palette.darken(Color("3a3048"), dim))
	var seat := Palette.darken(Color("8a2230"), dim)
	var seat_h := roundf(seat_w * 0.85)
	var x := 4.0
	while x < SIZE.x:
		if not _in_aisle(x, 7.0):
			c.draw_rect(Rect2(x, y - seat_h, seat_w, seat_h), seat)
		x += seat_step
	for aisle_x in AISLES:
		c.draw_rect(Rect2(aisle_x - 5, y - seat_h, 10, riser + seat_h), Palette.darken(Color("2e2638"), dim))
		c.draw_rect(Rect2(aisle_x - 5, y + riser * 0.4, 10, 1), Palette.darken(Color("4a4058"), dim))


func _has_aisles() -> bool:
	return venue_id == Venues.Id.BOXING_HALL or venue_id == Venues.Id.GRAND_ARENA


func _in_aisle(x: float, half_width: float) -> bool:
	for aisle_x in AISLES:
		if absf(x - aisle_x) < half_width:
			return true
	return false


## Grand Arena: the front of the upper tier, with a glowing LED strip.
func _draw_balcony(c: CanvasItem) -> void:
	c.draw_rect(Rect2(0, 46, SIZE.x, 9), Color("0c0c12"))
	c.draw_rect(Rect2(0, 47, SIZE.x, 1), Color("3a3a48"))
	var glow := 0.75 + 0.25 * sin(_time * 2.0)
	c.draw_rect(Rect2(0, 49, SIZE.x, 3), Color(0.88, 0.70, 0.24, glow))
	c.draw_rect(Rect2(0, 54, SIZE.x, 1), Color("1c1c26"))


## Grand Arena: a few photographers' flashes popping in the crowd. More
## flashes when the crowd is excited.
func _draw_camera_flashes(c: CanvasItem) -> void:
	var count := 2 + int(excitement * 10.0)
	for i in count:
		if _flash_rng.randf() > 0.55:
			continue
		var s: Dictionary = _crowd[_flash_rng.randi_range(0, _crowd.size() - 1)]
		var p: Vector2 = s["pos"] + Vector2(0, -14.0 * s["scale"])
		c.draw_circle(p, 2.5, Color(1, 1, 1, 0.25))
		c.draw_rect(Rect2(p.round() - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.95))


## Grand Arena: haze beams from the roof lamps down onto the ring.
func _draw_spotlight_beams(c: CanvasItem) -> void:
	var targets := [150.0, 212.0, 274.0, 212.0]
	var lamps := [40.0, 130.0, 294.0, 384.0]
	for i in lamps.size():
		var lx: float = lamps[i]
		var tx: float = targets[i]
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(lx - 2, 14), Vector2(lx + 2, 14),
			Vector2(tx + 34, CANVAS_BACK_Y), Vector2(tx - 34, CANVAS_BACK_Y),
		]), Color(1, 0.97, 0.85, 0.045))


## Grand Arena: the screen hanging over the ring, showing the two corners.
func _draw_big_screen(c: CanvasItem) -> void:
	var screen := Rect2(176, 6, 72, 26)
	for cable_x in [screen.position.x + 8, screen.end.x - 8]:
		c.draw_line(Vector2(cable_x, 0), Vector2(cable_x, screen.position.y), Color("3a3a44"), 1.0)
	c.draw_rect(screen.grow(2), Color("1a1a22"))
	c.draw_rect(screen.grow(1), Color("44444e"))
	var half := screen.size.x / 2.0
	c.draw_rect(Rect2(screen.position, Vector2(half, screen.size.y)), Color("8c1a1e"))
	c.draw_rect(Rect2(screen.position + Vector2(half, 0), Vector2(half, screen.size.y)), Color("1a3a8c"))
	_text_in(c, "VS", Rect2(screen.position.x, screen.position.y + 2, screen.size.x, 21), Color("f4f4f4"))
	# Scan lines give it a screen-like sheen.
	for y in range(int(screen.position.y) + 1, int(screen.end.y), 3):
		c.draw_rect(Rect2(screen.position.x, y, screen.size.x, 1), Color(0, 0, 0, 0.18))


# ============================================================================
#  Static background (walls, ceilings, lights)
# ============================================================================

func _draw_static_back(c: CanvasItem) -> void:
	match venue_id:
		Venues.Id.SMALL_GYM:
			_draw_small_gym_walls(c)
		Venues.Id.CITY_GYM:
			_draw_city_gym_walls(c)
		Venues.Id.BOXING_HALL:
			_draw_hall_walls(c)
		Venues.Id.GRAND_ARENA:
			_draw_arena_roof(c)
	# Floor either side of the ring, under the canvas line.
	var floor_colour: Color = FLOOR_COLOURS[venue_id]
	c.draw_rect(Rect2(0, CANVAS_BACK_Y, SIZE.x, SIZE.y - CANVAS_BACK_Y), floor_colour)


func _draw_small_gym_walls(c: CanvasItem) -> void:
	# Brick wall with a little variation so it does not look like wallpaper.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	c.draw_rect(Rect2(0, 0, SIZE.x, 120), Color("4e3026"))
	var brick_w := 12
	var brick_h := 5
	for row in range(0, 24):
		var y := 8 + row * (brick_h + 1)
		var offset := 0 if row % 2 == 0 else brick_w / 2
		for col in range(-1, SIZE.x / (brick_w + 1) + 1):
			var x := col * (brick_w + 1) + offset
			var tone := Color("7a4a38").darkened(rng.randf_range(0.0, 0.18))
			c.draw_rect(Rect2(x, y, brick_w, brick_h), tone)
			c.draw_rect(Rect2(x, y, brick_w, 1), tone.lightened(0.08))

	# Ceiling joists and a single fluorescent strip light.
	c.draw_rect(Rect2(0, 0, SIZE.x, 8), Color("2e2018"))
	for x in range(6, SIZE.x, 40):
		c.draw_rect(Rect2(x, 0, 6, 8), Color("3e2c20"))
	c.draw_rect(Rect2(170, 7, 84, 4), Color("3a3a3a"))
	c.draw_rect(Rect2(172, 8, 80, 2), Color("f4f4e4"))
	c.draw_colored_polygon(PackedVector2Array([
		Vector2(172, 10), Vector2(252, 10), Vector2(300, 60), Vector2(124, 60)
	]), Color(1, 1, 0.9, 0.05))

	# Window with dirty glass.
	c.draw_rect(Rect2(326, 20, 46, 38), Color("2a2420"))
	c.draw_rect(Rect2(329, 23, 40, 32), Color("62788a"))
	c.draw_rect(Rect2(348, 23, 2, 32), Color("2a2420"))
	c.draw_rect(Rect2(329, 38, 40, 2), Color("2a2420"))
	c.draw_line(Vector2(332, 34), Vector2(342, 25), Color("8aa0b0"), 1.0)
	c.draw_line(Vector2(353, 52), Vector2(365, 42), Color("8aa0b0"), 1.0)

	# "No smoking" sign - a nod to the classic gym backdrop - and the wall
	# clock. Both straddle the bottom of the announcement band, so they come
	# down while the verdict is read.
	if not _announcing:
		c.draw_rect(Rect2(96, 17, 88, 15), Color("2a2420"))
		c.draw_rect(Rect2(97, 18, 86, 13), Color("e8e4d8"))
		_text_in(c, "NO SMOKING", Rect2(97, 18, 86, 13), Color("a02020"))
		c.draw_circle(Vector2(262, 26), 7.0, Color("2a2420"))
		c.draw_circle(Vector2(262, 26), 6.0, Color("e8e4d8"))
		c.draw_line(Vector2(262, 26), Vector2(262, 22), Color("202020"), 1.0)
		c.draw_line(Vector2(262, 26), Vector2(265, 27), Color("202020"), 1.0)

	# Heavy bag hanging outside the ring on the left.
	c.draw_line(Vector2(14, 8), Vector2(14, 22), Color("8a8a8a"), 1.0)
	c.draw_rect(Rect2(7, 22, 15, 44), Color("1a1010"))
	c.draw_rect(Rect2(8, 23, 13, 42), Color("7a2a22"))
	c.draw_rect(Rect2(9, 24, 3, 40), Color("9a3e32"))
	c.draw_rect(Rect2(8, 30, 13, 2), Color("4a1a14"))
	c.draw_rect(Rect2(8, 56, 13, 2), Color("4a1a14"))

	# Speed-bag platform on the right.
	c.draw_rect(Rect2(400, 38, 22, 4), Color("4e3424"))
	c.draw_circle(Vector2(411, 47), 4.0, Color("1a1010"))
	c.draw_circle(Vector2(411, 47), 3.0, Color("a83a2a"))

	# Bare wooden floor behind the ring.
	c.draw_rect(Rect2(0, 104, SIZE.x, 16), Color("4a3424"))
	for x in range(0, SIZE.x, 18):
		c.draw_rect(Rect2(x, 104, 1, 16), Color("3a2818"))


func _draw_city_gym_walls(c: CanvasItem) -> void:
	# Painted breeze-block wall.
	c.draw_rect(Rect2(0, 0, SIZE.x, 120), Color("4a5470"))
	for row in range(0, 15):
		var y := row * 8
		var offset := 0 if row % 2 == 0 else 8
		c.draw_rect(Rect2(0, y, SIZE.x, 1), Color("3c445c"))
		for x in range(-offset, SIZE.x, 16):
			c.draw_rect(Rect2(x, y, 1, 8), Color("3c445c"))

	# High windows letting in daylight.
	for wx in [24.0, 72.0, 328.0, 376.0]:
		c.draw_rect(Rect2(wx, 24, 26, 18), Color("2a2e3a"))
		c.draw_rect(Rect2(wx + 2, 26, 22, 14), Color("9ab8d0"))
		c.draw_rect(Rect2(wx + 12, 26, 2, 14), Color("2a2e3a"))
		c.draw_line(Vector2(wx + 4, 36), Vector2(wx + 10, 29), Color("c8dcec"), 1.0)

	# Club banner.
	c.draw_rect(Rect2(140, 8, 144, 18), Color("6a1418"))
	c.draw_rect(Rect2(141, 9, 142, 16), Color("b02028"))
	c.draw_rect(Rect2(141, 9, 142, 1), Color("d04048"))
	_text_in(c, "CITY GYM", Rect2(141, 10, 142, 15), Color("f4ecd8"))

	# Two hanging lamps with soft light cones.
	for lx in [120.0, 304.0]:
		c.draw_line(Vector2(lx, 0), Vector2(lx, 26), Color("202024"), 1.0)
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(lx - 3, 26), Vector2(lx + 3, 26), Vector2(lx + 7, 32), Vector2(lx - 7, 32)
		]), Color("2c3038"))
		c.draw_rect(Rect2(lx - 5, 32, 10, 1), Color("fff4c8"))
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(lx - 6, 33), Vector2(lx + 6, 33), Vector2(lx + 40, 118), Vector2(lx - 40, 118)
		]), Color(1, 0.95, 0.8, 0.05))


## Grand Arena: a huge dark roof with two rows of lighting truss.
func _draw_arena_roof(c: CanvasItem) -> void:
	var bands := [Color("060609"), Color("09090e"), Color("0c0c13"), Color("101018")]
	for i in bands.size():
		c.draw_rect(Rect2(0, i * 6, SIZE.x, 6), bands[i])
	c.draw_rect(Rect2(0, 24, SIZE.x, 96), Color("12121c"))
	for rail_y in [3.0, 9.0]:
		c.draw_rect(Rect2(0, rail_y, SIZE.x, 1), Color("3a3a48"))
	for x in range(0, SIZE.x, 6):
		c.draw_line(Vector2(x, 4), Vector2(x + 3, 9), Color("26262f"), 1.0)
		c.draw_line(Vector2(x + 3, 9), Vector2(x + 6, 4), Color("26262f"), 1.0)
	for lx in [40.0, 85.0, 130.0, 294.0, 339.0, 384.0]:
		c.draw_rect(Rect2(lx - 3, 10, 6, 4), Color("22222a"))
		c.draw_rect(Rect2(lx - 2, 13, 4, 1), Color("fff6d8"))
		c.draw_circle(Vector2(lx, 14), 4.0, Color(1, 0.95, 0.8, 0.10))


func _draw_hall_walls(c: CanvasItem) -> void:
	# Dark hall fading up into the roof.
	var bands := [Color("0b0a12"), Color("0e0c17"), Color("120f1d"), Color("161324"), Color("1a172a")]
	for i in bands.size():
		c.draw_rect(Rect2(0, i * 14, SIZE.x, 14), bands[i])
	c.draw_rect(Rect2(0, 70, SIZE.x, 50), Color("1a172a"))

	# Lighting truss: two rails joined by a zig-zag lattice.
	c.draw_rect(Rect2(0, 6, SIZE.x, 1), Color("4a4a5a"))
	c.draw_rect(Rect2(0, 12, SIZE.x, 1), Color("4a4a5a"))
	for x in range(0, SIZE.x, 8):
		c.draw_line(Vector2(x, 7), Vector2(x + 4, 12), Color("34343f"), 1.0)
		c.draw_line(Vector2(x + 4, 12), Vector2(x + 8, 7), Color("34343f"), 1.0)

	# Spot lamps hanging from the truss.
	for lx in [52.0, 132.0, 212.0, 292.0, 372.0]:
		c.draw_rect(Rect2(lx - 4, 13, 8, 6), Color("26262e"))
		c.draw_rect(Rect2(lx - 3, 18, 6, 2), Color("fff6d0"))
		c.draw_circle(Vector2(lx, 19), 5.0, Color(1, 0.95, 0.75, 0.12))

	# A huge banner high up at the back, left blank for now.
	if _announcing:
		return
	c.draw_rect(Rect2(124, 26, 176, 19), Color("0c0c14"))
	c.draw_rect(Rect2(125, 27, 174, 17), Color("1c2a5a"))
	c.draw_rect(Rect2(125, 27, 174, 1), Color("c8a020"))
	c.draw_rect(Rect2(125, 43, 174, 1), Color("c8a020"))


# ============================================================================
#  Ring - back half (behind the boxers)
# ============================================================================

func _draw_ring_back(c: CanvasItem) -> void:
	_draw_canvas(c)
	for side in 2:
		_draw_post(c, POST_BACK_X[side], CANVAS_BACK_Y, POST_BACK_H, 3.0, _venue["pads"][2])
	# Back ropes run between the two back posts; side ropes join back to front.
	for i in ROPE_LEVELS.size():
		var level: float = ROPE_LEVELS[i]
		var colour: Color = _venue["ropes"][i]
		var back_l := Vector2(POST_BACK_X[0], CANVAS_BACK_Y - POST_BACK_H * level)
		var back_r := Vector2(POST_BACK_X[1], CANVAS_BACK_Y - POST_BACK_H * level)
		var front_l := Vector2(POST_FRONT_X[0], CANVAS_FRONT_Y - POST_FRONT_H * level)
		var front_r := Vector2(POST_FRONT_X[1], CANVAS_FRONT_Y - POST_FRONT_H * level)
		_draw_rope(c, back_l, back_r, colour, 1.0, 1.0, true)
		_draw_rope(c, back_l, front_l, colour, 1.0, 1.0, false, 0)
		_draw_rope(c, back_r, front_r, colour, 1.0, 1.0, false, 1)
	# Rope ties holding the back ropes together.
	var tie: Color = _venue["rope_tape"]
	for tx in [131.0, 212.0, 293.0]:
		var top := CANVAS_BACK_Y - POST_BACK_H * ROPE_LEVELS[-1]
		c.draw_line(Vector2(tx, top), Vector2(tx, CANVAS_BACK_Y - POST_BACK_H * ROPE_LEVELS[0]), Color(tie, 0.8), 1.0)


func _draw_canvas(c: CanvasItem) -> void:
	var tones: Array = _venue["canvas"]
	var back_l := Vector2(POST_BACK_X[0] - CANVAS_OVERHANG * 0.7, CANVAS_BACK_Y)
	var back_r := Vector2(POST_BACK_X[1] + CANVAS_OVERHANG * 0.7, CANVAS_BACK_Y)
	var front_r := Vector2(POST_FRONT_X[1] + CANVAS_OVERHANG, CANVAS_FRONT_Y)
	var front_l := Vector2(POST_FRONT_X[0] - CANVAS_OVERHANG, CANVAS_FRONT_Y)
	c.draw_colored_polygon(PackedVector2Array([back_l, back_r, front_r, front_l]), tones[0])
	# Darker strip at the far edge and a lit lip at the near edge.
	c.draw_colored_polygon(PackedVector2Array([
		back_l, back_r, back_r + Vector2(-1, 3), back_l + Vector2(1, 3)
	]), tones[1])
	c.draw_line(front_l + Vector2(0, -1), front_r + Vector2(0, -1), tones[2], 1.0)

	match venue_id:
		Venues.Id.SMALL_GYM:
			# Old stains and a taped repair.
			var stain := Color(tones[1], 0.7)
			_ellipse(c, Vector2(120, 128), 14, 3, stain)
			_ellipse(c, Vector2(292, 136), 10, 2, stain)
			_ellipse(c, Vector2(205, 124), 6, 1.5, stain)
			c.draw_rect(Rect2(250, 125, 9, 2), Color("8c8a80"))
		Venues.Id.CITY_GYM:
			_ellipse(c, Vector2(160, 133), 10, 2, Color(tones[1], 0.4))
		Venues.Id.BOXING_HALL:
			# Centre-ring logo.
			_ellipse(c, Vector2(212, 130), 44, 7, tones[2])
			_ellipse(c, Vector2(212, 130), 41, 6, tones[0])
			_ellipse(c, Vector2(212, 130), 30, 4, Color(tones[2], 0.5))
		Venues.Id.GRAND_ARENA:
			# Big gold centre-ring logo on the bright white canvas.
			_ellipse(c, Vector2(212, 130), 52, 8, Color("c8a020"))
			_ellipse(c, Vector2(212, 130), 49, 7, tones[0])
			_ellipse(c, Vector2(212, 130), 36, 5, Color("e0b43c", 0.55))
			_ellipse(c, Vector2(212, 130), 33, 4, tones[0])


# ============================================================================
#  Ring - front half (in front of the boxers)
# ============================================================================

func _draw_ring_front(c: CanvasItem) -> void:
	# Front ropes are see-through so the boxers stay visible behind them.
	for i in ROPE_LEVELS.size():
		var level: float = ROPE_LEVELS[i]
		var colour: Color = _venue["ropes"][i]
		colour.a = FRONT_ROPE_ALPHA
		var a := Vector2(POST_FRONT_X[0], CANVAS_FRONT_Y - POST_FRONT_H * level)
		var b := Vector2(POST_FRONT_X[1], CANVAS_FRONT_Y - POST_FRONT_H * level)
		_draw_rope(c, a, b, colour, 2.0, FRONT_ROPE_ALPHA, true)

	_draw_post(c, POST_FRONT_X[0], CANVAS_FRONT_Y, POST_FRONT_H, 4.0, _venue["pads"][0])
	_draw_post(c, POST_FRONT_X[1], CANVAS_FRONT_Y, POST_FRONT_H, 4.0, _venue["pads"][1])
	_draw_apron(c)


func _draw_apron(c: CanvasItem) -> void:
	var tones: Array = _venue["apron"]
	var left := POST_FRONT_X[0] - CANVAS_OVERHANG
	var right := POST_FRONT_X[1] + CANVAS_OVERHANG
	var rect := Rect2(left, CANVAS_FRONT_Y, right - left, APRON_BOTTOM_Y - CANVAS_FRONT_Y)
	c.draw_rect(rect, tones[0])
	c.draw_rect(Rect2(left, CANVAS_FRONT_Y, rect.size.x, 2), tones[1])

	match venue_id:
		Venues.Id.SMALL_GYM:
			# Bare wooden boards.
			for x in range(int(left) + 9, int(right), 10):
				c.draw_rect(Rect2(x, CANVAS_FRONT_Y + 2, 1, rect.size.y - 2), tones[1])
			c.draw_rect(Rect2(left, APRON_BOTTOM_Y - 2, rect.size.x, 2), tones[1])
		Venues.Id.CITY_GYM:
			# Plain cloth under a white trim.
			c.draw_rect(Rect2(left, CANVAS_FRONT_Y + 2, rect.size.x, 1), Color("f0f0f0"))
		Venues.Id.BOXING_HALL, Venues.Id.GRAND_ARENA:
			# Gold trim top and bottom, and faint skirt folds between them.
			var top_trim := CANVAS_FRONT_Y + 2
			var bottom_trim := APRON_BOTTOM_Y - 2
			c.draw_rect(Rect2(left, top_trim, rect.size.x, 1), Color("c8a020"))
			c.draw_rect(Rect2(left, bottom_trim, rect.size.x, 1), Color("c8a020"))
			var fold: Color = (tones[0] as Color).lightened(0.06)
			for x in range(int(left) + 12, int(right) - 4, 24):
				c.draw_rect(Rect2(x, top_trim + 2, 1, bottom_trim - top_trim - 3), fold)

	# Floor in front of the ring.
	var floor_colour: Color = FLOOR_COLOURS[venue_id]
	c.draw_rect(Rect2(0, APRON_BOTTOM_Y, SIZE.x, SIZE.y - APRON_BOTTOM_Y), floor_colour)
	c.draw_rect(Rect2(left, APRON_BOTTOM_Y, rect.size.x, 1), Color(0, 0, 0, 0.5))


# ============================================================================
#  Corner man and speech bubble (between rounds)
# ============================================================================

func _draw_fx(c: CanvasItem) -> void:
	if _flash_time > 0.0:
		_draw_impact(c, _flash_pos, _flash_time / FLASH_SECONDS)
	for corner in 2:
		if _advice_text[corner].is_empty():
			continue
		# The trainer is off screen by his corner post; his bubble's tail
		# points down towards him.
		var dir := 1.0 if corner == 0 else -1.0
		var x := BUBBLE_EDGE if corner == 0 else SIZE.x - BUBBLE_EDGE
		_draw_bubble(c, _advice_text[corner], Vector2(x, BUBBLE_TAIL_Y), dir)


## An eight-point star: long spikes up, down and sideways, short diagonals,
## with a hot centre. [param life] runs from 1 down to 0 and shrinks it.
func _draw_impact(c: CanvasItem, at: Vector2, life: float) -> void:
	var size := 5.0 + 6.0 * life
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		var r := size if i % 4 == 0 else (size * 0.6 if i % 2 == 0 else size * 0.25)
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(pts, Color(1.0, 0.92, 0.55, 0.9))
	c.draw_circle(at, size * 0.3, Color.WHITE)


## A speech bubble starting at [param anchor].x and growing in direction
## [param dir], with its tail pointing down to [param anchor].
func _draw_bubble(c: CanvasItem, text: String, anchor: Vector2, dir: float) -> void:
	var width := text.length() * FONT_SIZE + 10.0
	var height := 15.0
	var left := anchor.x if dir > 0 else anchor.x - width
	var rect := Rect2(left, BUBBLE_TOP, width, height)
	var tail := PackedVector2Array([
		Vector2(anchor.x + dir * 8.0, rect.end.y - 1), Vector2(anchor.x + dir * 16.0, rect.end.y - 1),
		Vector2(anchor.x + dir * 4.0, anchor.y),
	])
	c.draw_rect(rect.grow(1), Palette.OUTLINE)
	c.draw_colored_polygon(tail, Palette.OUTLINE)
	c.draw_rect(rect, Color("f8f6ee"))
	var inner := PackedVector2Array([tail[0] + Vector2(dir, -1), tail[1] + Vector2(-dir, -1), tail[2] + Vector2(0, -2)])
	c.draw_colored_polygon(inner, Color("f8f6ee"))
	_text_in(c, text, rect, Color("101010"))


# ============================================================================
#  Shared drawing helpers
# ============================================================================

## A post with a padded turnbuckle cover over the ropes.
func _draw_post(c: CanvasItem, x: float, base_y: float, height: float, width: float, pad: Color) -> void:
	var tones: Array = _venue["post"]
	var rect := Rect2(x - width * 0.5, base_y - height - 2.0, width, height + 2.0)
	c.draw_rect(rect.grow(1), Palette.OUTLINE)
	c.draw_rect(rect, tones[0])
	c.draw_rect(Rect2(rect.position, Vector2(1, rect.size.y)), tones[2])
	c.draw_rect(Rect2(rect.end.x - 1, rect.position.y, 1, rect.size.y), tones[1])
	# Corner pad from just above the top rope to just below the bottom rope.
	var pad_top := base_y - height * ROPE_LEVELS[-1] - 4.0
	var pad_bottom := base_y - height * ROPE_LEVELS[0] + 4.0
	var pad_rect := Rect2(x - width * 0.5 - 1.0, pad_top, width + 2.0, pad_bottom - pad_top)
	c.draw_rect(pad_rect.grow(1), Palette.OUTLINE)
	c.draw_rect(pad_rect, pad)
	c.draw_rect(Rect2(pad_rect.position, Vector2(1, pad_rect.size.y)), pad.lightened(0.3))
	c.draw_rect(Rect2(pad_rect.end.x - 1, pad_rect.position.y, 1, pad_rect.size.y), pad.darkened(0.3))


## Draws a rope as a short polyline so it can wobble when a boxer hits it.
## [param side] = 0 or 1 makes the whole rope shake with that side; -1 means
## the shake fades out towards the middle (back and front ropes).
func _draw_rope(c: CanvasItem, a: Vector2, b: Vector2, colour: Color, width: float,
		_alpha: float, spans_ring: bool, side: int = -1) -> void:
	var points := PackedVector2Array()
	var segments := 12
	for i in segments + 1:
		var t := float(i) / segments
		var shake := 0.0
		if spans_ring:
			shake = _rope_shake[0] * maxf(0.0, 1.0 - t * 2.2) + _rope_shake[1] * maxf(0.0, 1.0 - (1.0 - t) * 2.2)
		elif side >= 0:
			shake = _rope_shake[side]
		var sag := sin(t * PI) * 0.6
		var wobble := shake * sin(_time * 38.0 + t * 3.0) * 2.0
		points.append(a.lerp(b, t) + Vector2(0, sag + wobble))
	c.draw_polyline(points, colour.darkened(0.35), width + 1.0)
	c.draw_polyline(points, colour, width)


## Draws [param text] centred both ways inside [param area].
##
## At 8 px the pixel font's capitals are GLYPH_H (7) pixels tall and sit
## GLYPH_DROP (2) pixels above the baseline, so the baseline is placed to give
## equal space above and below them. Give text areas an odd height (7 + 2n)
## and the gaps come out exactly equal.
func _text_in(c: CanvasItem, text: String, area: Rect2, colour: Color) -> void:
	var gap := floorf((area.size.y - GLYPH_H) / 2.0)
	var baseline := area.position.y + gap + GLYPH_H + GLYPH_DROP - 1.0
	c.draw_string(FONT, Vector2(area.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, area.size.x, FONT_SIZE, colour)


func _ellipse(c: CanvasItem, centre: Vector2, rx: float, ry: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, colour)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
