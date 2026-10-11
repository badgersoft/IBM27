class_name Ceremony
extends Node2D
## The end of the fight, face-on: both boxers stand either side of the
## referee, who holds each man by the wrist while the verdict is read out, then
## lifts the winner's arm (both arms for a draw).
##
## The node's origin is the floor point under the referee. Red stands on the
## left of the screen, blue on the right, as in the fight.

## Seconds the referee takes to lift an arm.
const RAISE_TIME := 0.5
const ANIM_FPS := 20.0
## Clear space between the referee's shoulders and a boxer's hands.
const GAP := 5.0
## Reach used when holding or lifting an arm (a little short of straight).
const REACH := 0.96

var boxers: Array[FrontRig] = []
var referee: FrontRig

var _raised: Array[bool] = [false, false]
var _progress: Array[float] = [0.0, 0.0]
var _winner := -2                # -2 = not announced, -1 = draw, 0 / 1 = corner.


## Builds the group. [param ref_skin] picks the referee's skin tone.
func setup(red: BoxerData, blue: BoxerData, ref_skin: int) -> void:
	for child in get_children():
		child.queue_free()
	boxers.clear()
	referee = FrontRig.new()
	referee.setup_referee(ref_skin)
	var data := [red, blue]
	for corner in 2:
		var rig := FrontRig.new()
		rig.setup_boxer(data[corner], corner, true)
		var out := -1.0 if corner == 0 else 1.0
		var ref_half := FrontRig.SHOULDER_X * 0.92 * referee.pixel_height()
		rig.position.x = roundf(out * (ref_half + GAP + rig.half_width()))
		add_child(rig)
		boxers.append(rig)
	add_child(referee)          # In front, so his hands close over the wrists.
	_update_arms()


## Reads out the verdict: lifts [param winner]'s arm, or both for a draw (-1).
func raise(winner: int) -> void:
	_winner = winner
	for corner in 2:
		_raised[corner] = winner < 0 or winner == corner
		boxers[corner].bow = 0.0 if _raised[corner] or winner < 0 else 1.0
		boxers[corner].shout = _raised[corner] and winner >= 0


## Jumps to the end of the lift (used by the screenshot tool).
func finish_raise() -> void:
	for corner in 2:
		_progress[corner] = 1.0 if _raised[corner] else 0.0
	_update_arms()


func _process(delta: float) -> void:
	var moving := false
	for corner in 2:
		var goal := 1.0 if _raised[corner] else 0.0
		if _progress[corner] != goal:
			_progress[corner] = move_toward(_progress[corner], goal, delta / RAISE_TIME)
			moving = true
	if moving:
		_update_arms()


## Places every hand. Each boxer's inner hand is held by the referee: down
## at his side while the cards are read, then lifted straight up. A tall
## man's raised wrist is out of the referee's reach, so then he holds the
## forearm as high as he can.
func _update_arms() -> void:
	var ref_reach := referee.arm_length() * REACH
	for corner in 2:
		var rig := boxers[corner]
		var inner := 1 if corner == 0 else 0          # The arm nearest the referee.
		var out := -1.0 if corner == 0 else 1.0
		var ref_side := corner                        # Referee's arm on that side.
		var ref_sh := referee.position + referee.shoulder(ref_side)
		var h := rig.pixel_height()

		# Down: the hand hangs at his side, drawn in a touch towards the
		# referee and never further away than the referee can reach.
		var down := rig.position + rig.rest_hand(inner) - Vector2(out * 2.0, 0.0)
		down = ref_sh + (down - ref_sh).limit_length(ref_reach)
		# Up: straight up over his shoulder, leaning a little towards the referee.
		var up := rig.position + rig.shoulder(inner) + Vector2(-out * 0.04 * h, -rig.arm_length())

		var k := floorf(smoothstep(0.0, 1.0, _progress[corner]) * RAISE_TIME * ANIM_FPS) / (RAISE_TIME * ANIM_FPS)
		rig.hand_target[inner] = down.lerp(up, k) - rig.position
		rig.solve()

		referee.hand_target[ref_side] = _grip(rig, inner, ref_sh, ref_reach) - referee.position
	referee.solve()


## The highest point on [param rig]'s forearm, from the wrist down towards the
## elbow, that the referee can reach (in Ceremony coordinates).
func _grip(rig: FrontRig, side: int, ref_sh: Vector2, reach: float) -> Vector2:
	var wrist := rig.position + rig.wrist(side)
	var elbow := rig.position + rig.elbow(side)
	for i in 11:
		var p := wrist.lerp(elbow, i / 10.0)
		if p.distance_to(ref_sh) <= reach:
			return p
	return ref_sh + (wrist - ref_sh).limit_length(reach)
