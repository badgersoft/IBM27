class_name FrontRig
extends Node2D
## A figure seen face-on: a boxer at the weigh-in or waiting for the verdict,
## or the referee who raises the winner's arm.
##
## It uses the same body proportions, build (BoxerSkeleton.build_for), colours
## and three-tone shading as the side-on BoxerRig, so a boxer looks like the
## same man from the front. There is no animation system: the pose is a few
## numbers (each arm's hand position, how far the head is bowed) that the
## owner sets, and solve() works out the joints.
##
## The origin is the floor point between the feet, y down. Points are authored
## in body heights with y UP (like BoxerSkeleton) and converted by _p().
## Arm and side indexes: 0 = the arm on the left of the screen, 1 = the right.

enum Kind { BOXER, REFEREE }

## Half the shoulder width (centre to shoulder joint) for a 1.0 build.
const SHOULDER_X := 0.108
const SHOULDER_Y := 0.790
const HIP_X := 0.046
const HIP_Y := 0.500
const KNEE_Y := 0.270
const ANKLE_Y := 0.045
const FOOT_X := 0.056
const HEAD_Y := 0.9375           ## Centre of the head (chin 0.875, crown 1.0).
## Where a hanging hand rests, relative to its shoulder.
const REST_HAND := Vector2(0.024, -0.315)

## How far down the upper arm (0 - 1) it blends into the shoulder before the
## crease against the torso begins.
const SHOULDER_BLEND := 0.45
## How much of the side-on build's extra (or missing) width shows face-on.
const FRONT_WIDTH := 0.6

const REFEREE_HEIGHT_CM := 178
const SHIRT := [Color("eeeae2"), Color("b8b4ae"), Color("ffffff")]
const TROUSERS := [Color("1c1c22"), Color("0c0c10"), Color("34343e")]
const REF_HAIR := [Color("a4a2a0"), Color("767472")]
const BOW_TIE := Color("101014")

var kind := Kind.BOXER
var data: BoxerData
## Boxers wear gloves in the ring; at the weigh-in their hands are wrapped.
var gloves := true

## Hand (glove centre) targets in local pixels. Vector2.INF = hang at the side.
var hand_target: Array[Vector2] = [Vector2.INF, Vector2.INF]
## 0 - 1: how far the head is bowed (the loser looks at the canvas).
var bow := 0.0
## Mouth open (the winner shouting).
var shout := false

var _h := 80.0
var _bulk := 1.0
var _limb := 1.0
var _neck := 1.0
var _belly := 0.0
var _lean := false
var _skin: Array = []
var _hair: Array = []
var _hair_style := 0
var _bald := false
var _trunks: Array = []
var _trim := Color.WHITE
var _boots: Array = []
var _gloves: Array = []

var _j: Dictionary = {}          # Solved joints (local pixels).
var _time := 0.0
var _breath := 0.0               # Pixels the upper body is lifted (0 or 1).


## A boxer. [param corner_index] picks the glove colour (0 = red, 1 = blue).
## [param size] shrinks the whole figure, e.g. to stand him further back in
## the ring (outlines stay a crisp 2 px).
func setup_boxer(boxer: BoxerData, corner_index: int, wear_gloves: bool = true, size: float = 1.0) -> void:
	kind = Kind.BOXER
	data = boxer
	gloves = wear_gloves
	_h = BoxerSkeleton.pixel_height(boxer.height_cm) * size
	var build := BoxerSkeleton.build_for(boxer.height_cm, boxer.weight_lb)
	# Seen from the front a big man looks less wide than he does side-on
	# (where the chest's depth shows too), so the build is toned down.
	_bulk = 1.0 + (float(build["bulk"]) - 1.0) * FRONT_WIDTH
	_limb = 1.0 + (float(build["limb"]) - 1.0) * FRONT_WIDTH
	_neck = build["neck"]
	_belly = build["belly"]
	_lean = build["lean"]
	_skin = Palette.SKIN_TONES[boxer.skin_index]
	_hair = Palette.HAIR_TONES[boxer.hair_index]
	_hair_style = boxer.hair_style
	_bald = boxer.hair_index == 0
	_trunks = Palette.TRUNKS[boxer.trunks_index]["tones"]
	_trim = Palette.TRUNKS[boxer.trunks_index]["trim"]
	_boots = Palette.BOOTS[boxer.boots_index]
	_gloves = Palette.GLOVES[corner_index]
	_time = randf() * 3.0        # Boxers do not breathe in step.
	solve()


