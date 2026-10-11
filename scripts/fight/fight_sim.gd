class_name FightSim
extends RefCounted
## Runs a fight: the clock, the bell, punches landing, knockdowns, the count,
## the corners between rounds and the final result.
##
## FightSim knows nothing about drawing. The fight screen calls step() every
## frame and listens to the signals; the headless tools/simulate_fights.gd
## script calls step() in a tight loop to test balance over hundreds of fights.
##
## Time: a round lasts REAL_ROUND_SECONDS of real time but the on-screen clock
## counts down GAME_ROUND_SECONDS, so one real second = three "fight" seconds.

signal bell(strikes: int)
signal round_started(round_number: int)
signal round_ended(round_number: int)
signal punch_landed(corner: int, type: int, damage: float, blocked: bool)
signal punch_missed(corner: int, type: int)
signal knocked_down(corner: int)
signal count_changed(corner: int, count: int)
signal fighter_rose(corner: int)
signal ropes_hit(side: int)
signal corner_advice(corner: int, text: String)
signal fight_finished(result: Dictionary)

enum Phase { INTRO, ROUND, COUNT, BREAK, FINISHED }

const ROUNDS := 3
const REAL_ROUND_SECONDS := 60.0
const GAME_ROUND_SECONDS := 180.0
const CLOCK_SPEED := GAME_ROUND_SECONDS / REAL_ROUND_SECONDS
const BREAK_SECONDS := 10.0           ## Real seconds in the corner between rounds.
const ADVICE_AT := 3.5                ## Seconds into the break when trainers speak.
const COUNT_SECONDS := 1.0            ## Real seconds per number of the count.
const KNOCKDOWNS_FOR_TKO := 3         ## Knockdowns in one round that stop the fight.
const WALK_SPEED := 56.0              ## Pixels per second walking to the corner.
const MIN_GAP := 0.34                 ## Closest the boxers' centres get, in body heights.

## Brawlers and sluggers "don't mind getting hit": less stun and wear per
## shot, and a little extra on their own power punches.
## Order matches BoxerData.Style: Brawler, Slugger, Boxer, Counter, Evasive.
const STYLE_TOUGHNESS: Array[float] = [0.82, 0.85, 1.00, 1.00, 1.00]
const STYLE_POWER:     Array[float] = [1.08, 1.12, 1.00, 1.00, 1.00]

const State := Fighter.State

var red: Fighter
var blue: Fighter
var fighters: Array[Fighter] = []
var judges: Judges
var ai: BoxerAI
var rng := RandomNumberGenerator.new()

var phase: Phase = Phase.INTRO
var round_number := 1
var clock := GAME_ROUND_SECONDS       ## Game seconds left in the round.
var break_time := 0.0
var count_corner := -1                ## Corner of the boxer being counted.
var count_value := 0
var result := {}

var _count_timer := 0.0
var _advice_given := false
var _finish_timer := 0.0


func _init(red_data: BoxerData, blue_data: BoxerData, seed_value: int = -1) -> void:
	if seed_value < 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	red = Fighter.new(red_data, 0)
	blue = Fighter.new(blue_data, 1)
	fighters = [red, blue]
	red.x = ArenaRenderer.CORNER_X[0]
	blue.x = ArenaRenderer.CORNER_X[1]
	for f in fighters:
		f.set_state(State.CORNER, "relaxed")
	judges = Judges.new(ROUNDS, Officials.pick_judges(rng), Officials.pick_pundit(rng), red_data, blue_data, rng)
	ai = BoxerAI.new(rng)


## Rings the first bell. Call once the pre-fight screen is dismissed.
func start_fight() -> void:
	if phase == Phase.INTRO:
		_start_round()


func opponent_of(f: Fighter) -> Fighter:
	return blue if f == red else red


## "2:47" style clock text.
func clock_text() -> String:
	var seconds := ceili(clock)
	return "%d:%02d" % [seconds / 60, seconds % 60]


## Advances the fight by [param dt] real seconds.
func step(dt: float) -> void:
	match phase:
		Phase.INTRO:
			pass
		Phase.ROUND:
			clock = maxf(clock - dt * CLOCK_SPEED, 0.0)
			for f in fighters:
				_update_fighter(f, opponent_of(f), dt)
			_keep_apart()
			if clock <= 0.0 and phase == Phase.ROUND:
				_end_round()
		Phase.COUNT:
			clock = maxf(clock - dt * CLOCK_SPEED, 0.0)
			_update_count(dt)
		Phase.BREAK:
			_update_break(dt)
		Phase.FINISHED:
			_update_finished(dt)
	for f in fighters:
		f.state_time += dt


