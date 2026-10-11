class_name BoxerRig
extends Node2D
## Draws and animates one boxer in the low-resolution arena.
##
## There are no sprite sheets: the boxer is drawn from simple shapes every frame
## (outlined capsules for limbs, polygons for the torso, trunks and head) using
## three-tone shading. That means ONE rig covers every boxer - height scales the
## whole body, weight and height change how bulky it looks, and skin, hair,
## trunks, boots and gloves are just colours.
##
## The node's origin is the floor point between the boxer's feet. Everything is
## drawn facing right; [member facing] flips the node for the boxer on the right.
##
## Animation is stepped at ANIM_FPS so motion has the slightly choppy feel of a
## late-80s home computer game rather than perfectly smooth tweening.

const ANIM_FPS := 20.0
## Far-side limbs are drawn this much darker to suggest depth.
const FAR_DARKEN := 0.22

## Emitted when a non-looping animation reaches its last step.
signal animation_finished(anim_name: String)

var data: BoxerData
var corner: int = 0
var facing: int = 1: set = set_facing

var _h := 80.0          # Height in arena pixels.
var _bulk := 1.0        # Width multiplier (weight / height build).
var _skin: Array = []
var _hair: Array = []
var _trunks: Array = []
var _trim := Color.WHITE
var _boots: Array = []
var _gloves: Array = []

var _anim_name := ""
var _anim: Dictionary = {}
var _duration_scale := 1.0
var _time := 0.0
var _finished := false
var _start_pose: Dictionary = {}
var _pose: Dictionary = {}


## Prepares the rig for a boxer. [param corner_index] 0 = red, 1 = blue.
func setup(boxer: BoxerData, corner_index: int) -> void:
	data = boxer
	corner = corner_index
	_h = BoxerSkeleton.pixel_height(boxer.height_cm)
	_bulk = BoxerSkeleton.bulk_for(boxer.height_cm, boxer.weight_lb)
	_skin = Palette.SKIN_TONES[boxer.skin_index]
	_hair = Palette.HAIR_TONES[boxer.hair_index]
	_trunks = Palette.TRUNKS[boxer.trunks_index]["tones"]
	_trim = Palette.TRUNKS[boxer.trunks_index]["trim"]
	_boots = Palette.BOOTS[boxer.boots_index]
	_gloves = Palette.GLOVES[corner_index]
	_pose = BoxerPoses.get_pose("relaxed").duplicate()
	play("relaxed", 1.0, true)


func set_facing(value: int) -> void:
	facing = 1 if value >= 0 else -1
	scale.x = facing


## Pixel height of this boxer in the arena.
func pixel_height() -> float:
	return _h


func current_animation() -> String:
	return _anim_name


func is_finished() -> bool:
	return _finished


## Starts an animation. Calling play() with the animation that is already
## running does nothing unless [param restart] is true, so it is safe to call
## every frame. [param duration_scale] > 1 plays slower, < 1 faster.
func play(anim_name: String, duration_scale: float = 1.0, restart: bool = false) -> void:
	if not BoxerPoses.has_anim(anim_name):
		push_error("BoxerRig: unknown animation '%s'" % anim_name)
		return
	if anim_name == _anim_name and not restart:
		_duration_scale = duration_scale
		return
	_anim_name = anim_name
	_anim = BoxerPoses.ANIMS[anim_name]
	_duration_scale = maxf(duration_scale, 0.05)
	_time = 0.0
	_finished = false
	_start_pose = _pose.duplicate()


## Jumps straight to the final pose of an animation (no blending). Handy for
## setting up a scene, e.g. a boxer already lying on the canvas.
func snap_to(anim_name: String) -> void:
	play(anim_name, 1.0, true)
	var steps: Array = _anim["steps"]
	_pose = BoxerPoses.get_pose(steps[-1][0]).duplicate()
	_start_pose = _pose.duplicate()
	if not _anim["loop"]:
		_time = BoxerPoses.length(anim_name)
		_finished = true
	queue_redraw()