## Gives a boxer gloves in other colours ([base, shadow, highlight]), e.g. to
## match his trunks in a portrait where he has no corner.
func set_glove_tones(tones: Array) -> void:
	_gloves = tones
	queue_redraw()


## The referee: white shirt, black bow tie and trousers, grey hair.
func setup_referee(skin_index: int, size: float = 1.0) -> void:
	kind = Kind.REFEREE
	_h = BoxerSkeleton.pixel_height(REFEREE_HEIGHT_CM) * size
	_bulk = 0.92
	_limb = 0.95
	_neck = 0.95
	_skin = Palette.SKIN_TONES[clampi(skin_index, 0, Palette.SKIN_TONES.size() - 1)]
	_hair = REF_HAIR
	_hair_style = 3              # Neat, slicked back.
	_bald = false
	_boots = [TROUSERS[1], TROUSERS[0]]
	solve()


func pixel_height() -> float:
	return _h


## Upper arm + forearm, in pixels.
func arm_length() -> float:
	return (BoxerSkeleton.UPPER_ARM + BoxerSkeleton.FOREARM) * _h


## Half the figure's width at the hands, in pixels (for spacing a line-up).
func half_width() -> float:
	return (SHOULDER_X * _bulk + REST_HAND.x) * _h + _hand_radius() + 1.0


## Shoulder joint of [param side] in local pixels.
func shoulder(side: int) -> Vector2:
	return _shoulder(side)


## The solved hand (glove centre) of [param side] in local pixels.
func hand(side: int) -> Vector2:
	return _j.get("hand%d" % side, Vector2.ZERO)


## The elbow of [param side] in local pixels.
func elbow(side: int) -> Vector2:
	return _j.get("elbow%d" % side, Vector2.ZERO)


## Where someone would hold this arm: the wrist, just above the hand.
func wrist(side: int) -> Vector2:
	var h := hand(side)
	var back := (_j["elbow%d" % side] - h).normalized() as Vector2
	return h + back * _hand_radius() * 1.4


## Where [param side]'s hand hangs when nobody is holding it.
func rest_hand(side: int) -> Vector2:
	var out := -1.0 if side == 0 else 1.0
	return _shoulder(side) + Vector2(REST_HAND.x * out, -REST_HAND.y) * _h


func _process(delta: float) -> void:
	_time += delta
	# A slow breath: the upper body rises a pixel and settles, stepped like the
	# side-on animation so it keeps the chunky feel.
	var breath := 1.0 if sin(_time * 2.4) > 0.35 else 0.0
	if breath != _breath:
		_breath = breath
		solve()


## Works out every joint from the current hand targets. Call after changing
## hand_target, bow or shout.
func solve() -> void:
	_j.clear()
	for side in 2:
		var out := -1.0 if side == 0 else 1.0
		var sh := _shoulder(side)
		var target: Vector2 = hand_target[side] if hand_target[side] != Vector2.INF else rest_hand(side)
		# Of the two ways the elbow could bend, take the one that keeps it
		# out to the side, away from the body and head.
		var upper := BoxerSkeleton.UPPER_ARM * _h
		var fore := BoxerSkeleton.FOREARM * _h
		var arm := BoxerSkeleton._ik(sh, target, upper, fore, 1.0)
		var other := BoxerSkeleton._ik(sh, target, upper, fore, -1.0)
		if other[0].x * out > arm[0].x * out:
			arm = other
		_j["shoulder%d" % side] = sh
		_j["elbow%d" % side] = arm[0]
		_j["hand%d" % side] = arm[1]
	queue_redraw()


# ============================================================================
#  Geometry
# ============================================================================

## Body-height units (y up) to local pixels.
func _p(x: float, y: float) -> Vector2:
	return Vector2(x * _h, -y * _h)


## As _p() but for the upper body, which rises with each breath.
func _u(x: float, y: float) -> Vector2:
	return Vector2(x * _h, -y * _h - _breath)


