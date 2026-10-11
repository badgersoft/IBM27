class_name BoxerPoses
extends RefCounted
## The pose and animation library shared by every boxer.
##
## A POSE is a small Dictionary of numbers (see BASE_POSE for the full list).
## All values are in "body heights" with y pointing UP, and hands are measured
## from their own shoulder. Most poses only list what differs from STANCE.
##
## An ANIMATION is a list of [pose_name, seconds] steps. Each step means "move
## from wherever you are now to this pose over this many seconds", so an
## animation always blends smoothly out of whatever the boxer was doing before.
##   loop   - start again from the first step when the last one finishes.
##   impact - (punches only) index of the step that ends with the glove landing.
##   hand   - (punches only) "lead" or "rear", the glove that does the damage.
##
## The fight logic reads impact_time() so damage is applied on exactly the frame
## where the glove is drawn fully extended.

## Every key a pose can contain, with its default value.
const BASE_POSE := {
	"hip":       Vector2(0.00, 0.455),  ## Hip joint position (x forward, height).
	"lean":      6.0,                   ## Torso lean in degrees (+ = forward).
	"head":      4.0,                   ## Extra head tilt in degrees (+ = chin down).
	"lead_hand": Vector2(0.13, 0.11),   ## Lead glove, relative to lead shoulder.
	"rear_hand": Vector2(0.16, 0.13),   ## Rear glove, relative to rear shoulder.
	"lead_bend": 1.0,                   ## +1 elbow below the arm, -1 elbow above.
	"rear_bend": 1.0,
	"lead_foot": Vector2(0.12, 0.02),   ## Ankle positions (x, height).
	"rear_foot": Vector2(-0.13, 0.02),
	"lift":      0.0,                   ## Whole body raised off the floor (skipping).
	"twist":     0.0,                   ## Torso rotation into a rear-hand punch (0 - 1).
}

