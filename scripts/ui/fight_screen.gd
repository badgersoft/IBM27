extends Control
## The fight screen: the ring in the middle, name plates and the score bug
## above it, the boxers' condition and the scorecard panel below it (today's
## judges before the bell, the TV pundit's card during the fight, and the
## official cards across the whole bottom row, filled in judge by judge as
## the verdict is read out).
##
## Layout (1280 x 800 design frame, 16 px margins round every block):
##
##   y  16 -  72  [ RED NAMEPLATE ] [ SCORE BUG ] [ BLUE NAMEPLATE ]
##   y  88 - 592  [                ARENA (424 x 168 x3)              ]
##   y 608 - 784  [ RED PANEL ]     [ SCORECARD ]     [ BLUE PANEL ]
##
## This script only wires things together. The fight itself is FightSim, the
## ring and boxers are ArenaView, and each panel is its own small widget.
##
## Esc (or the phone's back button): at the tale of the tape it goes back
## (as BACK does); during the fight it pauses - RESUME, SKIP TO RESULT (the
## rest of the fight is fought at once), and QUIT FIGHT only for a fight that
## counts for nothing (a season fight can't be walked out of and watched
## again); once it is over it goes to the fight stats.
##
## The player's own fight (his boxer in a career fixture, or --manage=<0|1>):
## he is in that boxer's corner. Between rounds an ORDERS panel asks for the
## next round's tactic (the bell waits for it); during a round three SHOUT
## buttons (or A / D / K) give one shout a round - ATTACK, DEFEND or KNOCK
## HIM OUT (see Fighter.Shout).

const FRAME_SIZE := Vector2(1280, 800)
const ARENA_SCALE := 3
const ARENA_POS := Vector2(4, 88)
const MARGIN := 16
const INTRO_AUTO_START := 12.0   ## Seconds before the fight starts by itself.
const RESULT_DELAY := 3.0        ## Seconds after the final bell before the verdict.
const SCORECARD_REFRESH := 0.25
## How the crowd's cheering (Sfx.excite) answers each moment:
## (excitement 0 - 1, seconds it is held before dying away).
const CHEER_SIGNIFICANT := Vector2(0.45, 1.5)
const CHEER_ONE_TWO := Vector2(0.55, 1.5)
const CHEER_BIG := Vector2(0.85, 3.0)
const CHEER_KNOCKDOWN := Vector2(1.0, 7.0)
const CHEER_BEAT_COUNT := Vector2(0.8, 3.0)
const CHEER_WINNER := Vector2(1.0, 4.0)
## The pause box: PAUSE_W wide, the title, then a PAUSE_BUTTON for each
## choice PAUSE_STEP apart.
const PAUSE_W := 480
const PAUSE_BUTTON := Vector2(320, 48)
const PAUSE_FIRST_Y := 96
const PAUSE_STEP := 64
## The ORDERS panel between rounds: the tactics in the order shown (two by
## two), and its size.
const ORDERS: Array[Fighter.Advice] = [Fighter.Advice.DEFEND_MORE, Fighter.Advice.KEEP_IT_UP,
		Fighter.Advice.ATTACK_MORE, Fighter.Advice.ALL_OUT]
const ORDERS_SIZE := Vector2(720, 216)
const ORDER_BUTTON := Vector2(320, 48)
## The SHOUT bar along the bottom of the ring during a round.
const SHOUTS: Array[Fighter.Shout] = [Fighter.Shout.ATTACK, Fighter.Shout.DEFEND, Fighter.Shout.KNOCKOUT]
const SHOUT_KEYS: Array[Key] = [KEY_A, KEY_D, KEY_K]
const SHOUT_BUTTON := Vector2(304, 40)
const SHOUT_GAP := 16
const SHOUT_BOTTOM := 16

var sim: FightSim
var view: ArenaView