func _shoulder(side: int) -> Vector2:
	var out := -1.0 if side == 0 else 1.0
	return _u(SHOULDER_X * _bulk * out, SHOULDER_Y)


## Head-space points: x right, y up, in head units around the head centre.
func _head(x: float, y: float) -> Vector2:
	var size := _h * BoxerSkeleton.HEAD_DRAW_SCALE
	var centre := _u(0.0, HEAD_Y - 0.010 * bow)
	return centre + Vector2(x * size, -y * size)


func _head_poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_head(p.x, p.y))
	return out


## Mirrors a list of right-hand points (x >= 0) into a closed symmetric shape,
## right side top-to-bottom first, then the left side bottom-to-top.
func _mirrored(right: Array) -> Array:
	var pts: Array = right.duplicate()
	for i in range(right.size() - 1, -1, -1):
		var p: Vector2 = right[i]
		if p.x > 0.0:
			pts.append(Vector2(-p.x, p.y))
	return pts


func _hand_radius() -> float:
	if kind == Kind.BOXER and gloves:
		return _h * BoxerSkeleton.GLOVE_R
	return _h * 0.024


# ============================================================================
#  Drawing
# ============================================================================

func _draw() -> void:
	if _j.is_empty():
		return
	_draw_shadow()
	for side in 2:
		_draw_leg(side)
	if kind == Kind.BOXER:
		_draw_trunks()
	else:
		_draw_trousers()
	_draw_torso()
	_draw_head()
	for side in 2:
		_draw_arm(side)
		_draw_hand(side)


func _draw_shadow() -> void:
	var w := (FOOT_X + 0.05) * _h * maxf(_bulk, 0.9)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * w, sin(a) * maxf(_h * 0.025, 1.5)))
	draw_colored_polygon(pts, Palette.SHADOW)


func _draw_leg(side: int) -> void:
	var out := -1.0 if side == 0 else 1.0
	var hip := _p(HIP_X * _bulk * out, HIP_Y)
	var knee := _p((HIP_X * _bulk + FOOT_X) * 0.5 * out, KNEE_Y)
	var ankle := _p(FOOT_X * out, ANKLE_Y)
	var thigh_w := _h * 0.085 * _limb
	var shin_w := _h * 0.062 * _limb
	if kind == Kind.BOXER:
		_chain([hip, knee, ankle], [thigh_w, shin_w], _skin, out)
	# Boot seen from the front: a rounded block with the toe cap lighter.
	var boot_top := ankle + Vector2(0, -_h * 0.050)
	var toe := _p((FOOT_X + 0.006) * out, 0.012)
	var boot_w := shin_w + 1.0
	_capsule_outline(boot_top, toe, boot_w)
	_capsule_fill(boot_top, toe, boot_w, _boots[0])
	draw_line(toe + Vector2(-boot_w * 0.3, 0), toe + Vector2(boot_w * 0.3, 0), _boots[1], 1.0)
	if kind == Kind.BOXER:
		draw_line(boot_top + Vector2(-boot_w * 0.5, -1), boot_top + Vector2(boot_w * 0.5, -1), Palette.SOCK, 1.0)


func _draw_trunks() -> void:
	var tones: Array = _trunks
	var b := _belly
	var leg_w := _h * 0.085 * _limb + 3.0
	var waist := 0.080 * _bulk + 0.016 * b
	var seat := 0.088 * _bulk
	var hip_l := _p(-HIP_X * _bulk, HIP_Y)
	var hip_r := _p(HIP_X * _bulk, HIP_Y)
	var knee_l := _p(-(HIP_X * _bulk + FOOT_X) * 0.5, KNEE_Y)
	var knee_r := _p((HIP_X * _bulk + FOOT_X) * 0.5, KNEE_Y)
	var end_l := hip_l.lerp(knee_l, 0.40)
	var end_r := hip_r.lerp(knee_r, 0.40)
	var pelvis := PackedVector2Array([
		_p(-waist, 0.590), _p(waist, 0.590), _p(seat, 0.500),
		_p(0.012, 0.455), _p(-0.012, 0.455), _p(-seat, 0.500),
	])
	_capsule_outline(hip_l, end_l, leg_w)
	_capsule_outline(hip_r, end_r, leg_w)
	draw_polyline(_closed(pelvis), Palette.OUTLINE, 2.0)
	_capsule_fill(hip_l, end_l, leg_w, tones[0])
	_capsule_fill(hip_r, end_r, leg_w, tones[0])
	draw_colored_polygon(pelvis, tones[0])
	# Waistband, the outer side stripes, a crease down the middle and a shine.
	draw_colored_polygon(PackedVector2Array([
		_p(-waist, 0.590), _p(waist, 0.590), _p(waist + 0.002, 0.562), _p(-waist - 0.002, 0.562),
	]), _trim)
	for out in [-1.0, 1.0]:
		var top := _p((seat - 0.004) * out, 0.552)
		var bottom := (end_l if out < 0.0 else end_r) + Vector2(out * (leg_w * 0.5 - 1.0), 0)
		draw_line(top, bottom, _trim, 1.0)
	draw_line(_p(0.0, 0.556), _p(0.0, 0.470), tones[1], 1.0)
	draw_line(_p(-0.050 * _bulk, 0.540), _p(-0.040 * _bulk, 0.470), tones[2], 1.0)


