class_name BoxerAI
extends RefCounted
## Decides what a boxer does next. There is no human player in this build, so
## both corners are run by this class.
##
## Every "think" the boxer weighs up, in order:
##   1. Is a punch coming at me? (defend, slip back, or set up a counter)
##   2. Am I badly hurt? (cover up, back off, or hold on)
##   3. Is there an opening? (pick a punch that suits my style and the range)
##   4. Am I at my favourite distance? (step in or step out)
##
## Style decides the favourite distance and punch choice (and, for a
## showboat, how often he drops his hands and plays to the crowd).
## Intelligence decides
## how often the boxer makes the sensible choice. Speed decides how often he
## gets to think at all.

const Style := BoxerData.Style
const State := Fighter.State
const Advice := Fighter.Advice
const P := PunchTypes.Type

## How keen each style is to attack (0 - 1). Order matches BoxerData.Style.
const BASE_AGGRESSION: Array[float] = [0.62, 0.72, 0.52, 0.34, 0.30, 0.50]

## Favourite distance from the opponent, in body heights.
const PREFERRED_RANGE: Array[float] = [0.48, 0.40, 0.52, 0.62, 0.68, 0.56]

## Punch preferences per style: JAB, CROSS, HOOK, UPPERCUT, BODY.
const PUNCH_WEIGHTS: Array = [
	[0.25, 0.30, 0.22, 0.10, 0.13],   # Brawler
	[0.10, 0.25, 0.30, 0.20, 0.15],   # Slugger
	[0.45, 0.30, 0.10, 0.05, 0.10],   # Boxer
	[0.22, 0.38, 0.20, 0.10, 0.10],   # Counter
	[0.60, 0.25, 0.05, 0.02, 0.08],   # Evasive
	[0.30, 0.28, 0.20, 0.14, 0.08],   # Showboat
]

## Showboats: how long between taunts, how often a quiet moment becomes one,
## and how often they drop their hands when settling.
const SHOWBOAT_TAUNT_COOLDOWN := 6.0
const SHOWBOAT_TAUNT_CHANCE := 0.35
const SHOWBOAT_HANDS_DOWN := 0.45

## A boxer who has not thrown for a while edges closer, so two cautious
## styles (say a counter-puncher and an evasive boxer, who both like to stay
## out of range) still end up fighting: after IDLE_BEFORE_CLOSING seconds his
## favourite distance shrinks by CLOSE_IN_RATE body heights a second, up to
## MAX_CLOSE_IN.
const IDLE_BEFORE_CLOSING := 2.0
const CLOSE_IN_RATE := 0.05
const MAX_CLOSE_IN := 0.22

## Natural follow-ups when a boxer is quick-witted enough to combine punches.
const COMBOS := {
	P.JAB:      [P.JAB, P.CROSS],
	P.CROSS:    [P.HOOK, P.BODY],
	P.HOOK:     [P.UPPERCUT, P.CROSS],
	P.UPPERCUT: [P.HOOK],
	P.BODY:     [P.HOOK],
}

var rng: RandomNumberGenerator


func _init(random: RandomNumberGenerator) -> void:
	rng = random