## Pose overrides, applied on top of BASE_POSE (or on top of "base" if given).
const POSE_DEFS := {
	# --- Standing -------------------------------------------------------------
	"stance":       {},
	"stance_b":     {"hip": Vector2(0.00, 0.445), "lead_hand": Vector2(0.13, 0.10)},
	"guard":        {"hip": Vector2(0.00, 0.445), "lean": 10.0, "head": 14.0,
					 "lead_hand": Vector2(0.10, 0.17), "rear_hand": Vector2(0.14, 0.17)},
	"guard_b":      {"base": "guard", "hip": Vector2(0.00, 0.437)},
	"ready":        {"hip": Vector2(0.00, 0.465), "lean": 3.0, "head": 2.0,
					 "lead_hand": Vector2(0.13, -0.08), "rear_hand": Vector2(0.15, -0.06)},
	"ready_b":      {"base": "ready", "hip": Vector2(0.00, 0.458)},
	"relaxed":      {"hip": Vector2(0.00, 0.485), "lean": 0.0, "head": 0.0,
					 "lead_hand": Vector2(0.03, -0.31), "rear_hand": Vector2(-0.01, -0.31),
					 "lead_foot": Vector2(0.06, 0.02), "rear_foot": Vector2(-0.06, 0.02)},
	"relaxed_b":    {"base": "relaxed", "hip": Vector2(0.00, 0.480), "lead_hand": Vector2(0.04, -0.31)},
	"dejected":     {"base": "relaxed", "lean": 6.0, "head": 28.0},

	# --- Footwork ---------------------------------------------------------------
	"step_f1":      {"hip": Vector2(0.02, 0.450), "lead_foot": Vector2(0.19, 0.035)},
	"step_f2":      {"hip": Vector2(0.01, 0.455), "lead_foot": Vector2(0.13, 0.02), "rear_foot": Vector2(-0.07, 0.03)},
	"step_b1":      {"hip": Vector2(-0.02, 0.450), "rear_foot": Vector2(-0.20, 0.035)},
	"step_b2":      {"hip": Vector2(-0.01, 0.455), "lead_foot": Vector2(0.07, 0.03), "rear_foot": Vector2(-0.14, 0.02)},

	# --- Punches ------------------------------------------------------------------
	"jab_wind":     {"lean": 7.0, "lead_hand": Vector2(0.09, 0.11)},
	"jab_hit":      {"hip": Vector2(0.02, 0.455), "lean": 12.0, "head": 6.0,
					 "lead_hand": Vector2(0.34, 0.08), "lead_foot": Vector2(0.15, 0.02)},
	"cross_wind":   {"hip": Vector2(-0.01, 0.455), "lean": 3.0, "rear_hand": Vector2(0.10, 0.11)},
	"cross_hit":    {"hip": Vector2(0.05, 0.450), "lean": 22.0, "head": 8.0, "twist": 1.0,
					 "rear_hand": Vector2(0.42, 0.07), "lead_hand": Vector2(0.08, 0.13),
					 "rear_foot": Vector2(-0.10, 0.045)},
	"hook_wind":    {"hip": Vector2(-0.01, 0.450), "lean": 2.0, "head": 6.0,
					 "lead_hand": Vector2(0.00, 0.06)},
	"hook_hit":     {"hip": Vector2(0.03, 0.450), "lean": 16.0, "head": 8.0,
					 "lead_hand": Vector2(0.28, 0.05), "lead_bend": -1.0},
	"upper_wind":   {"hip": Vector2(0.00, 0.410), "lean": 4.0, "head": 8.0,
					 "rear_hand": Vector2(0.07, -0.14)},
	"upper_hit":    {"hip": Vector2(0.03, 0.470), "lean": 6.0, "head": 0.0, "twist": 0.8,
					 "rear_hand": Vector2(0.19, 0.22), "rear_foot": Vector2(-0.11, 0.03)},
	"body_wind":    {"hip": Vector2(0.00, 0.420), "lean": 16.0, "rear_hand": Vector2(0.07, 0.02)},
	"body_hit":     {"hip": Vector2(0.04, 0.395), "lean": 28.0, "head": 6.0, "twist": 0.8,
					 "rear_hand": Vector2(0.38, -0.10), "lead_hand": Vector2(0.09, 0.16)},

	# --- Taking punches ---------------------------------------------------------
	"hurt":         {"hip": Vector2(-0.03, 0.455), "lean": -14.0, "head": -24.0,
					 "lead_hand": Vector2(0.13, 0.03), "rear_hand": Vector2(0.12, 0.05)},
	"hurt_body":    {"hip": Vector2(-0.01, 0.430), "lean": 26.0, "head": 12.0,
					 "lead_hand": Vector2(0.08, -0.04), "rear_hand": Vector2(0.07, -0.02)},
	"kd_stagger":   {"hip": Vector2(-0.04, 0.440), "lean": -26.0, "head": -26.0,
					 "lead_hand": Vector2(0.06, 0.20), "rear_hand": Vector2(-0.04, 0.22),
					 "lead_foot": Vector2(0.14, 0.02), "rear_foot": Vector2(-0.12, 0.02)},
	"kd_fall":      {"hip": Vector2(-0.12, 0.240), "lean": -55.0, "head": -10.0,
					 "lead_hand": Vector2(-0.06, 0.18), "rear_hand": Vector2(-0.10, 0.14),
					 "lead_foot": Vector2(0.16, 0.02), "rear_foot": Vector2(0.02, 0.02)},
	"kd_floor":     {"hip": Vector2(-0.16, 0.070), "lean": -86.0, "head": -6.0,
					 "lead_hand": Vector2(0.06, -0.06), "rear_hand": Vector2(-0.20, 0.00),
					 "lead_foot": Vector2(0.30, 0.040), "rear_foot": Vector2(0.25, 0.02)},
	"kneel":        {"hip": Vector2(0.00, 0.275), "lean": 16.0, "head": 18.0,
					 "lead_hand": Vector2(0.13, -0.27), "rear_hand": Vector2(0.02, -0.27),
					 "lead_foot": Vector2(0.20, 0.02), "rear_foot": Vector2(-0.27, 0.03)},
	"ropes_back":   {"hip": Vector2(-0.06, 0.450), "lean": -30.0, "head": -16.0,
					 "lead_hand": Vector2(-0.10, 0.10), "rear_hand": Vector2(-0.20, 0.06),
					 "rear_foot": Vector2(-0.10, 0.02)},
	"ropes_spring": {"hip": Vector2(0.04, 0.450), "lean": 18.0, "head": 6.0,
					 "lead_hand": Vector2(0.15, 0.06), "rear_hand": Vector2(0.12, 0.09)},
	"clinch":       {"hip": Vector2(0.04, 0.440), "lean": 30.0, "head": 22.0,
					 "lead_hand": Vector2(0.22, -0.04), "rear_hand": Vector2(0.24, 0.00)},

	# --- Showboating --------------------------------------------------------------
	"skip_a":       {"hip": Vector2(0.00, 0.470), "lean": -4.0, "head": -10.0,
					 "lead_hand": Vector2(0.05, 0.30), "rear_hand": Vector2(-0.03, 0.30),
					 "lead_foot": Vector2(0.07, 0.07), "rear_foot": Vector2(-0.07, 0.02), "lift": 0.03},
	"skip_b":       {"base": "skip_a", "lead_foot": Vector2(0.07, 0.02), "lift": 0.0},
	"skip_c":       {"base": "skip_a", "lead_foot": Vector2(0.07, 0.02), "rear_foot": Vector2(-0.07, 0.07)},
	"taunt_one":    {"hip": Vector2(0.00, 0.470), "lean": -6.0, "head": -14.0,
					 "lead_hand": Vector2(0.07, 0.31), "rear_hand": Vector2(0.12, -0.04),
					 "lead_foot": Vector2(0.09, 0.02), "rear_foot": Vector2(-0.09, 0.02)},
	"taunt_one_b":  {"base": "taunt_one", "lead_hand": Vector2(0.09, 0.30), "hip": Vector2(0.00, 0.462)},
	"victory_a":    {"hip": Vector2(0.00, 0.480), "lean": -5.0, "head": -14.0,
					 "lead_hand": Vector2(0.10, 0.30), "rear_hand": Vector2(-0.06, 0.30),
					 "lead_foot": Vector2(0.08, 0.02), "rear_foot": Vector2(-0.08, 0.02)},
	"victory_b":    {"base": "victory_a", "lift": 0.02, "lead_hand": Vector2(0.12, 0.30)},
}