# ============================================================================
#  Rounds and breaks
# ============================================================================

func _start_round() -> void:
	phase = Phase.ROUND
	clock = GAME_ROUND_SECONDS
	for f in fighters:
		f.reset_round_stats()
		f.combo.clear()
		f.think_timer = rng.randf_range(0.2, 0.6)
		f.set_state(State.IDLE, "stance")
	bell.emit(1)
	round_started.emit(round_number)


func _end_round() -> void:
	judges.finalise_round(round_number - 1, red, blue)
	bell.emit(3)
	round_ended.emit(round_number)
	if round_number >= ROUNDS:
		_decision()
		return

	phase = Phase.BREAK
	break_time = 0.0
	_advice_given = false
	for f in fighters:
		f.combo.clear()
		f.set_state(State.WALK_CORNER, "move_back")
		_corner_recovery(f)
	# The official cards are secret, so each trainer goes by the TV pundit's
	# card (what they would hear at ringside) before giving advice.
	var t := judges.pundit_totals()
	red.advice = ai.corner_advice(red, t[0], t[1], round_number + 1, ROUNDS)
	blue.advice = ai.corner_advice(blue, t[1], t[0], round_number + 1, ROUNDS)


## A minute in the corner: water, a towel and some breath back.
func _corner_recovery(f: Fighter) -> void:
	var recover := lerpf(0.35, 0.60, f.data.stamina / 99.0)
	f.energy = minf(f.energy + (Fighter.MAX_ENERGY - f.energy) * recover, Fighter.MAX_ENERGY)
	f.health = minf(f.health + 2.0, f.data.start_health)
	f.stun = 0.0
	f.wear *= 0.85


func _update_break(dt: float) -> void:
	break_time += dt
	for f in fighters:
		if f.state == State.WALK_CORNER:
			var target: float = ArenaRenderer.CORNER_X[f.corner]
			f.x = move_toward(f.x, target, WALK_SPEED * dt)
			if absf(f.x - target) < 0.5:
				f.set_state(State.CORNER, "relaxed")
	if not _advice_given and break_time >= ADVICE_AT:
		_advice_given = true
		for f in fighters:
			corner_advice.emit(f.corner, Fighter.ADVICE_TEXT[f.advice])
	if break_time >= BREAK_SECONDS:
		round_number += 1
		_start_round()


# ============================================================================
#  Fighters during a round
# ============================================================================

func _update_fighter(f: Fighter, o: Fighter, dt: float) -> void:
	# Head clears and breath returns a little all the time.
	f.stun = maxf(f.stun - dt * lerpf(5.0, 9.0, f.data.chin / 99.0), 0.0)
	f.spend_energy(0.28 * f.energy_drain_scale() * dt)
	if f.state in [State.IDLE, State.GUARD, State.CLINCH]:
		f.energy = minf(f.energy + dt * (0.25 + f.data.stamina / 99.0 * 0.55), Fighter.MAX_ENERGY)

	match f.state:
		State.PUNCH:
			if not f.punch_resolved and f.state_time >= f.punch_impact:
				_resolve_punch(f, o)
			if f.state == State.PUNCH and f.state_time >= f.state_length:
				f.set_state(State.IDLE, "stance")
		State.MOVE:
			f.x += f.facing * f.move_dir * f.move_speed() * dt
			f.spend_energy(0.25 * f.energy_drain_scale() * dt)
			if f.move_dir > 0:
				f.add_stat("pressure", dt)
			if _hit_ropes(f, f.move_dir < 0):
				pass
			elif f.state_time >= f.state_length:
				f.set_state(State.IDLE, "stance")
		State.ROPES:
			if f.state_time >= f.state_length:
				f.x += f.facing * 4.0
				f.set_state(State.IDLE, "stance")
		State.CLINCH:
			if f.state_time >= f.state_length and o.state == State.CLINCH:
				_break_clinch()
		State.GUARD, State.HURT, State.TAUNT:
			if f.state_length > 0.0 and f.state_time >= f.state_length:
				f.set_state(State.IDLE, "stance")

	if f.is_free():
		ai.think(f, o, round_number, dt)
		if f.state == State.CLINCH and o.state == State.CLINCH:
			_start_clinch()