## Called by FightSim every frame for a boxer who is free to act.
func think(me: Fighter, opp: Fighter, round_number: int, dt: float) -> void:
	me.think_timer -= dt
	me.reset_timer = maxf(me.reset_timer - dt, 0.0)
	me.counter_window = maxf(me.counter_window - dt, 0.0)
	me.clinch_cooldown = maxf(me.clinch_cooldown - dt, 0.0)
	me.taunt_cooldown = maxf(me.taunt_cooldown - dt, 0.0)

	# Finish a combination before anything else.
	if not me.combo.is_empty() and me.state != State.PUNCH:
		var next: int = me.combo.pop_front()
		if _in_range(me, opp, next, 1.0):
			me.start_punch(next)
			return
		me.combo.clear()

	if me.think_timer > 0.0:
		return
	me.think_timer = _think_interval(me)

	var intel := me.skill("intelligence") / 99.0
	var dist := absf(opp.x - me.x)
	var hurt := me.hurt_level()

	# 1. Defend against an incoming punch -------------------------------------
	if _punch_incoming(opp, me):
		var react := 0.10 + intel * 0.45 + me.skill("speed") / 99.0 * 0.15 + hurt * 0.15
		if me.advice == Advice.DEFEND_MORE:
			react += 0.10
		if me.data.style == Style.SHOWBOAT:
			react += 0.10   # Quick reactions.
		if rng.randf() < react:
			_defend(me, opp)
			return

	# 2. Badly hurt: survive ---------------------------------------------------------
	if hurt > 0.35:
		var close := dist < me.height_px * 0.50
		var can_hold := opp.state in [State.IDLE, State.MOVE, State.GUARD, State.PUNCH]
		if close and can_hold and me.clinch_cooldown <= 0.0 and rng.randf() < 0.30 + intel * 0.45:
			me.set_state(State.CLINCH, "clinch", 0.0)
			opp.set_state(State.CLINCH, "clinch", 0.0)
			me.clinch_cooldown = 7.0
			return
		if rng.randf() < hurt * (0.4 + intel * 0.5):
			if _can_back_off(me) and dist < me.height_px * 0.70 and rng.randf() < 0.6:
				_move(me, -1, rng.randf_range(0.3, 0.6))
			else:
				me.set_state(State.GUARD, "guard", rng.randf_range(0.4, 0.8))
			return

	# 3. Attack ------------------------------------------------------------------------
	var aggression := _aggression(me, opp, round_number)
	var options := _punches_in_range(me, opp)
	if not options.is_empty():
		var chance := aggression * 1.0
		if me.counter_window > 0.0:
			chance = maxf(chance, 0.55 + intel * 0.35)   # Punish a miss.
		if rng.randf() < chance:
			var type := _choose_punch(me, options)
			me.start_punch(type)
			_maybe_queue_combo(me, type)
			if me.data.style == Style.BOXER or me.data.style == Style.EVASIVE:
				me.reset_timer = rng.randf_range(0.6, 1.2)
			return

	# 4. Footwork ---------------------------------------------------------------------
	var want := _preferred_distance(me, round_number) * me.height_px
	if dist > want + 3.0:
		if rng.randf() < 0.35 + aggression * 0.65:
			_move(me, 1, rng.randf_range(0.2, 0.5))
			return
	elif dist < want - 3.0 and _wants_to_back_off(me, hurt):
		_move(me, -1, rng.randf_range(0.2, 0.45))
		return

	# Opponent hurt and we are ahead and flashy? Showboat for a moment. A
	# showboat does it far more often, hurt opponent or not.
	var showboat := me.data.style == Style.SHOWBOAT
	if me.taunt_cooldown <= 0.0 and dist > me.height_px * 0.6:
		var wants := opp.hurt_level() > 0.5 and rng.randf() < 0.25 * (1.0 - intel * 0.5)
		if showboat:
			wants = opp.hurt_level() > 0.15 or rng.randf() < SHOWBOAT_TAUNT_CHANCE
		if wants:
			var taunt := "taunt_skip" if me.data.style == Style.EVASIVE else "taunt_one"
			if showboat and rng.randf() < 0.5:
				taunt = "taunt_skip"
			me.set_state(State.TAUNT, taunt, rng.randf_range(0.8, 1.4))
			me.taunt_cooldown = SHOWBOAT_TAUNT_COOLDOWN if showboat else 15.0
			return

	_settle(me, opp, hurt)


## Picks the trainer's advice for the next round.
func corner_advice(me: Fighter, my_cards: int, opp_cards: int, next_round: int, last_round: int) -> Advice:
	var behind := my_cards < opp_cards
	var well_ahead := my_cards - opp_cards >= 2
	if next_round == last_round and behind:
		return Advice.ALL_OUT
	if me.health < 35.0:
		return Advice.DEFEND_MORE
	if behind:
		return Advice.ATTACK_MORE
	if well_ahead and me.fatigue() > 0.4:
		return Advice.DEFEND_MORE
	if my_cards == opp_cards:
		return Advice.ATTACK_MORE if rng.randf() < 0.6 else Advice.KEEP_IT_UP
	return Advice.KEEP_IT_UP


# ============================================================================
#  Helpers
# ============================================================================

func _think_interval(me: Fighter) -> float:
	return lerpf(0.36, 0.15, me.skill("speed") / 99.0) * rng.randf_range(0.8, 1.25)


## How keen the boxer is to throw right now (0 - 1).
func _aggression(me: Fighter, opp: Fighter, round_number: int) -> float:
	var intel := me.skill("intelligence") / 99.0
	var a: float = BASE_AGGRESSION[me.data.style]
	if me.data.style == Style.EVASIVE and round_number >= FightSim.ROUNDS:
		a += 0.28   # Evasive boxers save themselves for the last round.
	match me.advice:
		Advice.ATTACK_MORE:
			a += 0.12
		Advice.DEFEND_MORE:
			a -= 0.12
		Advice.ALL_OUT:
			a += 0.25
	# Smell blood when the opponent is hurt (clever boxers notice more).
	a += opp.hurt_level() * (0.15 + intel * 0.35)
	# Hurt boxers ease off - a clever one much more than a reckless one.
	a -= me.hurt_level() * (0.15 + intel * 0.40)
	a -= me.fatigue() * 0.25
	return clampf(a, 0.05, 0.95)


