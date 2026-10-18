extends Control
## The fight screen: the ring in the middle, name plates and the score bug
## above it, the boxers' condition and the scorecard panel below it (today's
## judges before the bell, the TV pundit's card during the fight, and the
## official cards across the whole bottom row, filled in judge by judge as
## the verdict is read out).
##
## Layout (1280 x 720 design frame, 8 px margins between every block):
##
##   y   8 - 64   [ RED NAMEPLATE ] [ SCORE BUG ] [ BLUE NAMEPLATE ]
##   y  72 - 576  [                ARENA (424 x 168 x3)              ]
##   y 584 - 712  [ RED PANEL ]     [ SCORECARD ]     [ BLUE PANEL ]
##
## This script only wires things together. The fight itself is FightSim, the
## ring and boxers are ArenaView, and each panel is its own small widget.

const FRAME_SIZE := Vector2(1280, 720)
const ARENA_SCALE := 3
const ARENA_POS := Vector2(4, 72)
const MARGIN := 8
const INTRO_AUTO_START := 12.0   ## Seconds before the fight starts by itself.
const RESULT_DELAY := 3.0        ## Seconds after the final bell before the verdict.
const SCORECARD_REFRESH := 0.25

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

var _serials := [-1, -1]
var _intro_time := 0.0
var _card_clock := 0.0
var _result_clock := -1.0
var _capturing := false
var _big_landing := false        # A big punch's punch_landed is on its way.
var _big_this_step := false     # The screenshot tool waits for a big punch.


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if GameState.red == null:
		GameState.new_fight()
	var red := GameState.red
	var blue := GameState.blue

	sim = FightSim.new(red, blue, GameState.fight_seed(), GameState.rounds)
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


func _process(delta: float) -> void:
	if _capturing:
		return
	if sim.phase == FightSim.Phase.INTRO:
		_intro_time += delta
		if _intro_time >= INTRO_AUTO_START:
			_begin_fight()
	sim.step(delta)
	_sync_rigs()
	_update_banner(delta)
	_refresh_hud(delta)
	if _result_clock >= 0.0:
		_result_clock += delta
		if _result_clock >= RESULT_DELAY and _result == null:
			_show_result()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_to_menu()
	elif sim.phase == FightSim.Phase.INTRO:
		var tapped: bool = event is InputEventMouseButton and event.pressed
		if tapped or event.is_action_pressed("ui_accept"):
			_begin_fight()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:   # Android back button.
		_go_to_menu()


# ============================================================================
#  Layout
# ============================================================================

func _build_layout(red: BoxerData, blue: BoxerData) -> void:
	add_child(UiTheme.block(Palette.UI_BACKGROUND, 0, 0, 0, 0))
	get_child(-1).set_anchors_preset(Control.PRESET_FULL_RECT)

	# Everything is laid out inside a fixed 1280 x 720 frame kept centred, so
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
	_tape.setup(red, blue, GameState.venue_id, sim.rounds)
	_tape.position = (arena_size - Vector2(TaleOfTape.W, TaleOfTape.H)) / 2.0
	_tape.dismissed.connect(_begin_fight)
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
	sim.knocked_down.connect(_on_knocked_down)
	sim.count_changed.connect(func(_c: int, n: int) -> void: _show_banner(str(n), 0.9, Palette.UI_TEXT))
	sim.fighter_rose.connect(func(_c: int) -> void: view.arena.excitement = 0.8)
	sim.ropes_hit.connect(func(side: int) -> void: view.arena.shake_ropes(side))
	sim.corner_advice.connect(func(corner: int, text: String) -> void: view.arena.show_corner_advice(corner, text, 6.5))
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


## A big punch: a flash where it lands, a heavy thud and the crowd rising.
func _on_big_punch(corner: int, type: int) -> void:
	_big_landing = true
	_big_this_step = true
	var d: Fighter = sim.fighters[1 - corner]
	var height_share := 0.80 if PunchTypes.TO_HEAD[type] else 0.56
	var at := Vector2(d.x + d.facing * d.height_px * 0.10, ArenaRenderer.FIGHT_Y - d.height_px * height_share)
	view.arena.impact_flash(at.round())
	view.arena.excitement = 1.0
	Sfx.big_hit()


func _on_knocked_down(_corner: int) -> void:
	_show_banner("DOWN!", 1.0, Palette.UI_RED)
	view.arena.excitement = 1.0
	Sfx.roar(1.0)


func _on_fight_finished(result: Dictionary) -> void:
	_update_records(result)
	view.arena.excitement = 1.0
	if result["method"] in ["KO", "TKO"]:
		_show_banner(ResultBand.METHOD_TITLES[result["method"]], RESULT_DELAY, Palette.UI_GOLD)
		Sfx.roar(1.0)
	else:
		_show_banner("FINAL BELL", RESULT_DELAY, Palette.UI_TEXT)
	_result_clock = 0.0


## Adds this fight to both boxers' records (kept for the rest of the session).
func _update_records(result: Dictionary) -> void:
	var winner: int = result["winner"]
	var by_ko: bool = result["method"] in ["KO", "TKO"]
	for f in sim.fighters:
		if winner < 0:
			f.data.add_result("D", false)
		else:
			f.data.add_result("W" if f.corner == winner else "L", by_ko)


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
	_result.setup(sim.result, sim.red.data, sim.blue.data, sim.judges, apron_mid)
	_result.new_fight_pressed.connect(_new_fight)
	_result.menu_pressed.connect(_go_to_menu)
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
	view.arena.excitement = 1.0


func _new_fight() -> void:
	GameState.new_fight()
	get_tree().reload_current_scene()


func _go_to_menu() -> void:
	Sfx.crowd_stop()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


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
## Run with:  -- --capture=<file.png> [--show=intro|fight|big|taunt|break|count|announce|result] [--at=<seconds>]
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
			sim.step(dt)
			_sync_rigs()
			for rig in view.rigs:
				rig.advance(dt)
			_update_banner(dt)
			t += dt
			if t >= at and _is_capture_moment(show):
				break
		for rig in view.rigs:
			rig.set_process(false)
		if show == "big":
			view.arena.set_process(false)   # Hold the impact flash for the shot.
		_refresh_hud()
		if show in ["result", "announce"] and sim.phase == FightSim.Phase.FINISHED:
			_show_result()
			if show == "result":
				_result.reveal_all()
				_ceremony.finish_raise()

	# "--wait" lets the decision announcement run for a while before the shot.
	await get_tree().create_timer(float(GameState.options.get("wait", "0.5"))).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()


func _is_capture_moment(show: String) -> bool:
	match show:
		"break":
			return sim.phase == FightSim.Phase.BREAK and sim.break_time > FightSim.ADVICE_AT + 0.6
		"count":
			return sim.phase == FightSim.Phase.COUNT and sim.count_value >= 2
		"result", "announce":
			return sim.phase == FightSim.Phase.FINISHED and sim._finish_timer > 1.0
		"big":
			return _big_this_step
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