func _process(delta: float) -> void:
	if _anim.is_empty():
		return
	_time += delta
	var cycle := BoxerPoses.length(_anim_name, _duration_scale)
	if _anim["loop"]:
		# When a loop wraps, the next pass starts from the loop's last pose.
		while _time >= cycle and cycle > 0.0:
			_time -= cycle
			_start_pose = BoxerPoses.get_pose(_anim["steps"][-1][0])
	elif _time >= cycle and not _finished:
		_finished = true
		animation_finished.emit(_anim_name)

	var stepped := floorf(_time * ANIM_FPS) / ANIM_FPS
	_pose = _evaluate(stepped)
	queue_redraw()


## Works out the pose [param t] seconds into the current animation.
func _evaluate(t: float) -> Dictionary:
	var previous := _start_pose
	for step in _anim["steps"]:
		var target := BoxerPoses.get_pose(step[0])
		var duration: float = step[1] * _duration_scale
		if t < duration:
			var k := clampf(t / duration, 0.0, 1.0)
			return BoxerPoses.blend(previous, target, smoothstep(0.0, 1.0, k))
		t -= duration
		previous = target
	return previous.duplicate()


# ============================================================================
#  Drawing
# ============================================================================

func _draw() -> void:
	if data == null:
		return
	var j := BoxerSkeleton.solve(_pose, _h, _bulk)
	_draw_shadow(j)
	_draw_leg(j, "rear", true)
	_draw_arm(j, "rear", true)
	_draw_leg(j, "lead", false)
	_draw_torso(j)
	_draw_trunks(j)
	_draw_head(j)
	_draw_glove(j, "rear", true)
	_draw_arm(j, "lead", false)
	_draw_glove(j, "lead", false)


func _draw_shadow(j: Dictionary) -> void:
	var left: float = minf(minf(j["ankle_lead"].x, j["ankle_rear"].x), j["hip"].x) - _h * 0.08
	var right: float = maxf(maxf(j["ankle_lead"].x, j["ankle_rear"].x), j["hip"].x) + _h * 0.08
	var centre := Vector2((left + right) * 0.5, 0.0)
	_ellipse(centre, (right - left) * 0.5, maxf(_h * 0.025, 1.5), Palette.SHADOW)


func _draw_leg(j: Dictionary, side: String, far: bool) -> void:
	var hip_p: Vector2 = j["hip_" + side]
	var knee: Vector2 = j["knee_" + side]
	var ankle: Vector2 = j["ankle_" + side]
	var skin := _tones(_skin, far)
	var thigh_w := _h * 0.085 * _bulk
	var shin_w := _h * 0.062 * _bulk
	_chain([hip_p, knee, ankle], [thigh_w, shin_w], skin)

	# Boot: the bottom of the shin plus a foot pointing the way the boxer faces.
	var boots := _tones(_boots, far)
	var shin_dir := (ankle - knee).normalized()
	var foot_dir := Vector2(shin_dir.y, -shin_dir.x)   # Shin direction turned 90 degrees.
	var boot_top := ankle - shin_dir * _h * 0.075
	var heel := ankle - foot_dir * _h * 0.022
	var toe := ankle + foot_dir * _h * 0.070
	var boot_w := shin_w + 1.0
	_capsule_outline(boot_top, ankle, boot_w)
	_capsule_outline(heel, toe, _h * 0.045)
	_capsule_fill(boot_top, ankle, boot_w, boots[0])
	_capsule_fill(heel, toe, _h * 0.045, boots[0])
	draw_line(heel + Vector2(0, _h * 0.012), toe + Vector2(0, _h * 0.012), boots[1], 1.0)
	# Sock band above the boot.
	var sock_a := boot_top - shin_dir * 1.0
	draw_line(sock_a, boot_top, Palette.darken(Palette.SOCK, FAR_DARKEN if far else 0.0), boot_w)


func _draw_arm(j: Dictionary, side: String, far: bool) -> void:
	var shoulder: Vector2 = j["sh_" + side]
	var elbow: Vector2 = j["elbow_" + side]
	var glove: Vector2 = j["glove_" + side]
	var skin := _tones(_skin, far)
	_chain([shoulder, elbow, glove], [_h * 0.066 * _bulk, _h * 0.056 * _bulk], skin)


