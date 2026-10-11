class_name BoxerSkeleton
extends RefCounted
## Turns a pose (a handful of numbers) into joint positions.
##
## Poses are authored in "body heights" (1.0 = the boxer's full height) with
## +x pointing towards the opponent and +y pointing UP, which is the natural way
## to think about a body. solve() converts that into screen pixels (y down) for a
## boxer of a given pixel height, using simple two-bone IK for arms and legs.
##
## Because everything is in body heights, one set of poses works for every
## boxer: a 198 cm boxer is simply drawn with a bigger [code]h[/code].

# --- Body proportions (fractions of total height) --------------------------------
const THIGH     := 0.245
const SHIN      := 0.235
const TORSO     := 0.290   ## Hip joint to base of neck.
const NECK      := 0.035
const HEAD      := 0.125   ## Chin to crown.
const UPPER_ARM := 0.170
const FOREARM   := 0.160
const GLOVE_R   := 0.050   ## Glove radius.
## Heads are drawn a touch larger than life so faces read at low resolution.
const HEAD_DRAW_SCALE := 1.15

## Pixels per centimetre of real height inside the low-res arena.
const PIXELS_PER_CM := 0.45


## Pixel height for a boxer of the given real height.
static func pixel_height(height_cm: int) -> float:
	return height_cm * PIXELS_PER_CM


## A 157 lb, 184 cm middleweight is the reference build (everything 1.0).
const REF_LB_PER_CM := 157.0 / 184.0
## Weight-per-height (relative to the reference) of a lean, toned heavyweight.
const TONED_MASS := 1.25


## How a boxer's body is drawn, from his height and weight:
##   bulk  - torso and shoulder width (1.0 = reference middleweight)
##   limb  - arm and leg thickness (scales a little less than the torso)
##   neck  - neck thickness
##   belly - 0 - 1, how much the stomach pushes out (only the heaviest men)
##   lean  - true for the light, wiry builds that show their ribs
##
## "Mass" is weight per centimetre of height compared with the reference, so a
## tall, light man looks rangy and a short, heavy one looks stocky. Lighter men
## (under about 154 lb) also get a slimmer frame so the lightweights read as
## clearly smaller than the middleweights. Heavyweights widen quickly up to a
## toned build, then more gently, and only the very heaviest carry a little
## weight around the middle.
static func build_for(height_cm: int, weight_lb: int) -> Dictionary:
	var mass := (float(weight_lb) / float(height_cm)) / REF_LB_PER_CM
	var frame := lerpf(0.90, 1.0, clampf((weight_lb - 130.0) / 24.0, 0.0, 1.0))
	# Up to a well-toned heavyweight (mass ~1.25) the body widens quickly;
	# beyond that, extra weight adds width much more gently so the biggest men
	# look heavy rather than obese.
	var widen := _soft_cap(mass, TONED_MASS, 0.50)
	var bulk := clampf(pow(widen, 1.2) * frame, 0.78, 1.60)
	return {
		"bulk": bulk,
		"limb": clampf(_soft_cap(mass, TONED_MASS, 0.45) * frame, 0.80, 1.42),
		"neck": clampf(pow(bulk, 1.2), 0.78, 1.70),
		"belly": clampf((mass - 1.55) / 0.40, 0.0, 0.7),
		"lean": weight_lb < 145,
	}


## Above [param knee], only [param rate] of any further increase counts.
static func _soft_cap(value: float, knee: float, rate: float) -> float:
	return value if value <= knee else knee + (value - knee) * rate