var _frame: Control
var _overlay: Control
var _bug: ScoreBug
var _scorecard: Scorecard
var _official: OfficialCard
var _panels: Array[FighterPanel] = []
var _banner: Label
var _banner_time := 0.0
var _tape: TaleOfTape
var _result: ResultBand
var _ceremony: Ceremony
var _post: PostFight
var _pause: Control = null
var _human := -1                 ## The player's corner, or -1.
var _orders: Control = null
var _shout_bar: Control = null
var _shout_buttons: Array[Button] = []
## What the result did to the two boxers (see Season.record_result), with
## their places before and after; filled in when the fight ends.
var _summary := {}

var _serials := [-1, -1]
var _intro_time := 0.0
var _card_clock := 0.0
var _result_clock := -1.0
var _capturing := false
var _big_landing := false        # A big punch's punch_landed is on its way.
var _big_this_step := false     # The screenshot tool waits for a big punch...
var _one_two_this_step := false # ...or a one-two.


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.red == null:
		GameState.new_fight()
	var red := GameState.red
	var blue := GameState.blue

	sim = FightSim.new(red, blue, GameState.fight_seed(), GameState.rounds)
	sim.title_fight = GameState.title_fight
	_human = _players_corner(red, blue)
	sim.human_corner = _human
	_connect_sim()

	view = ArenaView.new()
	add_child(view)
	view.setup(GameState.venue_id, red, blue)

	_build_layout(red, blue)
	_sync_rigs()
	_refresh_hud()
	Sfx.crowd_start(GameState.venue_id)

	if GameState.options.has("capture"):
		_run_capture()


## The corner the player is in: his boxer's in his own fixture (or
## --manage for screenshots), otherwise -1.
static func _players_corner(red: BoxerData, blue: BoxerData) -> int:
	if GameState.options.has("manage"):
		return clampi(int(GameState.options["manage"]), 0, 1)
	var career := GameState.career
	if career == null or GameState.fixture == null or not GameState.fixture.involves(career.boxer):
		return -1
	return 0 if red == career.boxer else 1


func _process(delta: float) -> void:
	if _capturing or _pause != null:
		return
	if sim.phase == FightSim.Phase.INTRO:
		_intro_time += delta
		if _intro_time >= INTRO_AUTO_START:
			_begin_fight()
	sim.step(delta)
	_sync_rigs()
	_update_shout_bar()
	_update_banner(delta)
	_refresh_hud(delta)
	if _result_clock >= 0.0:
		_result_clock += delta
		if _result_clock >= RESULT_DELAY and _result == null:
			_show_result()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and _human >= 0 and _pause == null:
		var i := SHOUT_KEYS.find((event as InputEventKey).keycode)
		if i >= 0:
			_shout(SHOUTS[i])
			get_viewport().set_input_as_handled()
	elif sim.phase == FightSim.Phase.INTRO and _pause == null:
		var tapped: bool = event is InputEventMouseButton and event.pressed
		if tapped or event.is_action_pressed("ui_accept"):
			_begin_fight()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:   # Android back button.
		_on_back()


## Esc / back (see the top of the file).
func _on_back() -> void:
	if _capturing:
		return
	if _pause != null:
		_close_pause()
	elif sim.phase == FightSim.Phase.INTRO:
		_leave()
	elif sim.phase == FightSim.Phase.FINISHED:
		if _result != null:
			_show_post_fight()
	else:
		_open_pause()


## Back to where the fight was chosen, before a punch is thrown: nothing is
## recorded and the fight can be picked again.
func _leave() -> void:
	Sfx.crowd_stop()
	if GameState.fixture != null:
		get_tree().change_scene_to_file("res://scenes/fixtures.tscn")
	elif GameState.exhibition:
		GameState.picking = true
		get_tree().change_scene_to_file("res://scenes/roster.tscn")
	else:
		_go_to_menu()