## Animations. See the notes at the top of this file.
const ANIMS := {
	# Idles ------------------------------------------------------------------------
	"stance":       {"loop": true,  "steps": [["stance", 0.12], ["stance_b", 0.40], ["stance", 0.40]]},
	"guard":        {"loop": true,  "steps": [["guard", 0.08], ["guard_b", 0.40], ["guard", 0.40]]},
	"ready":        {"loop": true,  "steps": [["ready", 0.15], ["ready_b", 0.50], ["ready", 0.50]]},
	"relaxed":      {"loop": true,  "steps": [["relaxed", 0.25], ["relaxed_b", 0.60], ["relaxed", 0.60]]},
	"dejected":     {"loop": false, "steps": [["dejected", 0.40]]},

	# Footwork ---------------------------------------------------------------------
	"move_forward": {"loop": true,  "steps": [["step_f1", 0.12], ["step_f2", 0.12], ["stance", 0.10]]},
	"move_back":    {"loop": true,  "steps": [["step_b1", 0.12], ["step_b2", 0.12], ["stance", 0.10]]},

	# Punches (impact = step that ends with the glove on target) -----------------
	"jab":          {"loop": false, "impact": 1, "hand": "lead", "steps": [["jab_wind", 0.07], ["jab_hit", 0.08], ["jab_hit", 0.05], ["stance", 0.14]]},
	"cross":        {"loop": false, "impact": 1, "hand": "rear", "steps": [["cross_wind", 0.09], ["cross_hit", 0.10], ["cross_hit", 0.06], ["stance", 0.18]]},
	"hook":         {"loop": false, "impact": 1, "hand": "lead", "steps": [["hook_wind", 0.10], ["hook_hit", 0.10], ["hook_hit", 0.06], ["stance", 0.20]]},
	"uppercut":     {"loop": false, "impact": 1, "hand": "rear", "steps": [["upper_wind", 0.12], ["upper_hit", 0.10], ["upper_hit", 0.07], ["stance", 0.20]]},
	"body":         {"loop": false, "impact": 1, "hand": "rear", "steps": [["body_wind", 0.10], ["body_hit", 0.10], ["body_hit", 0.06], ["stance", 0.18]]},

	# Reactions -----------------------------------------------------------------------
	"hurt":         {"loop": false, "steps": [["hurt", 0.07], ["hurt", 0.12], ["stance", 0.18]]},
	"hurt_body":    {"loop": false, "steps": [["hurt_body", 0.08], ["hurt_body", 0.15], ["stance", 0.20]]},
	"knockdown":    {"loop": false, "steps": [["kd_stagger", 0.12], ["kd_fall", 0.18], ["kd_floor", 0.16]]},
	"to_knee":      {"loop": false, "steps": [["kneel", 0.60]]},
	"stand_up":     {"loop": false, "steps": [["ready", 0.50], ["stance", 0.20]]},
	"ropes":        {"loop": false, "steps": [["ropes_back", 0.12], ["ropes_back", 0.10], ["ropes_spring", 0.14], ["stance", 0.14]]},
	"clinch":       {"loop": false, "steps": [["clinch", 0.15]]},

	# Showboating -------------------------------------------------------------------
	"taunt_skip":   {"loop": true,  "steps": [["skip_a", 0.14], ["skip_b", 0.14], ["skip_c", 0.14], ["skip_b", 0.14]]},
	"taunt_one":    {"loop": true,  "steps": [["taunt_one", 0.20], ["taunt_one_b", 0.40], ["taunt_one", 0.40]]},
	"victory":      {"loop": true,  "steps": [["victory_a", 0.25], ["victory_b", 0.30], ["victory_a", 0.30]]},
}

