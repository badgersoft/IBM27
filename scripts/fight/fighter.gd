class_name Fighter
extends RefCounted
## One boxer's live state during a fight: where he is, how hurt and tired he
## is, and what he is doing right now.
##
## Fighter only stores state and answers questions about it. The rules of the
## fight (what happens when a punch lands) live in FightSim, and decisions
## (what to do next) live in BoxerAI.

enum State {
	CORNER,        ## Resting in the corner (before the fight / between rounds).
	IDLE,          ## Standing in his fighting stance.
	MOVE,          ## Stepping forward or back.
	GUARD,         ## Gloves up covering the face.
	PUNCH,         ## Throwing a punch.
	HURT,          ## Rocked back by a punch.
	ROPES,         ## Bouncing off the ropes.
	CLINCH,        ## Holding on.
	DOWN,          ## On the canvas.
	KNEEL,         ## Up on one knee during the count.
	RISING,        ## Getting back to his feet.
	NEUTRAL,       ## Waiting out the count in a neutral spot.
	WALK_CORNER,   ## Walking back to the corner after the bell.
	CELEBRATE,     ## Won the fight.
	DEJECTED,      ## Lost the fight.
	TAUNT,         ## Showboating.
}

## States in which the AI is allowed to choose a new action.
const FREE_STATES: Array[State] = [State.IDLE, State.MOVE, State.GUARD]

## Trainer instructions given between rounds.
enum Advice { NONE, ATTACK_MORE, DEFEND_MORE, KEEP_IT_UP, ALL_OUT }
const ADVICE_TEXT: Array[String] = ["", "ATTACK MORE!", "DEFEND MORE!", "KEEP IT UP!", "GO ALL OUT!"]

const MAX_HEALTH := 100.0
const MAX_ENERGY := 100.0
## Footwork speed multiplier while walking out of the corner at the bell.
const COME_OUT_SPEED := 1.8

var data: BoxerData
var corner := 0
var facing := 1                 ## +1 faces right (red corner), -1 faces left.
var height_px := 80.0
var x := 0.0

# --- Condition ----------------------------------------------------------------
var health := 90.0
var energy := MAX_ENERGY
var stun := 0.0                 ## 0 - 100 "rocked" meter, fades quickly.
var wear := 0.0                 ## 0 - 1 how much punishment has drained his skills.

# --- Current action -----------------------------------------------------------
var state: State = State.CORNER
var state_time := 0.0           ## Seconds spent in the current state.
var state_length := 0.0         ## How long the current state should last.
var move_dir := 0               ## +1 towards the opponent, -1 away (MOVE state).
var punch_type := 0
var punch_impact := 0.0         ## Seconds into PUNCH when the glove lands.
var punch_resolved := false
var combo: Array[int] = []      ## Follow-up punches queued by the AI.

# --- Animation request (read by the renderer) -----------------------------------
var anim := "relaxed"
var anim_scale := 1.0
var anim_serial := 0            ## Bumped to force the same animation to restart.

# --- AI memory ------------------------------------------------------------------
var think_timer := 0.0
var clinch_cooldown := 0.0
var taunt_cooldown := 8.0
var reset_timer := 0.0          ## Boxer style: time left backing off after a combo.
var counter_window := 0.0       ## Time left to punish an opponent's miss.
var streak := 0                 ## Clean punches landed in a row (feeds big punches).
var idle_time := 0.0            ## Seconds since he last threw a punch.
var celebrates_knockdown := false ## Showboating over the man he has just put down.
var coming_out := false         ## Walking briskly out of his corner at the bell.
## Between rounds: health and energy when he reached the corner (x, y), where
## the corner will get them (x, y), and seconds spent sitting down.
var corner_from := Vector2.ZERO
var corner_to := Vector2.ZERO
var corner_time := 0.0
var one_two := false            ## The jab in the air is the first half of a one-two.
var one_two_window := 0.0       ## Time left for the cross after a one-two jab landed.
var advice: Advice = Advice.NONE

# --- Knockdowns -----------------------------------------------------------------
var knockdowns_round := 0
var knockdowns_total := 0
var getup_count := 0            ## Count at which he will be up (99 = not getting up).

# --- Stats for the judges and the end-of-fight screen -----------------------
var round_stats := {}
var fight_stats := {}


func _init(boxer: BoxerData, corner_index: int) -> void:
	data = boxer
	corner = corner_index
	facing = 1 if corner_index == 0 else -1
	height_px = BoxerSkeleton.pixel_height(boxer.height_cm)
	health = boxer.start_health
	round_stats = _empty_stats()
	fight_stats = _empty_stats()