func _draw_glove(j: Dictionary, side: String, far: bool) -> void:
	var glove: Vector2 = j["glove_" + side]
	var elbow: Vector2 = j["elbow_" + side]
	var tones := _tones(_gloves, far)
	var r := _h * BoxerSkeleton.GLOVE_R
	var back := (elbow - glove).normalized()
	var cuff := glove + back * r * 1.25
	var up := Vector2(back.y, -back.x)
	if up.y > 0.0:
		up = -up

	# Outline first so the cuff and fist read as one shape.
	draw_circle(glove, r + 1.0, Palette.OUTLINE)
	_capsule_outline(glove, cuff, r * 1.3)
	_capsule_fill(glove, cuff, r * 1.3, tones[1])
	draw_circle(glove, r, tones[0])
	# Thumb bump, white lace band and a highlight.
	draw_circle(glove + up * r * 0.55 + back * r * 0.2, r * 0.42, tones[1])
	draw_line(cuff + up * r * 0.6, cuff - up * r * 0.6, Palette.darken(Palette.LACE, FAR_DARKEN if far else 0.0), 1.0)
	draw_circle(glove + up * r * 0.35 - back * r * 0.25, maxf(r * 0.3, 1.0), tones[2])


func _draw_torso(j: Dictionary) -> void:
	var skin: Array = _skin
	# Outline of the chest / back seen from a three-quarter angle.
	var body := _torso_points(j, [
		Vector2(-0.070, 0.000), Vector2(-0.080, 0.100), Vector2(-0.085, 0.200),
		Vector2(-0.075, 0.270), Vector2(-0.030, 0.295), Vector2(0.030, 0.295),
		Vector2(0.075, 0.275), Vector2(0.092, 0.220), Vector2(0.086, 0.150),
		Vector2(0.070, 0.070), Vector2(0.068, 0.000),
	])
	# Neck goes in first so the shoulders overlap it.
	var neck_w := _h * 0.062 * _bulk
	var head_base: Vector2 = j["neck"] + (j["head"] - j["neck"]) * 0.45
	_capsule_outline(j["neck"], head_base, neck_w)
	_capsule_fill(j["neck"], head_base, neck_w, skin[1])

	_polygon_outlined(body, skin[0])
	# Shadow down the back, highlight across the chest.
	draw_colored_polygon(_torso_points(j, [
		Vector2(-0.069, 0.000), Vector2(-0.079, 0.100), Vector2(-0.084, 0.200),
		Vector2(-0.074, 0.268), Vector2(-0.045, 0.270), Vector2(-0.052, 0.150),
		Vector2(-0.042, 0.000),
	]), skin[1])
	draw_colored_polygon(_torso_points(j, [
		Vector2(0.015, 0.250), Vector2(0.070, 0.262), Vector2(0.086, 0.215),
		Vector2(0.074, 0.165), Vector2(0.020, 0.175),
	]), skin[2])
	# Pec line and, for the heavier boxers, a bit of ab definition.
	var pec := _torso_points(j, [Vector2(0.018, 0.168), Vector2(0.084, 0.152)])
	draw_line(pec[0], pec[1], skin[1], 1.0)
	if _bulk > 0.98:
		var abs_a := _torso_points(j, [Vector2(0.020, 0.110), Vector2(0.066, 0.104)])
		var abs_b := _torso_points(j, [Vector2(0.022, 0.065), Vector2(0.064, 0.060)])
		draw_line(abs_a[0], abs_a[1], skin[1], 1.0)
		draw_line(abs_b[0], abs_b[1], skin[1], 1.0)