func _draw_trousers() -> void:
	# Referee: black trousers from the waist to the shoes.
	var leg_w := _h * 0.080
	for out in [-1.0, 1.0]:
		var hip := _p(HIP_X * _bulk * out, HIP_Y)
		var ankle := _p(FOOT_X * out, ANKLE_Y + 0.012)
		_capsule_outline(hip, ankle, leg_w)
	var waist := 0.078 * _bulk
	var pelvis := PackedVector2Array([
		_p(-waist, 0.590), _p(waist, 0.590), _p(waist + 0.006, 0.480),
		_p(0.010, 0.440), _p(-0.010, 0.440), _p(-waist - 0.006, 0.480),
	])
	draw_polyline(_closed(pelvis), Palette.OUTLINE, 2.0)
	for out in [-1.0, 1.0]:
		var hip := _p(HIP_X * _bulk * out, HIP_Y)
		var ankle := _p(FOOT_X * out, ANKLE_Y + 0.012)
		_capsule_fill(hip, ankle, leg_w, TROUSERS[0])
		draw_line(hip + Vector2(out * leg_w * 0.25, 0), ankle + Vector2(out * leg_w * 0.25, 0), TROUSERS[2], 1.0)
	draw_colored_polygon(pelvis, TROUSERS[0])
	draw_line(_p(0.0, 0.585), _p(0.0, 0.450), TROUSERS[1], 1.0)
	# Belt.
	draw_line(_p(-waist, 0.582), _p(waist, 0.582), TROUSERS[1], 2.0)


func _draw_torso() -> void:
	var referee := kind == Kind.REFEREE
	var tones: Array = SHIRT if referee else _skin
	var bk := _bulk
	var b := _belly
	# Right half from the neck down to the waist, mirrored for the left.
	var body := _torso_poly(_mirrored([
		Vector2(0.034 * _neck, 0.822), Vector2(0.090 * bk, 0.806),
		Vector2(0.112 * bk, 0.778), Vector2(0.104 * bk, 0.730),
		Vector2(0.094 * bk + 0.010 * b, 0.680), Vector2(0.082 * bk + 0.022 * b, 0.630),
		Vector2(0.080 * bk + 0.016 * b, 0.586), Vector2(0.0, 0.586),
	]))
	# Neck first so the shoulders overlap it.
	var neck_w := _h * 0.066 * _neck
	var neck_top := _u(0.0, 0.880 - 0.010 * bow)
	var neck_base := _u(0.0, 0.812)
	_capsule_outline(neck_base, neck_top, neck_w)
	_capsule_fill(neck_base, neck_top, neck_w, _skin[1])
	_polygon_outlined(body, tones[0])

	# Shading: the outer edges in shadow, a lit centre.
	for out in [-1.0, 1.0]:
		draw_colored_polygon(_torso_poly([
			Vector2(0.104 * bk * out, 0.770), Vector2((0.094 * bk + 0.010 * b) * out, 0.680),
			Vector2((0.080 * bk + 0.016 * b) * out, 0.588), Vector2((0.066 * bk + 0.012 * b) * out, 0.588),
			Vector2((0.078 * bk + 0.008 * b) * out, 0.680), Vector2(0.088 * bk * out, 0.760),
		]), tones[1])

	if referee:
		_draw_shirt_details()
		return

	# Collar bones and pecs.
	for out in [-1.0, 1.0]:
		draw_line(_u(0.020 * out, 0.800), _u(0.070 * bk * out, 0.790), _skin[2], 1.0)
		draw_line(_u(0.010 * out, 0.722), _u(0.074 * bk * out, 0.716), _skin[1], 1.0)
	draw_line(_u(0.0, 0.776), _u(0.0, 0.720), _skin[1], 1.0)
	if b > 0.25:
		# Heavy stomach: a soft highlight with a shadow line under it.
		draw_colored_polygon(_torso_poly([
			Vector2(-0.030 * bk, 0.664), Vector2(0.030 * bk, 0.664),
			Vector2(0.046 * bk, 0.630), Vector2(-0.046 * bk, 0.630),
		]), _skin[2])
		draw_line(_p(-0.052 * bk, 0.604), _p(0.052 * bk, 0.604), _skin[1], 1.0)
	elif _bulk > 0.98 or _lean:
		# Abs: two rows of short lines either side of the middle.
		for y in [0.680, 0.646, 0.612]:
			for out in [-1.0, 1.0]:
				draw_line(_u(0.008 * out, y), _u(0.030 * bk * out, y), _skin[1], 1.0)
	if _lean:
		for out in [-1.0, 1.0]:
			for rib_y in [0.700, 0.680]:
				draw_line(_u(0.058 * bk * out, rib_y), _u(0.082 * bk * out, rib_y + 0.006), _skin[1], 1.0)