func _open_pause() -> void:
	_pause = Control.new()
	_frame.add_child(UiTheme.place(_pause, 0, 0, FRAME_SIZE.x, FRAME_SIZE.y))
	_pause.add_child(UiTheme.block(Color(0, 0, 0, 0.55), 0, 0, FRAME_SIZE.x, FRAME_SIZE.y))
	var choices := [["RESUME", _close_pause], ["SKIP TO RESULT", _skip_to_result]]
	if GameState.fixture == null:
		choices.append(["QUIT FIGHT", _leave])
	var box := Vector2(PAUSE_W, PAUSE_FIRST_Y + choices.size() * PAUSE_STEP + 24)
	var box_pos := ((FRAME_SIZE - box) / 2.0).floor()
	_pause.add_child(UiTheme.panel(box_pos.x, box_pos.y, box.x, box.y, Palette.UI_PANEL, Palette.UI_BORDER, 4))
	_pause.add_child(UiTheme.place(UiTheme.label("PAUSED", UiTheme.TITLE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), box_pos.x, box_pos.y + 32, box.x, UiTheme.TITLE))
	var first: Button = null
	for i in choices.size():
		var b := Button.new()
		b.text = choices[i][0]
		b.focus_mode = Control.FOCUS_ALL
		UiTheme.place(b, box_pos.x + (box.x - PAUSE_BUTTON.x) / 2.0, box_pos.y + PAUSE_FIRST_Y + i * PAUSE_STEP, PAUSE_BUTTON.x, PAUSE_BUTTON.y)
		b.pressed.connect(choices[i][1])
		_pause.add_child(b)
		if first == null:
			first = b
	first.grab_focus()


func _close_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null


## Fights the rest of the bout at once (quietly), then carries on to the
## verdict as if it had been watched to the end.
func _skip_to_result() -> void:
	_close_pause()
	_close_orders()
	sim.release_human()
	sim.set_block_signals(true)
	var steps := 0
	while sim.phase != FightSim.Phase.FINISHED and steps < Season.MAX_STEPS:
		sim.step(Season.STEP)
		steps += 1
	sim.set_block_signals(false)
	_banner.visible = false
	view.arena.hide_corner_advice()
	_sync_rigs()
	_refresh_hud()
	_on_fight_finished(sim.result)


# ============================================================================
#  Layout
# ============================================================================