func _start_clinch() -> void:
	var hold := rng.randf_range(1.0, 1.8)
	var gap := (red.height_px + blue.height_px) * 0.5 * MIN_GAP
	var centre := (red.x + blue.x) * 0.5
	red.x = centre - gap * 0.5
	blue.x = centre + gap * 0.5
	for f in fighters:
		f.combo.clear()
		f.state_length = hold


func _break_clinch() -> void:
	for f in fighters:
		f.x -= f.facing * 6.0
		f.think_timer = rng.randf_range(0.1, 0.3)
		f.set_state(State.IDLE, "stance")


## Stops a boxer at the ropes. Returns true if he bounced off them.
func _hit_ropes(f: Fighter, moving_back: bool) -> bool:
	var limit_low := ArenaRenderer.RING_MIN_X
	var limit_high := ArenaRenderer.RING_MAX_X
	if f.x >= limit_low and f.x <= limit_high:
		return false
	f.x = clampf(f.x, limit_low, limit_high)
	var backing_into := (f.facing > 0 and f.x <= limit_low) or (f.facing < 0 and f.x >= limit_high)
	if moving_back and backing_into and f.state != State.ROPES and f.state != State.DOWN:
		f.set_state(State.ROPES, "ropes", BoxerPoses.length("ropes"))
		ropes_hit.emit(0 if f.x <= limit_low else 1)
		return true
	return false


## Boxers can never walk through each other.
func _keep_apart() -> void:
	var gap := (red.height_px + blue.height_px) * 0.5 * MIN_GAP
	var overlap := gap - (blue.x - red.x)
	if overlap > 0.0:
		if red.is_down():
			blue.x += overlap
		elif blue.is_down():
			red.x -= overlap
		else:
			red.x -= overlap * 0.5
			blue.x += overlap * 0.5
	for f in fighters:
		if f.state != State.ROPES:
			_hit_ropes(f, f.state == State.HURT)
		f.x = clampf(f.x, ArenaRenderer.RING_MIN_X, ArenaRenderer.RING_MAX_X)


# ============================================================================
#  Punches
# ============================================================================

func _resolve_punch(a: Fighter, d: Fighter) -> void:
	a.punch_resolved = true
	var type := a.punch_type
	var dist := absf(d.x - a.x)
	var reach := a.reach_px(type) + d.height_px * 0.08

	# Out of range (the defender stepped away) or nothing to hit.
	if dist > reach or d.is_down():
		_missed(a, d, type)
		return

	# Slipped or ducked.
	var slip := 0.20
	slip += (d.skill("speed") - a.skill("speed")) / 99.0 * 0.20
	slip += d.skill("intelligence") / 99.0 * 0.08
	slip -= a.skill("intelligence") / 99.0 * 0.06
	slip -= d.hurt_level() * 0.10
	if d.state == State.MOVE and d.move_dir < 0:
		slip += 0.20
	if d.state in [State.PUNCH, State.TAUNT, State.CLINCH]:
		slip = 0.0          # Caught square.
	elif d.state in [State.HURT, State.ROPES]:
		slip = minf(slip, 0.12)
	if rng.randf() < clampf(slip, 0.0, 0.55):
		_missed(a, d, type)
		return

	# Damage before defence. Tired, later-round boxers get hurt more.
	var power := a.skill("power")
	var dmg := PunchTypes.DAMAGE[type] * (0.45 + power / 99.0 * 0.95) * rng.randf_range(0.8, 1.2)
	dmg *= 1.0 + d.fatigue() * 0.6 + (round_number - 1) * 0.06
	if a.advice == Fighter.Advice.ALL_OUT:
		dmg *= 1.1
	if PunchTypes.is_power_punch(type):
		dmg *= STYLE_POWER[a.data.style]
	var caught_punching := d.state == State.PUNCH and not d.punch_resolved
	if caught_punching:
		dmg *= 1.3   # Walked onto it.

	# Blocked? A high guard stops most head shots; the normal stance catches some.
	var to_head := PunchTypes.TO_HEAD[type]
	var guard_quality := 0.0
	if d.state == State.GUARD:
		guard_quality = 1.0
	elif d.state == State.IDLE or d.state == State.MOVE:
		guard_quality = 0.35 if d.anim == "stance" or d.state == State.MOVE else 0.10
	guard_quality *= 0.75 + 0.25 * d.skill("intelligence") / 99.0
	if to_head and rng.randf() < PunchTypes.BLOCKABLE[type] * guard_quality:
		dmg *= 0.12
		d.health = maxf(d.health - dmg, 0.0)
		d.spend_energy(0.3)
		d.add_stat("evaded", 1)
		a.add_stat("blocked", 1)
		d.x -= d.facing * 1.0
		punch_landed.emit(a.corner, type, dmg, true)
		return

	# Clean shot.
	d.health = maxf(d.health - dmg, 0.0)
	a.add_stat("landed", 1)
	a.add_stat("damage", dmg)
	a.add_stat("score", PunchTypes.SCORE[type] * (0.6 + dmg))
	if PunchTypes.is_power_punch(type):
		a.add_stat("power_landed", 1)
	var toughness := (1.4 - d.data.strength / 99.0) * STYLE_TOUGHNESS[d.data.style]
	d.wear = minf(d.wear + dmg * 0.010 * toughness, 1.0)
	d.spend_energy(dmg * (2.5 if not to_head else 0.8) * toughness)
	if to_head:
		d.stun += dmg * 12.0 * (1.5 - d.data.chin / 99.0) * PunchTypes.STUN[type] * STYLE_TOUGHNESS[d.data.style]
	d.combo.clear()
	d.x -= d.facing * (1.0 + dmg * 2.5)
	punch_landed.emit(a.corner, type, dmg, false)

	# Down he goes?
	if d.health <= 0.0 or d.stun >= 100.0:
		_knockdown(d, a)
		return
	if to_head and PunchTypes.is_power_punch(type):
		var chance := (dmg - 0.5) * 0.05 * (1.5 - d.data.chin / 99.0)
		chance *= (1.0 + d.stun / 60.0) * (1.6 - d.health / Fighter.MAX_HEALTH)
		if rng.randf() < clampf(chance, 0.0, 0.30):
			_knockdown(d, a)
			return

	var reaction := "hurt" if to_head else "hurt_body"
	d.set_state(State.HURT, reaction, 0.25 + dmg * 0.15)
	_hit_ropes(d, true)