func _draw_shirt_details() -> void:
	# Open collar, black bow tie and a line of buttons.
	var collar := _torso_poly([Vector2(-0.030, 0.824), Vector2(0.0, 0.800), Vector2(0.030, 0.824)])
	draw_polyline(collar, SHIRT[1], 1.0)
	var knot := _u(0.0, 0.806)
	var wing := 0.024 * _h
	draw_colored_polygon(PackedVector2Array([
		knot + Vector2(-wing, -1.5), knot + Vector2(-wing, 1.5), knot, knot + Vector2(wing, 1.5), knot + Vector2(wing, -1.5), knot,
	]), BOW_TIE)
	draw_rect(Rect2(knot - Vector2(1, 1), Vector2(2, 2)), BOW_TIE)
	for y in [0.750, 0.690, 0.630]:
		draw_rect(Rect2(_u(0.0, y).round() - Vector2(0.5, 0.5), Vector2(1, 1)), SHIRT[1])


func _draw_head() -> void:
	var skin: Array = _skin
	# Ears behind the head.
	for out in [-1.0, 1.0]:
		var ear := _head(0.052 * out, 0.000)
		draw_circle(ear, _h * 0.015, Palette.OUTLINE)
		draw_circle(ear, _h * 0.011, skin[1])
	var face := _head_poly(_mirrored([
		Vector2(0.000, 0.064), Vector2(0.036, 0.058), Vector2(0.050, 0.034),
		Vector2(0.052, 0.002), Vector2(0.046, -0.030), Vector2(0.032, -0.052),
		Vector2(0.012, -0.064), Vector2(0.000, -0.066),
	]))
	_polygon_outlined(face, skin[0])
	# Shadow down one side of the face and under the jaw, a lit cheek.
	draw_colored_polygon(_head_poly([
		Vector2(-0.051, 0.010), Vector2(-0.046, -0.030), Vector2(-0.032, -0.052),
		Vector2(-0.012, -0.064), Vector2(-0.020, -0.046), Vector2(-0.036, -0.020),
	]), skin[1])
	draw_colored_polygon(_head_poly([
		Vector2(0.022, -0.004), Vector2(0.040, -0.004), Vector2(0.036, -0.022), Vector2(0.024, -0.020),
	]), skin[2])

	_draw_hair()

	# Face: brows, eyes, the shadow of the nose and the mouth. Bowing the head
	# drops the features towards the chin, as if looking down at the canvas.
	var drop := 0.016 * bow
	var brow_color: Color = Palette.darken(_hair[1] if not _bald else skin[1], 0.2)
	for out in [-1.0, 1.0]:
		draw_line(_head(0.012 * out, 0.020 - drop), _head(0.034 * out, 0.022 - drop), brow_color, 1.0)
		var eye := _head(0.022 * out, 0.006 - drop).round()
		draw_rect(Rect2(eye - Vector2(0.5, 0.5), Vector2(1, 1)), Palette.EYE)
	var nose := _head(0.004, -0.014 - drop).round()
	draw_rect(Rect2(nose - Vector2(0.5, 0.5), Vector2(1, 1)), skin[1])
	var mouth_y := -0.036 - drop
	if shout:
		var m := _head(0.0, mouth_y).round()
		draw_rect(Rect2(m - Vector2(1, 1), Vector2(2, 2)), Palette.darken(skin[1], 0.55))
	else:
		draw_line(_head(-0.012, mouth_y), _head(0.012, mouth_y), Palette.darken(skin[1], 0.25), 1.0)