func _preferred_distance(me: Fighter, round_number: int) -> float:
	var d: float = PREFERRED_RANGE[me.data.style]
	if me.data.style == Style.EVASIVE and round_number >= FightSim.ROUNDS:
		d = 0.52
	if me.reset_timer > 0.0:
		d = maxf(d, 0.66)   # Hit and move.
	if me.advice == Advice.ALL_OUT or me.advice == Advice.ATTACK_MORE:
		d -= 0.04
	d -= clampf((me.idle_time - IDLE_BEFORE_CLOSING) * CLOSE_IN_RATE, 0.0, MAX_CLOSE_IN)
	return d


func _wants_to_back_off(me: Fighter, hurt: float) -> bool:
	if not _can_back_off(me):
		return false
	match me.data.style:
		Style.BRAWLER, Style.SLUGGER:
			return hurt > 0.3 or rng.randf() < 0.15
		_:
			return true


## Not worth stepping back if already on the ropes.
func _can_back_off(me: Fighter) -> bool:
	var behind := me.x - me.facing * 6.0
	return behind > ArenaRenderer.RING_MIN_X and behind < ArenaRenderer.RING_MAX_X


func _punch_incoming(opp: Fighter, me: Fighter) -> bool:
	if opp.state != State.PUNCH or opp.punch_resolved:
		return false
	if opp.state_time > opp.punch_impact * 0.8:
		return false   # Too late to react.
	return _in_range(opp, me, opp.punch_type, 1.1)


func _defend(me: Fighter, opp: Fighter) -> void:
	var style := me.data.style
	var step_back_chance := 0.25
	if style == Style.BOXER or style == Style.EVASIVE:
		step_back_chance = 0.65
	elif style == Style.SHOWBOAT:
		step_back_chance = 0.55
	elif style == Style.COUNTER:
		step_back_chance = 0.40
	if _can_back_off(me) and rng.randf() < step_back_chance:
		_move(me, -1, rng.randf_range(0.25, 0.4))
	else:
		me.set_state(State.GUARD, "guard", rng.randf_range(0.35, 0.6))
	if style == Style.COUNTER or rng.randf() < me.skill("intelligence") / 99.0 * 0.4:
		me.counter_window = 0.7


func _move(me: Fighter, dir: int, seconds: float) -> void:
	me.move_dir = dir
	var anim_name := "move_forward" if dir > 0 else "move_back"
	me.set_state(State.MOVE, anim_name, seconds)


## Neutral moment: stance, guard or (when tired, or a showboat) hands dropped.
func _settle(me: Fighter, opp: Fighter, hurt: float) -> void:
	var guard_chance := 0.15 + hurt * 0.5
	if me.data.style == Style.COUNTER or me.advice == Advice.DEFEND_MORE:
		guard_chance += 0.15
	var showboat := me.data.style == Style.SHOWBOAT
	if showboat:
		guard_chance = maxf(guard_chance - 0.10, 0.05)
	var dist := absf(opp.x - me.x)
	if dist < me.height_px * 0.6 and rng.randf() < guard_chance:
		me.set_state(State.GUARD, "guard", rng.randf_range(0.3, 0.7))
	elif me.fatigue() > 0.65 or (showboat and rng.randf() < SHOWBOAT_HANDS_DOWN):
		me.set_state(State.IDLE, "ready", 0.0)
	else:
		me.set_state(State.IDLE, "stance", 0.0)


func _in_range(me: Fighter, opp: Fighter, type: int, slack: float) -> bool:
	var dist := absf(opp.x - me.x)
	return dist <= (me.reach_px(type) + opp.height_px * 0.08) * slack


func _punches_in_range(me: Fighter, opp: Fighter) -> Array[int]:
	var out: Array[int] = []
	for type in PunchTypes.COUNT:
		if _in_range(me, opp, type, 1.0):
			out.append(type)
	return out


func _choose_punch(me: Fighter, options: Array[int]) -> int:
	var weights: Array = PUNCH_WEIGHTS[me.data.style]
	var total := 0.0
	for type in options:
		total += weights[type]
	var roll := rng.randf() * total
	for type in options:
		roll -= weights[type]
		if roll <= 0.0:
			return type
	return options[-1]


func _maybe_queue_combo(me: Fighter, first: int) -> void:
	var skill := (me.skill("intelligence") + me.skill("speed")) / 198.0
	var chance := skill * 0.55
	if me.advice == Advice.ALL_OUT:
		chance += 0.15
	if rng.randf() < chance:
		var follow: Array = COMBOS[first]
		me.combo.append(follow[rng.randi_range(0, follow.size() - 1)])
		if rng.randf() < chance * 0.5:
			me.combo.append(P.CROSS if me.combo[-1] != P.CROSS else P.HOOK)