func _missed(a: Fighter, d: Fighter, type: int) -> void:
	d.add_stat("evaded", 1)
	d.counter_window = maxf(d.counter_window, 0.5)
	punch_missed.emit(a.corner, type)


# ============================================================================
#  Knockdowns and the count
# ============================================================================

func _knockdown(d: Fighter, a: Fighter) -> void:
	d.knockdowns_round += 1
	d.knockdowns_total += 1
	d.combo.clear()
	a.combo.clear()
	d.set_state(State.DOWN, "knockdown")
	a.set_state(State.NEUTRAL, "move_back")
	knocked_down.emit(d.corner)

	if d.knockdowns_round >= KNOCKDOWNS_FOR_TKO:
		_finish(a.corner, "TKO", "Three knockdowns in the round")
		return

	# How long until he can beat the count? 99 = he is not getting up.
	var t := 3.0 + d.stun / 30.0 + (1.0 - d.health / Fighter.MAX_HEALTH) * 7.5
	t += -d.data.chin / 99.0 * 2.0 + d.knockdowns_total * 1.8 + rng.randf_range(-1.0, 2.0)
	if d.health <= 0.0:
		t = 99.0
	d.getup_count = clampi(ceili(t), 3, 99)

	phase = Phase.COUNT
	count_corner = d.corner
	count_value = 0
	_count_timer = 0.0


func _update_count(dt: float) -> void:
	var down := fighters[count_corner]
	var other := opponent_of(down)

	# The downed boxer slides clear of the ropes so he lies inside the ring.
	var safe_low := ArenaRenderer.RING_MIN_X + down.height_px * 0.42
	var safe_high := ArenaRenderer.RING_MAX_X - down.height_px * 0.42
	if down.state == State.DOWN:
		down.x = move_toward(down.x, clampf(down.x, safe_low, safe_high), 30.0 * dt)

	# The other boxer backs off to a neutral spot and waits.
	if other.state == State.NEUTRAL:
		var dist := absf(down.x - other.x)
		var room := other.x - other.facing * 2.0
		if dist < other.height_px * 1.1 and room > ArenaRenderer.RING_MIN_X and room < ArenaRenderer.RING_MAX_X:
			other.x -= other.facing * other.move_speed() * dt
			other.play("move_back")
		else:
			var brash := other.data.intelligence < 55 and other.data.style in [BoxerData.Style.BRAWLER, BoxerData.Style.SLUGGER]
			other.play("taunt_one" if brash else "ready")
	_keep_apart_during_count(down, other)

	if down.state == State.RISING and down.state_time >= BoxerPoses.length("stand_up"):
		down.set_state(State.IDLE, "stance")

	_count_timer += dt
	if _count_timer < COUNT_SECONDS:
		_check_count_over(down, other)
		return
	_count_timer -= COUNT_SECONDS
	count_value += 1
	count_changed.emit(down.corner, count_value)

	var up_at := down.getup_count
	if up_at <= 10 and count_value == up_at - 2:
		down.set_state(State.KNEEL, "to_knee")
	elif up_at in [11, 12] and count_value == 8:
		down.set_state(State.KNEEL, "to_knee")   # Tries... but won't make it.
	if up_at <= 10 and count_value == up_at:
		down.set_state(State.RISING, "stand_up")
		fighter_rose.emit(down.corner)
	if count_value >= 10 and (down.state == State.DOWN or down.state == State.KNEEL):
		_finish(other.corner, "KO", "Counted out")
		return
	_check_count_over(down, other)