func _draw_hair() -> void:
	if _bald:
		draw_line(_head(-0.016, 0.054), _head(0.010, 0.058), _skin[2], 1.0)
		return
	var base: Color = _hair[0]
	var shade: Color = _hair[1]
	var dip := 0.010 * bow          # A bowed head shows more of the top.
	var hairline := [Vector2(0.046, 0.012), Vector2(0.040, 0.034 - dip), Vector2(0.016, 0.040 - dip), Vector2(0.000, 0.040 - dip)]
	var top: Array = []
	match _hair_style:
		0:  # Crop
			top = [Vector2(0.000, 0.071), Vector2(0.034, 0.064), Vector2(0.054, 0.040), Vector2(0.055, 0.004)]
		1:  # Flat top
			top = [Vector2(0.000, 0.082), Vector2(0.048, 0.082), Vector2(0.056, 0.050), Vector2(0.055, 0.004)]
		2:  # Curly
			top = [Vector2(0.000, 0.086), Vector2(0.048, 0.074), Vector2(0.068, 0.040), Vector2(0.064, 0.000)]
			hairline[0] = Vector2(0.050, 0.012)
		_:  # Slick
			top = [Vector2(0.000, 0.072), Vector2(0.036, 0.066), Vector2(0.054, 0.044), Vector2(0.054, 0.010)]
	# Right half: over the top and down the side, then back along the hairline.
	var right: Array = top.duplicate()
	for i in hairline.size():
		right.append(hairline[i])
	var shape := _head_poly(_mirrored(right))
	_polygon_outlined(shape, base)
	draw_polyline(_head_poly([Vector2(-0.040, 0.036 - dip), Vector2(0.0, 0.042 - dip), Vector2(0.040, 0.036 - dip)]), shade, 1.0)
	match _hair_style:
		2:
			for p in [Vector2(-0.040, 0.066), Vector2(0.000, 0.076), Vector2(0.040, 0.066), Vector2(-0.058, 0.030), Vector2(0.058, 0.030)]:
				draw_circle(_head(p.x, p.y), maxf(_h * 0.009, 1.0), shade)
		3:
			# A side parting and a shine.
			draw_line(_head(-0.022, 0.068), _head(-0.026, 0.044 - dip), shade, 1.0)
			draw_line(_head(0.000, 0.064), _head(0.030, 0.058), base.lightened(0.3), 1.0)
		1:
			draw_line(_head(-0.040, 0.076), _head(0.040, 0.076), base.lightened(0.2), 1.0)