static func _empty_stats() -> Dictionary:
	return {
		"thrown": 0,         # Punches thrown.
		"landed": 0,         # Punches that landed clean.
		"power_landed": 0,   # Clean non-jab punches.
		"blocked": 0,        # Punches that hit the gloves.
		"big": 0,            # Big punches landed (the rare, huge ones).
		"significant": 0,    # Significant strikes: hard clean shots that hurt.
		"one_twos": 0,       # One-twos landed (the jab and the cross both clean).
		"score": 0.0,        # Judges' "clean punching" points.
		"damage": 0.0,       # Health damage dealt.
		"pressure": 0.0,     # Seconds spent coming forward.
		"evaded": 0,         # Opponent punches slipped or blocked.
	}


## Adds to both this round's and the whole fight's stats.
func add_stat(key: String, amount: float) -> void:
	round_stats[key] += amount
	fight_stats[key] += amount


func reset_round_stats() -> void:
	round_stats = _empty_stats()
	knockdowns_round = 0


# ----------------------------------------------------------------------------
#  Derived values
# ----------------------------------------------------------------------------

## 0 = fresh, 1 = exhausted.
func fatigue() -> float:
	return 1.0 - energy / MAX_ENERGY


## A skill after tiredness and punishment are taken into account.
## Stamina never drops - it is what controls how fast the others drop.
func skill(skill_name: String) -> float:
	var base := float(data.get(skill_name))
	if skill_name == "stamina":
		return base
	var tired := lerpf(1.0, 0.62, fatigue())
	var worn := 1.0 - wear * 0.35
	return base * tired * worn


## 0 = fine, 1 = badly hurt. Combines being rocked with low health.
func hurt_level() -> float:
	var low_health := maxf(0.0, 0.40 - health / MAX_HEALTH) * 2.0
	return clampf(stun / 100.0 + low_health, 0.0, 1.0)


func is_free() -> bool:
	return state in FREE_STATES


func is_down() -> bool:
	return state == State.DOWN or state == State.KNEEL


## Seconds-long multiplier for animations: fast, fresh boxers punch quicker.
func punch_duration_scale() -> float:
	return lerpf(1.30, 0.80, skill("speed") / 99.0) * _division_speed()


## Footwork speed in arena pixels per second.
func move_speed() -> float:
	var walk_out := COME_OUT_SPEED if coming_out else 1.0
	return lerpf(16.0, 28.0, skill("speed") / 99.0) * (0.75 + 0.25 * (1.0 - fatigue())) / _division_speed() * walk_out


## Heavier divisions move and punch a little slower, lighter ones quicker.
func _division_speed() -> float:
	return Divisions.get_division(data.division)["speed_scale"]


## Multiplier on energy use: high stamina boxers tire slower.
func energy_drain_scale() -> float:
	return lerpf(1.40, 0.55, data.stamina / 99.0)


## Pixel reach of a punch from this boxer's centre.
func reach_px(type: int) -> float:
	return PunchTypes.reach(type) * height_px


# ----------------------------------------------------------------------------
#  State changes
# ----------------------------------------------------------------------------

## Switches state and asks for an animation. [param length] is how long the
## state lasts (0 = until something else changes it).
func set_state(new_state: State, anim_name: String, length: float = 0.0, scale: float = 1.0) -> void:
	state = new_state
	state_time = 0.0
	state_length = length
	play(anim_name, scale, true)


func play(anim_name: String, scale: float = 1.0, restart: bool = false) -> void:
	if anim_name != anim or restart:
		anim_serial += 1
	anim = anim_name
	anim_scale = scale


## Starts throwing [param type].
func start_punch(type: int) -> void:
	var scale := punch_duration_scale()
	var anim_name: String = PunchTypes.ANIMS[type]
	punch_type = type
	punch_resolved = false
	punch_impact = BoxerPoses.impact_time(anim_name, scale)
	set_state(State.PUNCH, anim_name, BoxerPoses.length(anim_name, scale), scale)
	var cost := PunchTypes.ENERGY_COST[type] * energy_drain_scale()
	if advice == Advice.ALL_OUT:
		cost *= 1.25
	spend_energy(cost)
	add_stat("thrown", 1)
	idle_time = 0.0


func spend_energy(amount: float) -> void:
	energy = clampf(energy - amount, 5.0, MAX_ENERGY)