func _draw_trunks(j: Dictionary) -> void:
	var tones: Array = _trunks
	var leg_w := _h * 0.085 * _bulk + 3.0
	var lead_end: Vector2 = j["hip_lead"].lerp(j["knee_lead"], 0.48)
	var rear_end: Vector2 = j["hip_rear"].lerp(j["knee_rear"], 0.48)
	var pelvis := _torso_points(j, [
		Vector2(-0.080, 0.055), Vector2(0.074, 0.055),
		Vector2(0.080, -0.035), Vector2(-0.084, -0.035),
	])

	# Outline pass for all three pieces, then the fills on top.
	_capsule_outline(j["hip_rear"], rear_end, leg_w)
	_capsule_outline(j["hip_lead"], lead_end, leg_w)
	draw_polyline(_closed(pelvis), Palette.OUTLINE, 2.0)
	_capsule_fill(j["hip_rear"], rear_end, leg_w, tones[1])
	draw_colored_polygon(pelvis, tones[0])
	_capsule_fill(j["hip_lead"], lead_end, leg_w, tones[0])

	# Waistband, side stripe and a fold of shadow between the legs.
	var band := _torso_points(j, [
		Vector2(-0.080, 0.055), Vector2(0.074, 0.055),
		Vector2(0.076, 0.030), Vector2(-0.082, 0.030),
	])
	draw_colored_polygon(band, _trim)
	draw_line(j["hip_lead"], lead_end, _trim, 1.0)
	var fold := _torso_points(j, [Vector2(0.005, 0.000), Vector2(0.000, -0.034)])
	draw_line(fold[0], fold[1], tones[1], 1.0)
	var shine := _torso_points(j, [Vector2(0.040, 0.020), Vector2(0.065, -0.020)])
	draw_line(shine[0], shine[1], tones[2], 1.0)


func _draw_head(j: Dictionary) -> void:
	var skin: Array = _skin
	var face := _head_points(j, [
		Vector2(-0.052, 0.005), Vector2(-0.046, 0.040), Vector2(-0.020, 0.062),
		Vector2(0.020, 0.064), Vector2(0.046, 0.046), Vector2(0.056, 0.018),
		Vector2(0.066, 0.002), Vector2(0.057, -0.010), Vector2(0.059, -0.024),
		Vector2(0.050, -0.048), Vector2(0.020, -0.062), Vector2(-0.020, -0.052),
		Vector2(-0.042, -0.030),
	])
	_polygon_outlined(face, skin[0])
	# Jaw and back-of-head shadow, cheek highlight.
	draw_colored_polygon(_head_points(j, [
		Vector2(-0.051, 0.005), Vector2(-0.041, -0.029), Vector2(-0.019, -0.051),
		Vector2(0.019, -0.061), Vector2(0.040, -0.052), Vector2(0.004, -0.040),
		Vector2(-0.030, -0.010),
	]), skin[1])
	draw_colored_polygon(_head_points(j, [
		Vector2(0.018, 0.040), Vector2(0.044, 0.040), Vector2(0.050, 0.020),
		Vector2(0.030, 0.012),
	]), skin[2])

	# Ear.
	var ear := _head_points(j, [Vector2(-0.012, -0.002)])[0]
	draw_circle(ear, _h * 0.015, Palette.OUTLINE)
	draw_circle(ear, _h * 0.011, skin[1])

	_draw_hair(j)

	# Eye, brow and mouth - single pixels at this resolution.
	var eye := _head_points(j, [Vector2(0.040, 0.014)])[0]
	draw_rect(Rect2(eye.round() - Vector2(0.5, 0.5), Vector2(1.5, 1.5)), Palette.EYE)
	var brow := _head_points(j, [Vector2(0.030, 0.026), Vector2(0.054, 0.024)])
	var brow_color: Color = _hair[1] if data.hair_index > 0 else skin[1]
	draw_line(brow[0], brow[1], Palette.darken(brow_color, 0.2), 1.0)
	var mouth := _head_points(j, [Vector2(0.044, -0.026), Vector2(0.056, -0.026)])
	draw_line(mouth[0], mouth[1], Palette.darken(skin[1], 0.25), 1.0)