## Computes every joint for [param pose] at pixel height [param h].
## Returns a Dictionary of Vector2 positions in local pixels (origin = floor
## between the feet, y down) plus a few angles the renderer needs.
static func solve(pose: Dictionary, h: float, bulk: float) -> Dictionary:
	var j := {}
	var lift: float = pose["lift"] * h

	# Torso ----------------------------------------------------------------------
	var hip := Vector2(pose["hip"].x * h, -pose["hip"].y * h - lift)
	var lean := deg_to_rad(pose["lean"])
	var spine := Vector2(sin(lean), -cos(lean))   # hip -> neck
	var fwd := Vector2(cos(lean), sin(lean))      # chest direction
	var neck := hip + spine * TORSO * h

	# Head -----------------------------------------------------------------------
	var head_angle := deg_to_rad(pose["lean"] + pose["head"])
	var head_up := Vector2(sin(head_angle), -cos(head_angle))
	var head := neck + head_up * (NECK + HEAD * 0.5) * h

	# Shoulders: the lead shoulder sits forward, the rear one back. ---------------
	# "twist" turns the torso into a rear-hand punch, bringing that shoulder forward.
	var twist: float = pose["twist"]
	var sh_lead := neck - spine * 0.030 * h + fwd * (0.045 - 0.020 * twist) * h * bulk
	var sh_rear := neck - spine * 0.040 * h + fwd * (-0.040 + 0.090 * twist) * h * bulk

	# Arms (targets are relative to each shoulder, y up). ------------------------
	var lead_target: Vector2 = sh_lead + _flip(pose["lead_hand"]) * h
	var rear_target: Vector2 = sh_rear + _flip(pose["rear_hand"]) * h
	var lead_arm := _ik(sh_lead, lead_target, UPPER_ARM * h, FOREARM * h, pose["lead_bend"])
	var rear_arm := _ik(sh_rear, rear_target, UPPER_ARM * h, FOREARM * h, pose["rear_bend"])

	# Hips and legs. The pelvis only follows half of the torso lean. -------------
	var pelvis_angle := lean * 0.5
	var pelvis := Vector2(cos(pelvis_angle), sin(pelvis_angle)) * 0.035 * h * bulk
	var hip_lead := hip + pelvis
	var hip_rear := hip - pelvis
	var ankle_lead := Vector2(pose["lead_foot"].x * h, -pose["lead_foot"].y * h - lift)
	var ankle_rear := Vector2(pose["rear_foot"].x * h, -pose["rear_foot"].y * h - lift)
	# Knees always bend towards the boxer's front (-1 = rotate anticlockwise).
	var lead_leg := _ik(hip_lead, ankle_lead, THIGH * h, SHIN * h, -1.0)
	var rear_leg := _ik(hip_rear, ankle_rear, THIGH * h, SHIN * h, -1.0)

	j["hip"] = hip
	j["neck"] = neck
	j["head"] = head
	j["head_angle"] = head_angle
	j["lean"] = lean
	j["spine"] = spine
	j["fwd"] = fwd
	j["sh_lead"] = sh_lead
	j["sh_rear"] = sh_rear
	j["elbow_lead"] = lead_arm[0]
	j["glove_lead"] = lead_arm[1]
	j["elbow_rear"] = rear_arm[0]
	j["glove_rear"] = rear_arm[1]
	j["hip_lead"] = hip_lead
	j["hip_rear"] = hip_rear
	j["knee_lead"] = lead_leg[0]
	j["ankle_lead"] = lead_leg[1]
	j["knee_rear"] = rear_leg[0]
	j["ankle_rear"] = rear_leg[1]
	return j


## Two-bone IK. Returns [middle_joint, end_point]. [param side] picks which of
## the two possible bends to use (+1 = clockwise on screen, e.g. elbow down
## when punching forward).
static func _ik(root: Vector2, target: Vector2, len_a: float, len_b: float, side: float) -> Array:
	var to_target := target - root
	var dist := clampf(to_target.length(), absf(len_a - len_b) + 0.01, len_a + len_b - 0.01)
	var dir := to_target.normalized() if to_target.length() > 0.001 else Vector2.DOWN
	var end := root + dir * dist
	var cos_a := (len_a * len_a + dist * dist - len_b * len_b) / (2.0 * len_a * dist)
	var angle := acos(clampf(cos_a, -1.0, 1.0))
	var middle := root + dir.rotated(angle * signf(side)) * len_a
	return [middle, end]


## Converts a "y up" authoring vector into a "y down" screen vector.
static func _flip(v: Vector2) -> Vector2:
	return Vector2(v.x, -v.y)