func _build_layout(red: BoxerData, blue: BoxerData) -> void:
	add_child(UiTheme.block(Palette.UI_BACKGROUND, 0, 0, 0, 0))
	get_child(-1).set_anchors_preset(Control.PRESET_FULL_RECT)

	# Everything is laid out inside a fixed 1280 x 800 frame kept centred, so
	# wider or taller screens simply get more background around it.
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_preset(Control.PRESET_CENTER)
	_frame.offset_left = -FRAME_SIZE.x / 2.0
	_frame.offset_top = -FRAME_SIZE.y / 2.0
	_frame.offset_right = FRAME_SIZE.x / 2.0
	_frame.offset_bottom = FRAME_SIZE.y / 2.0
	add_child(_frame)

	var arena_size := Vector2(ArenaRenderer.SIZE * ARENA_SCALE)
	var arena := TextureRect.new()
	arena.texture = view.get_texture()
	arena.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(arena, ARENA_POS.x, ARENA_POS.y, arena_size.x, arena_size.y))

	# Top row.
	var top_y := MARGIN
	var red_plate := Nameplate.new()
	red_plate.setup(red, 0)
	red_plate.position = Vector2(16, top_y)
	_frame.add_child(red_plate)
	var blue_plate := Nameplate.new()
	blue_plate.setup(blue, 1)
	blue_plate.position = Vector2(FRAME_SIZE.x - 16 - Nameplate.W, top_y)
	_frame.add_child(blue_plate)
	_bug = ScoreBug.new()
	_bug.position = Vector2((FRAME_SIZE.x - ScoreBug.W) / 2.0, top_y)
	_frame.add_child(_bug)

	# Bottom row: panel - scorecard - panel, 16 px apart.
	var bottom_y := ARENA_POS.y + arena_size.y + MARGIN
	for corner in 2:
		var panel := FighterPanel.new()
		panel.setup(red if corner == 0 else blue, corner)
		panel.position = Vector2(16 if corner == 0 else FRAME_SIZE.x - 16 - FighterPanel.W, bottom_y)
		_frame.add_child(panel)
		_panels.append(panel)
	_scorecard = Scorecard.new()
	_scorecard.position = Vector2((FRAME_SIZE.x - Scorecard.W) / 2.0, bottom_y)
	_frame.add_child(_scorecard)
	_scorecard.show_judges(sim.judges)
	# At the verdict the official cards take over the whole bottom row.
	_official = OfficialCard.new()
	_official.position = Vector2((FRAME_SIZE.x - OfficialCard.W) / 2.0, bottom_y)
	_official.setup(sim.judges)
	_official.visible = false
	_frame.add_child(_official)

	# Overlay over the arena for banners and pop-up panels.
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(UiTheme.place(_overlay, ARENA_POS.x, ARENA_POS.y, arena_size.x, arena_size.y))

	_banner = UiTheme.label("", UiTheme.HUGE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.outline(_banner, 16)
	_banner.clip_text = false
	_banner.visible = false
	_overlay.add_child(UiTheme.place(_banner, 0, 160, arena_size.x, 64))

	_tape = TaleOfTape.new()
	_tape.setup(red, blue, GameState.venue_id, sim.rounds, GameState.title_fight, GameState.purse)
	_tape.position = (arena_size - Vector2(TaleOfTape.W, TaleOfTape.H)) / 2.0
	_tape.dismissed.connect(_begin_fight)
	_tape.back_pressed.connect(_leave)
	if _human >= 0:
		_build_shout_bar()
	_overlay.add_child(_tape)


# ============================================================================
#  Fight events
# ============================================================================

func _connect_sim() -> void:
	sim.bell.connect(func(strikes: int) -> void: Sfx.bell(strikes))
	sim.round_started.connect(_on_round_started)
	sim.round_ended.connect(_on_round_ended)
	sim.punch_landed.connect(_on_punch_landed)
	sim.big_punch.connect(_on_big_punch)
	sim.one_two_landed.connect(_on_one_two)
	sim.significant_strike.connect(func(_c: int) -> void: Sfx.excite(CHEER_SIGNIFICANT.x, CHEER_SIGNIFICANT.y))
	sim.knocked_down.connect(_on_knocked_down)
	sim.count_changed.connect(func(_c: int, n: int) -> void: _show_banner(str(n), 0.9, Palette.UI_TEXT))
	sim.fighter_rose.connect(_on_fighter_rose)
	sim.ropes_hit.connect(func(side: int) -> void: view.arena.shake_ropes(side))
	sim.corner_advice.connect(func(corner: int, text: String) -> void: view.arena.show_corner_advice(corner, text, 6.5))
	sim.tactic_wanted.connect(func(_corner: int) -> void: _open_orders())
	sim.shouted.connect(_on_shouted)
	sim.fight_finished.connect(_on_fight_finished)


func _begin_fight() -> void:
	if sim.phase != FightSim.Phase.INTRO:
		return
	if is_instance_valid(_tape):
		_tape.queue_free()
	_scorecard.set_mode(Scorecard.Mode.PUNDIT)
	sim.start_fight()


func _on_round_started(r: int) -> void:
	view.arena.hide_corner_advice()
	_show_banner("ROUND %d" % r, 1.6)


func _on_round_ended(r: int) -> void:
	if r < sim.rounds:
		_show_banner("END OF ROUND %d" % r, 2.0, Palette.UI_TEXT)


func _on_punch_landed(_corner: int, _type: int, damage: float, blocked: bool) -> void:
	if blocked:
		Sfx.block()
		return
	if _big_landing:
		_big_landing = false     # The big punch already made its own noise.
		return
	Sfx.punch(damage / 1.6)
	view.arena.excitement = minf(view.arena.excitement + damage * 0.25, 1.0)
	if damage > 1.3:
		Sfx.roar(0.5)


## A big punch: blood spraying off where it lands, a heavy thud and the
## crowd rising (and staying up for a while).
func _on_big_punch(corner: int, type: int) -> void:
	_big_landing = true
	_big_this_step = true
	var d: Fighter = sim.fighters[1 - corner]
	var height_share := 0.80 if PunchTypes.TO_HEAD[type] else 0.56
	var at := Vector2(d.x + d.facing * d.height_px * 0.10, ArenaRenderer.FIGHT_Y - d.height_px * height_share)
	view.arena.blood_splatter(at.round(), -d.facing)
	view.arena.excitement = 1.0
	Sfx.big_hit()
	Sfx.excite(CHEER_BIG.x, CHEER_BIG.y)


## A one-two landed: a call-out over the man who threw it and a lift from the crowd.
func _on_one_two(corner: int) -> void:
	_one_two_this_step = true
	var a: Fighter = sim.fighters[corner]
	var head_top := ArenaRenderer.FIGHT_Y - a.height_px - 10.0
	view.arena.callout("ONE-TWO!", Vector2(a.x, head_top))
	view.arena.excitement = minf(view.arena.excitement + 0.4, 1.0)
	Sfx.roar(0.6)
	Sfx.excite(CHEER_ONE_TWO.x, CHEER_ONE_TWO.y)


func _on_knocked_down(_corner: int) -> void:
	_show_banner("DOWN!", 1.0, Palette.UI_RED)
	view.arena.excitement = 1.0
	Sfx.roar(1.0)
	Sfx.excite(CHEER_KNOCKDOWN.x, CHEER_KNOCKDOWN.y)


func _on_fighter_rose(_corner: int) -> void:
	view.arena.excitement = 0.8
	Sfx.excite(CHEER_BEAT_COUNT.x, CHEER_BEAT_COUNT.y)


func _on_fight_finished(result: Dictionary) -> void:
	_close_orders()
	if _shout_bar != null:
		_shout_bar.visible = false
	_update_records(result)
	view.arena.excitement = 1.0
	if result["method"] in ["KO", "TKO"]:
		_show_banner(ResultBand.METHOD_TITLES[result["method"]], RESULT_DELAY, Palette.UI_GOLD)
		Sfx.roar(1.0)
	else:
		_show_banner("FINAL BELL", RESULT_DELAY, Palette.UI_TEXT)
	_result_clock = 0.0


## Adds this fight to both boxers' records, pays the purse and moves them in
## the rankings (kept for the rest of the session). A season fixture is
## completed in the season, which also rates it and keeps it for the paper.
## An exhibition counts for nothing.
func _update_records(result: Dictionary) -> void:
	if GameState.exhibition:
		_summary = {}
		return
	var f := GameState.fixture
	if f != null and not f.is_done():
		f.watched = true
		GameState.season.complete(f, sim)
		_summary = f.summary
		return
	var before := [_rank(sim.red.data), _rank(sim.blue.data)]
	_summary = GameState.record_fight(sim.red.data, sim.blue.data, result, GameState.title_fight, GameState.purse)
	_summary["red_rank"] = before[0]
	_summary["blue_rank"] = before[1]
	_summary["red_rank_after"] = _rank(sim.red.data)
	_summary["blue_rank_after"] = _rank(sim.blue.data)


static func _rank(b: BoxerData) -> int:
	return GameState.rankings_for(b).rank_number(b)


## The verdict: the boxers and referee face the crowd in the middle of the
## ring while the slim band over the crowd reads out the result. The
## referee lifts the winner's arm the moment his name is called.
func _show_result() -> void:
	_banner.visible = false
	var ref_skin := absi(hash(sim.red.data.last_name + sim.blue.data.last_name)) % Palette.SKIN_TONES.size()
	_ceremony = view.show_ceremony(sim.red.data, sim.blue.data, ref_skin)
	view.arena.set_announcing(true)

	_result = ResultBand.new()
	_overlay.add_child(UiTheme.place(_result, 0, 0, _overlay.size.x, _overlay.size.y))
	var apron_mid := (ArenaRenderer.CANVAS_FRONT_Y + ArenaRenderer.APRON_BOTTOM_Y) / 2.0 * ARENA_SCALE
	_result.setup(sim.result, sim.red.data, sim.blue.data, sim.judges, apron_mid,
			GameState.title_fight, GameState.title_holder)
	_result.continue_pressed.connect(_show_post_fight)
	_result.judge_revealed.connect(_on_judge_revealed)
	_result.winner_announced.connect(_on_winner_announced)
	# The official cards replace the condition panels and the pundit's card,
	# filled in judge by judge.
	for panel in _panels:
		panel.visible = false
	_scorecard.visible = false
	_official.visible = true
	_official.reveal_judges(0, sim)


func _on_judge_revealed(index: int) -> void:
	_official.reveal_judges(index + 1, sim)


func _on_winner_announced() -> void:
	sim.announce_winner()
	_ceremony.raise(sim.result["winner"])
	Sfx.excite(CHEER_WINNER.x, CHEER_WINNER.y)
	view.arena.excitement = 1.0


## The post-fight stats over the whole screen.
func _show_post_fight() -> void:
	if _post != null:
		return
	_post = PostFight.new()
	var season_fight := GameState.fixture != null
	var next_text := "FIXTURES" if season_fight else "NEW FIGHT"
	var next: Callable = _to_fixtures if season_fight else _new_fight
	if GameState.exhibition:
		next_text = "NEW EXHIBITION"
		next = _new_exhibition
	_post.setup(sim, _summary, Excitement.rate(sim), GameState.purse, GameState.venue_id, next_text)
	_post.position = Vector2(MARGIN, MARGIN)
	_post.next_pressed.connect(next)
	_post.menu_pressed.connect(_go_to_menu)
	_frame.add_child(_post)
	_post.focus()


func _new_fight() -> void:
	GameState.new_fight()
	get_tree().reload_current_scene()


func _new_exhibition() -> void:
	Sfx.crowd_stop()
	GameState.picking = true
	get_tree().change_scene_to_file("res://scenes/roster.tscn")


func _to_fixtures() -> void:
	Sfx.crowd_stop()
	get_tree().change_scene_to_file("res://scenes/fixtures.tscn")


## The main menu, or the career's home page in a career.
func _go_to_menu() -> void:
	Sfx.crowd_stop()
	get_tree().change_scene_to_file("res://scenes/career_home.tscn" if GameState.career != null else "res://scenes/main_menu.tscn")


# ============================================================================
#  The player's corner: orders between rounds, shouts during them
# ============================================================================

## The SHOUT bar along the bottom of the ring (the player's fight only).
func _build_shout_bar() -> void:
	var arena_size := Vector2(ArenaRenderer.SIZE * ARENA_SCALE)
	var row_w := SHOUT_BUTTON.x * SHOUTS.size() + SHOUT_GAP * (SHOUTS.size() - 1)
	_shout_bar = Control.new()
	_shout_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(UiTheme.place(_shout_bar, (arena_size.x - row_w) / 2.0, arena_size.y - SHOUT_BOTTOM - SHOUT_BUTTON.y, row_w, SHOUT_BUTTON.y))
	for i in SHOUTS.size():
		var b := Button.new()
		b.text = "%s (%s)" % [Fighter.SHOUT_TEXT[SHOUTS[i]].trim_suffix("!"), OS.get_keycode_string(SHOUT_KEYS[i])]
		b.focus_mode = Control.FOCUS_NONE
		UiTheme.place(b, i * (SHOUT_BUTTON.x + SHOUT_GAP), 0, SHOUT_BUTTON.x, SHOUT_BUTTON.y)
		b.pressed.connect(_shout.bind(SHOUTS[i]))
		_shout_bar.add_child(b)
		_shout_buttons.append(b)
	_update_shout_bar()


## Shouts can be used once a round, during the round.
func _update_shout_bar() -> void:
	if _shout_bar == null:
		return
	var f: Fighter = sim.fighters[_human] if _human >= 0 else null
	var open := f != null and sim.phase == FightSim.Phase.ROUND and not f.shouted_this_round
	_shout_bar.visible = sim.phase in [FightSim.Phase.ROUND, FightSim.Phase.COUNT]
	for b in _shout_buttons:
		b.disabled = not open


func _shout(kind: Fighter.Shout) -> void:
	sim.shout(kind)


## The shout over the player's boxer, like a one-two's call-out.
func _on_shouted(corner: int, kind: int) -> void:
	var f: Fighter = sim.fighters[corner]
	view.arena.callout(Fighter.SHOUT_TEXT[kind], Vector2(f.x, ArenaRenderer.FIGHT_Y - f.height_px - 10.0))
	_update_shout_bar()


## Between rounds: the next round's orders. The bell waits for them.
func _open_orders() -> void:
	_close_orders()
	var arena_size := Vector2(ArenaRenderer.SIZE * ARENA_SCALE)
	var pos := ((arena_size - ORDERS_SIZE) / 2.0).floor()
	_orders = Control.new()
	_overlay.add_child(UiTheme.place(_orders, pos.x, pos.y, ORDERS_SIZE.x, ORDERS_SIZE.y))
	_orders.add_child(UiTheme.panel(0, 0, ORDERS_SIZE.x, ORDERS_SIZE.y, Palette.UI_PANEL, Palette.UI_BORDER, 4))
	var title := "ORDERS FOR ROUND %d" % (sim.round_number + 1)
	_orders.add_child(UiTheme.place(UiTheme.label(title, UiTheme.LARGE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), 0, 16, ORDERS_SIZE.x, UiTheme.LARGE))
	var x0 := (ORDERS_SIZE.x - ORDER_BUTTON.x * 2 - 16) / 2.0
	var focus: Button = null
	for i in ORDERS.size():
		var b := Button.new()
		b.text = Fighter.ADVICE_TEXT[ORDERS[i]].trim_suffix("!")
		b.focus_mode = Control.FOCUS_ALL
		UiTheme.place(b, x0 + (i % 2) * (ORDER_BUTTON.x + 16), 56 + (i / 2) * (ORDER_BUTTON.y + 16), ORDER_BUTTON.x, ORDER_BUTTON.y)
		b.pressed.connect(_choose_order.bind(ORDERS[i]))
		_orders.add_child(b)
		if ORDERS[i] == Fighter.Advice.KEEP_IT_UP:
			focus = b
	var note := UiTheme.label("THE BELL WAITS FOR YOUR ORDERS", UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_orders.add_child(UiTheme.place(note, 0, ORDERS_SIZE.y - 32, ORDERS_SIZE.x, UiTheme.CAPTION))
	focus.grab_focus()


func _choose_order(advice: Fighter.Advice) -> void:
	sim.choose_tactic(advice)
	_close_orders()


func _close_orders() -> void:
	if _orders != null:
		_orders.queue_free()
		_orders = null


# ============================================================================
#  Per-frame updates
# ============================================================================

## Copies each fighter's position and animation request onto its rig.
func _sync_rigs() -> void:
	for i in 2:
		var f: Fighter = sim.fighters[i]
		view.place(i, f.x)
		if f.anim_serial != _serials[i]:
			_serials[i] = f.anim_serial
			view.rigs[i].play(f.anim, f.anim_scale, true)


func _refresh_hud(delta: float = SCORECARD_REFRESH) -> void:
	_bug.show_state(sim.round_number, sim.rounds, sim.clock_text())
	for i in 2:
		_panels[i].refresh(sim.fighters[i])
	_card_clock += delta
	if _card_clock >= SCORECARD_REFRESH:
		_card_clock = 0.0
		_scorecard.refresh(sim)


func _show_banner(text: String, seconds: float, colour: Color = Palette.UI_GOLD) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", colour)
	_banner.visible = true
	_banner_time = seconds


func _update_banner(delta: float) -> void:
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time <= 0.0:
			_banner.visible = false


# ============================================================================
#  Screenshot mode (developer tool)
# ============================================================================
## Run with:  -- --capture=<file.png> [--show=intro|fight|big|onetwo|taunt|break|count|announce|result|stats] [--at=<seconds>]
## The fight is fast-forwarded (rigs stepped in lock-step with the fight) to a
## moment worth showing, frozen, and the whole screen saved as a PNG.

func _run_capture() -> void:
	_capturing = true
	var path: String = GameState.options["capture"]
	var show: String = GameState.options.get("show", "fight")
	var at := float(GameState.options.get("at", "20"))
	await get_tree().process_frame

	if show != "intro":
		_begin_fight()
		var dt := 1.0 / 60.0
		var t := 0.0
		var limit := (FightSim.REAL_ROUND_SECONDS + FightSim.BREAK_SECONDS) * sim.rounds + 120.0
		while t < limit:
			_big_this_step = false
			_one_two_this_step = false
			sim.step(dt)
			_sync_rigs()
			for rig in view.rigs:
				rig.advance(dt)
			view.arena.advance(dt)
			_update_banner(dt)
			t += dt
			if t >= at and _is_capture_moment("fight" if show == "pause" else show):
				break
		for rig in view.rigs:
			rig.set_process(false)
		if show == "big":
			for i in 14:
				view.arena.advance(dt)      # Let the blood fly a little.
		if show == "big" or show == "onetwo":
			view.arena.set_process(false)   # Hold the blood or call-out for the shot.
		_refresh_hud()
		_update_shout_bar()
		if show == "pause":
			_open_pause()
		if show in ["result", "announce", "stats"] and sim.phase == FightSim.Phase.FINISHED:
			_show_result()
			if show != "announce":
				_result.reveal_all()
				_ceremony.finish_raise()
			if show == "stats":
				_show_post_fight()

	# "--wait" lets the decision announcement run for a while before the shot.
	await get_tree().create_timer(float(GameState.options.get("wait", "0.5"))).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path, "  (", sim.result.get("method", "fight on"), " ", sim.result.get("winner", ""), ")")
	get_tree().quit()


func _is_capture_moment(show: String) -> bool:
	match show:
		"break":
			return sim.phase == FightSim.Phase.BREAK and sim.break_time > FightSim.ADVICE_AT + 0.6
		"orders":
			return sim.phase == FightSim.Phase.BREAK and sim.break_time > 2.0
		"count":
			return sim.phase == FightSim.Phase.COUNT and sim.count_value >= 2
		"result", "announce", "stats":
			return sim.phase == FightSim.Phase.FINISHED and sim._finish_timer > 1.0
		"big":
			return _big_this_step
		"onetwo":
			return _one_two_this_step
		"taunt":
			for f in sim.fighters:
				if f.state == Fighter.State.TAUNT and f.state_time > 0.35:
					return true
			return false
		_:
			if sim.phase != FightSim.Phase.ROUND:
				return false
			for f in sim.fighters:
				var near_impact := f.state == Fighter.State.PUNCH and absf(f.state_time - f.punch_impact) < 0.02
				var gap := absf(sim.red.x - sim.blue.x) / f.height_px
				if near_impact and gap > 0.40 and gap < 0.62:
					return true
			return false