func _draw_hair(j: Dictionary) -> void:
	if data.hair_index == 0:
		# Shaved head: just a shine on the scalp.
		var shine := _head_points(j, [Vector2(-0.010, 0.056), Vector2(0.018, 0.058)])
		draw_line(shine[0], shine[1], _skin[2], 1.0)
		return
	var base: Color = _hair[0]
	var shade: Color = _hair[1]
	var shape: Array[Vector2] = []
	match data.hair_style:
		0:  # Crop
			shape = [Vector2(-0.056, 0.000), Vector2(-0.052, 0.046), Vector2(-0.022, 0.070),
					 Vector2(0.024, 0.071), Vector2(0.050, 0.052), Vector2(0.053, 0.032),
					 Vector2(0.030, 0.040), Vector2(-0.008, 0.036), Vector2(-0.030, 0.018),
					 Vector2(-0.040, -0.012)]
		1:  # Flat top
			shape = [Vector2(-0.057, 0.000), Vector2(-0.056, 0.082), Vector2(0.044, 0.086),
					 Vector2(0.052, 0.040), Vector2(0.030, 0.044), Vector2(-0.010, 0.034),
					 Vector2(-0.032, 0.016), Vector2(-0.042, -0.012)]
		2:  # Curly
			shape = [Vector2(-0.066, -0.006), Vector2(-0.068, 0.042), Vector2(-0.046, 0.080),
					 Vector2(0.000, 0.090), Vector2(0.042, 0.080), Vector2(0.058, 0.048),
					 Vector2(0.036, 0.042), Vector2(-0.004, 0.038), Vector2(-0.030, 0.018),
					 Vector2(-0.046, -0.016)]
		_:  # Slick
			shape = [Vector2(-0.058, -0.010), Vector2(-0.054, 0.048), Vector2(-0.020, 0.072),
					 Vector2(0.030, 0.070), Vector2(0.054, 0.046), Vector2(0.036, 0.046),
					 Vector2(-0.004, 0.042), Vector2(-0.036, 0.024), Vector2(-0.046, -0.014)]
	var hair := _head_points(j, shape)
	_polygon_outlined(hair, base)
	# Darker underside and a little texture so it does not read as a hat.
	var under := _head_points(j, [Vector2(-0.040, 0.004), Vector2(-0.020, 0.030), Vector2(0.020, 0.040)])
	draw_polyline(PackedVector2Array(under), shade, 1.0)
	if data.hair_style == 2:
		for p in [Vector2(-0.040, 0.066), Vector2(-0.006, 0.078), Vector2(0.030, 0.070), Vector2(-0.056, 0.030)]:
			draw_circle(_head_points(j, [p])[0], maxf(_h * 0.009, 1.0), shade)
	elif data.hair_style == 3:
		var shine := _head_points(j, [Vector2(-0.030, 0.060), Vector2(0.020, 0.064)])
		draw_line(shine[0], shine[1], base.lightened(0.3), 1.0)


# ============================================================================
#  Drawing helpers
# ============================================================================

## Returns [base, shadow, highlight] (or [base, shadow]) darkened for far limbs.
func _tones(tones: Array, far: bool) -> Array:
	if not far:
		return tones
	var out: Array = []
	for c in tones:
		out.append(Palette.darken(c, FAR_DARKEN))
	return out


## Converts points authored in the torso frame (x = chest direction scaled by
## bulk, y = up the spine) into local pixels.
func _torso_points(j: Dictionary, pts: Array) -> PackedVector2Array:
	var hip: Vector2 = j["hip"]
	var spine: Vector2 = j["spine"]
	var fwd: Vector2 = j["fwd"]
	var out := PackedVector2Array()
	for p in pts:
		out.append(hip + fwd * p.x * _h * _bulk + spine * p.y * _h)
	return out


## Converts points authored around the head centre (x forward, y up) to pixels.
func _head_points(j: Dictionary, pts: Array) -> PackedVector2Array:
	var centre: Vector2 = j["head"]
	var angle: float = j["head_angle"]
	var up := Vector2(sin(angle), -cos(angle))
	var fwd := Vector2(cos(angle), sin(angle))
	var size := _h * BoxerSkeleton.HEAD_DRAW_SCALE
	var out := PackedVector2Array()
	for p in pts:
		out.append(centre + fwd * p.x * size + up * p.y * size)
	return out


## A limb made of joined segments: outline pass, fill pass, then shading.
func _chain(points: Array, widths: Array, tones: Array) -> void:
	for i in widths.size():
		_capsule_outline(points[i], points[i + 1], widths[i])
	for i in widths.size():
		_capsule_fill(points[i], points[i + 1], widths[i], tones[0])
	for i in widths.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var normal := (b - a).normalized().orthogonal()
		if normal.y > 0.0:
			normal = -normal   # Highlight on the upper side, shadow underneath.
		var w: float = widths[i]
		draw_line(a - normal * w * 0.30, b - normal * w * 0.30, tones[1], maxf(w * 0.30, 1.0))
		draw_line(a + normal * w * 0.22, b + normal * w * 0.22, tones[2], 1.0)


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


func _ellipse(centre: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