func _draw_arm(side: int) -> void:
	var out := -1.0 if side == 0 else 1.0
	var sh: Vector2 = _j["shoulder%d" % side]
	var elbow: Vector2 = _j["elbow%d" % side]
	var hand_p: Vector2 = _j["hand%d" % side]
	var upper_w := _h * 0.066 * _limb
	var fore_w := _h * 0.056 * _limb
	var tones: Array = SHIRT if kind == Kind.REFEREE else _skin
	# The forearm is a normal outlined limb.
	_capsule_outline(elbow, hand_p, fore_w)
	# The upper arm grows out of the shoulder rather than being pinned on: no
	# outline where it joins the body, a dark edge only on its outer side (the
	# silhouette) from part way down, and a soft crease in the shadow tone on
	# the side against the torso.
	var along := (elbow - sh).normalized()
	var normal := along.orthogonal()
	if normal.x * out < 0.0:
		normal = -normal
	var edge := upper_w * 0.5 + 0.5
	var outer_from := sh.lerp(elbow, SHOULDER_BLEND * 0.5)
	var inner_from := sh.lerp(elbow, SHOULDER_BLEND)
	draw_line(outer_from + normal * edge, elbow + normal * edge, Palette.OUTLINE, 2.0)
	_capsule_fill(sh, elbow, upper_w, tones[0])
	_capsule_fill(elbow, hand_p, fore_w, tones[0])
	draw_line(inner_from - normal * (edge - 1.0), elbow - normal * (edge - 1.0), tones[1], 1.0)
	_shade(elbow, hand_p, fore_w, tones, out)
	draw_line(inner_from + normal * upper_w * 0.30, elbow + normal * upper_w * 0.30, tones[1], maxf(upper_w * 0.30, 1.0))
	# Rounded shoulder in the body's own tone so the arm grows out of it.
	draw_circle(sh, upper_w * 0.62, tones[0])
	if kind == Kind.REFEREE:
		# Shirt cuff, then the hand shows below it.
		var back := (elbow - hand_p).normalized()
		var cuff := hand_p + back * fore_w * 0.9
		var across := back.orthogonal() * fore_w * 0.5
		draw_line(cuff - across, cuff + across, SHIRT[1], 1.0)


func _draw_hand(side: int) -> void:
	var hand_p: Vector2 = _j["hand%d" % side]
	var elbow: Vector2 = _j["elbow%d" % side]
	var r := _hand_radius()
	var back := (elbow - hand_p).normalized()
	if kind == Kind.BOXER and gloves:
		var tones: Array = _gloves
		var cuff := hand_p + back * r * 1.25
		draw_circle(hand_p, r + 1.0, Palette.OUTLINE)
		_capsule_outline(hand_p, cuff, r * 1.3)
		_capsule_fill(hand_p, cuff, r * 1.3, tones[1])
		draw_circle(hand_p, r, tones[0])
		var across := back.orthogonal()
		draw_line(cuff + across * r * 0.6, cuff - across * r * 0.6, Palette.LACE, 1.0)
		draw_circle(hand_p - back * r * 0.25 + Vector2(-0.3, -0.3) * r, maxf(r * 0.3, 1.0), tones[2])
		return
	# Bare hand (referee) or a taped fist (weigh-in).
	var colour: Color = Palette.LACE if kind == Kind.BOXER else _skin[0]
	draw_circle(hand_p, r + 1.0, Palette.OUTLINE)
	draw_circle(hand_p, r, colour)


# ============================================================================
#  Drawing helpers (the same look as BoxerRig)
# ============================================================================

func _torso_poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_u(p.x, p.y))
	return out


## A limb of joined segments: outline, fill, then the shading.
func _chain(points: Array, widths: Array, tones: Array, out: float) -> void:
	for i in widths.size():
		_capsule_outline(points[i], points[i + 1], widths[i])
	for i in widths.size():
		_capsule_fill(points[i], points[i + 1], widths[i], tones[0])
	for i in widths.size():
		_shade(points[i], points[i + 1], widths[i], tones, out)


## Shadow along the side of a segment facing [param out] (away from the
## light, which is front-left) and a highlight along the other side.
func _shade(a: Vector2, b: Vector2, w: float, tones: Array, out: float) -> void:
	var normal := (b - a).normalized().orthogonal()
	if normal.x * out < 0.0:
		normal = -normal
	draw_line(a + normal * w * 0.30, b + normal * w * 0.30, tones[1], maxf(w * 0.30, 1.0))
	draw_line(a - normal * w * 0.22, b - normal * w * 0.22, tones[2], 1.0)


func _capsule_outline(a: Vector2, b: Vector2, width: float) -> void:
	draw_line(a, b, Palette.OUTLINE, width + 2.0)
	draw_circle(a, width * 0.5 + 1.0, Palette.OUTLINE)
	draw_circle(b, width * 0.5 + 1.0, Palette.OUTLINE)


func _capsule_fill(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	draw_line(a, b, color, width)
	draw_circle(a, width * 0.5, color)
	draw_circle(b, width * 0.5, color)


func _polygon_outlined(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(_closed(points), Palette.OUTLINE, 2.0)
	draw_colored_polygon(points, color)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out