## Fight resumes after a mandatory eight count once the boxer is up.
func _check_count_over(down: Fighter, other: Fighter) -> void:
	if count_value < 8 or down.state != State.IDLE:
		return
	down.stun = 25.0
	down.health = minf(down.health + 3.0, Fighter.MAX_HEALTH)
	down.think_timer = 0.4
	other.think_timer = 0.2
	other.set_state(State.IDLE, "stance")
	count_corner = -1
	phase = Phase.ROUND
	if clock <= 0.0:
		_end_round()


func _keep_apart_during_count(down: Fighter, other: Fighter) -> void:
	other.x = clampf(other.x, ArenaRenderer.RING_MIN_X, ArenaRenderer.RING_MAX_X)
	down.x = clampf(down.x, ArenaRenderer.RING_MIN_X, ArenaRenderer.RING_MAX_X)


# ============================================================================
#  End of the fight
# ============================================================================

## Reads the three cards. A boxer needs at least two judges to win:
##   3-0 unanimous decision, 2-1 split decision, 2-0 with one even = majority.
## Otherwise it is a draw: 0-0-3 unanimous, 1-0-2 majority, 1-1-1 split.
func _decision() -> void:
	var tally := judges.tally()   # [for red, for blue, even]
	var winner := -1
	if tally[0] >= 2:
		winner = 0
	elif tally[1] >= 2:
		winner = 1
	var method := "DRAW"
	var detail := ""
	if winner >= 0:
		if tally[winner] == 3:
			method = "UD"
		elif tally[2] > 0:
			method = "MD"
		else:
			method = "SD"
	elif tally[2] == 3:
		detail = "UNANIMOUS"
	elif tally[2] == 2:
		detail = "MAJORITY"
	else:
		detail = "SPLIT"
	_finish(winner, method, detail)


## After a decision both boxers wait for the announcer; call this when the
## winner is read out to start the celebrations. (Stoppages celebrate at once.)
func announce_winner() -> void:
	var winner: int = result.get("winner", -1)
	_finish_timer = 0.0
	for f in fighters:
		if winner == f.corner:
			f.set_state(State.CELEBRATE, "victory")
		elif winner >= 0:
			f.set_state(State.DEJECTED, "dejected")


func _finish(winner: int, method: String, detail: String) -> void:
	phase = Phase.FINISHED
	_finish_timer = 0.0
	# Derived from the displayed clock so "time of stoppage" + clock = 3:00.
	var elapsed := int(GAME_ROUND_SECONDS) - ceili(clock)
	result = {
		"winner": winner,
		"method": method,
		"detail": detail,
		"round": round_number,
		"time": "%d:%02d" % [elapsed / 60, elapsed % 60],
		"cards": [],
	}
	for j in judges.panel.size():
		result["cards"].append(judges.totals(j))
	var stoppage := method in ["KO", "TKO"]
	for f in fighters:
		f.combo.clear()
		if not stoppage:
			f.set_state(State.CORNER, "relaxed")   # Waiting for the verdict.
		elif winner == f.corner:
			f.set_state(State.CELEBRATE, "victory")
		elif not f.is_down():
			f.set_state(State.DEJECTED, "dejected")
	if stoppage:
		bell.emit(5)
	fight_finished.emit(result)


func _update_finished(dt: float) -> void:
	_finish_timer += dt
	# The winner alternates between celebrating and a skip for the crowd.
	for f in fighters:
		if f.state == State.CELEBRATE and _finish_timer > 3.0:
			var cycle := fmod(_finish_timer - 3.0, 6.0)
			f.play("taunt_skip" if cycle > 4.0 else "victory")