static var _cache: Dictionary = {}


## Returns the fully expanded pose called [param pose_name].
static func get_pose(pose_name: String) -> Dictionary:
	if _cache.has(pose_name):
		return _cache[pose_name]
	if not POSE_DEFS.has(pose_name):
		push_error("BoxerPoses: unknown pose '%s'" % pose_name)
		return BASE_POSE
	var def: Dictionary = POSE_DEFS[pose_name]
	var pose: Dictionary = (get_pose(def["base"]) if def.has("base") else BASE_POSE).duplicate()
	for key in def:
		if key != "base":
			pose[key] = def[key]
	_cache[pose_name] = pose
	return pose


static func has_anim(anim_name: String) -> bool:
	return ANIMS.has(anim_name)


## Total length of one pass through an animation, in seconds.
static func length(anim_name: String, duration_scale: float = 1.0) -> float:
	var total := 0.0
	for step in ANIMS[anim_name]["steps"]:
		total += step[1]
	return total * duration_scale


## Seconds from the start of a punch animation until the glove lands.
static func impact_time(anim_name: String, duration_scale: float = 1.0) -> float:
	var anim: Dictionary = ANIMS[anim_name]
	var total := 0.0
	for i in int(anim.get("impact", 0)) + 1:
		total += anim["steps"][i][1]
	return total * duration_scale


## Blends two poses. Bend directions cannot be blended so they switch half way.
static func blend(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key in BASE_POSE:
		var va: Variant = a[key]
		var vb: Variant = b[key]
		if key.ends_with("_bend"):
			out[key] = vb if t >= 0.5 else va
		elif va is Vector2:
			out[key] = (va as Vector2).lerp(vb, t)
		else:
			out[key] = lerpf(va, vb, t)
	return out


## How far in front of a boxer's centre the glove reaches at the impact pose,
## in body heights (glove edge included). Used by the fight logic for range.
static func reach(anim_name: String) -> float:
	var anim: Dictionary = ANIMS[anim_name]
	var pose := get_pose(anim["steps"][int(anim.get("impact", 0))][0])
	var j := BoxerSkeleton.solve(pose, 1.0, 1.0)
	var glove: Vector2 = j["glove_" + str(anim.get("hand", "lead"))]
	return glove.x + BoxerSkeleton.GLOVE_R
