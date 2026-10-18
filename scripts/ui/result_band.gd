class_name ResultBand
extends Control
## The end-of-fight announcement, kept to a slim two-line band over the crowd
## so the ring stays clear for the boxers and referee waiting for the verdict.
##
## It covers the whole arena overlay but only draws in two places:
##
##   y  8  +--------------------------------------------------------------+
##         |          JUDGE Y. SHIMADA SCORES THE BOUT...   (lead-in, 24) |
##         |             29-28 IN FAVOUR OF HAYES           (payoff, 32)  |
##   y 88  +--------------------------------------------------------------+
##
##                 ( boxers and referee stand in the ring )
##
##                          [ CONTINUE ]            <- on the apron
##
## The top line is the announcer's lead-in and the bigger line under it the
## payoff: each judge's name, then his score, then "AND THE WINNER, BY ...
## DECISION..." and the name, billed with any nickname between first name
## and surname (JAKE "MAMMOTH" HARRIS!). As each judge is read out his row of the
## official scorecard under the ring is filled in (judge_revealed).
## A stoppage gets to the name quickly. In a title fight the name is called
## as "...AND STILL IBC HEAVYWEIGHT CHAMPION" or "...AND NEW IBC HEAVYWEIGHT
## CHAMPION". Tap, click or Space skips to the end.

## CONTINUE pressed (on to the post-fight stats).
signal continue_pressed
## Emitted when judge [param index]'s score is read out.
signal judge_revealed(index: int)
## Emitted the moment the winner (or draw) is read out.
signal winner_announced

## Ink is spaced evenly: 9 px of panel above, between and below the lines.
const BAND := Rect2(16, 8, 1240, 80)
const PAD := 16                 ## Inside the band, left and right.
const LEAD_Y := 11              ## 24 px text.
const PAYOFF_Y := 41            ## 32 px text.

const BUTTON_W := 256
const BUTTON_H := 48

## Seconds into the announcement when each step happens. The waits are
## longer than a ring announcer strictly needs: the pause is the drama.
const FIRST_JUDGE_AT := 2.0
const JUDGE_EVERY := 4.6
const SCORE_AFTER := 2.5        ## Judge's name first, then his score.
const WINNER_PAUSE := 2.4       ## Drum roll between "and the winner..." and the name.
const STOPPAGE_VERDICT_AT := 0.4
const BUTTONS_AFTER := 1.0
## After a drawn title fight, how long before the champion is named as
## keeping his title.
const TITLE_AFTER_DRAW := 3.0

const METHOD_TITLES := {
	"KO": "KNOCKOUT!",
	"TKO": "TECHNICAL KNOCKOUT",
	"UD": "UNANIMOUS DECISION",
	"MD": "MAJORITY DECISION",
	"SD": "SPLIT DECISION",
	"DRAW": "IT'S A DRAW",
}

var _lead: Label
var _payoff: Label
var _buttons: Control
var _first_button: Button

## [time, Callable] in order; each runs once when the clock passes its time.
var _steps: Array = []
var _next_step := 0
var _clock := 0.0
var _announced := false
## Title fight details: is one on the line, the champion's corner (-1 if
## the title is vacant) and the division's name.
var _title := false
var _holder := -1
var _division := ""


## [param buttons_mid_y] is the overlay y the buttons are centred on. For a
## title fight, [param title_holder] is the champion's corner (-1 if vacant).
func setup(result: Dictionary, red: BoxerData, blue: BoxerData, judges: Judges, buttons_mid_y: float,
		title_fight: bool = false, title_holder: int = -1) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title = title_fight
	_holder = title_holder
	_division = red.division_name().to_upper()
	add_child(UiTheme.panel(BAND.position.x, BAND.position.y, BAND.size.x, BAND.size.y))
	var inner_w := BAND.size.x - PAD * 2
	_lead = UiTheme.label("", UiTheme.LARGE, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(_lead, BAND.position.x + PAD, BAND.position.y + LEAD_Y, inner_w, UiTheme.ROW_H))
	_payoff = UiTheme.label("", UiTheme.TITLE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(_payoff, BAND.position.x + PAD, BAND.position.y + PAYOFF_Y, inner_w, UiTheme.TITLE))

	_buttons = Control.new()
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.visible = false
	add_child(UiTheme.place(_buttons, 0, roundf(buttons_mid_y - BUTTON_H / 2.0), size.x, BUTTON_H))
	_first_button = _button("CONTINUE", roundf((size.x - BUTTON_W) / 2.0), continue_pressed)

	if result["method"] in ["KO", "TKO"]:
		_plan_stoppage(result, [red, blue], judges)
	else:
		_plan_decision(result, [red, blue], judges)


## Runs every remaining step at once (skips the announcement).
func reveal_all() -> void:
	_clock = INF
	_advance()


func is_announcing() -> bool:
	return _next_step < _steps.size()


func _process(delta: float) -> void:
	if not is_announcing():
		return
	_clock += delta
	_advance()


func _advance() -> void:
	while _next_step < _steps.size() and _clock >= _steps[_next_step][0]:
		var action: Callable = _steps[_next_step][1]
		_next_step += 1
		action.call()


func _gui_input(event: InputEvent) -> void:
	if is_announcing() and event is InputEventMouseButton and event.pressed:
		reveal_all()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if is_announcing() and event.is_action_pressed("ui_accept"):
		reveal_all()
		get_viewport().set_input_as_handled()


# ============================================================================
#  The running order
# ============================================================================

func _plan_decision(result: Dictionary, boxers: Array, judges: Judges) -> void:
	_at(0.0, _say.bind("LADIES AND GENTLEMEN, WE GO TO THE SCORECARDS", "", Palette.UI_TEXT))
	for j in judges.panel.size():
		var at := FIRST_JUDGE_AT + j * JUDGE_EVERY
		var who := "JUDGE %s SCORES THE BOUT..." % Officials.short_name(judges.panel[j])
		_at(at, _say.bind(who, "", Palette.UI_TEXT))
		var card: Array = result["cards"][j]
		var line := "%d-%d  EVEN" % [card[0], card[1]]
		var colour := Palette.UI_TEXT
		if card[0] != card[1]:
			var leader := 0 if card[0] > card[1] else 1
			line = "%d-%d IN FAVOUR OF %s" % [maxi(card[0], card[1]), mini(card[0], card[1]), boxers[leader].last_name.to_upper()]
			colour = Palette.corner_color(leader)
		_at(at + SCORE_AFTER, _say.bind(who, line, colour))
		_at(at + SCORE_AFTER, judge_revealed.emit.bind(j))
		_at(at + SCORE_AFTER, _crowd_reacts.bind(card, judges.fair_totals()))

	var verdict_at := FIRST_JUDGE_AT + judges.panel.size() * JUDGE_EVERY
	var winner: int = result["winner"]
	var lead_in := "THIS CONTEST IS SCORED A..."
	var verdict := "%s DRAW!" % str(result["detail"])
	var colour := Palette.UI_GOLD
	var name_lead := lead_in
	if winner >= 0:
		var kind := {"UD": "UNANIMOUS", "SD": "SPLIT", "MD": "MAJORITY"}[result["method"]] as String
		lead_in = "AND THE WINNER, BY %s DECISION..." % kind
		name_lead = _title_line(winner) if _title else lead_in
		verdict = "%s!" % boxers[winner].billing_name().to_upper()
		colour = Palette.corner_color(winner)
	_at(verdict_at, _say.bind(lead_in, "", Palette.UI_TEXT))
	_at(verdict_at + WINNER_PAUSE, _announce.bind(name_lead, verdict, colour))
	var buttons_at := verdict_at + WINNER_PAUSE + BUTTONS_AFTER
	if _title and winner < 0:
		# A draw: the champion keeps his title (a vacant one stays vacant).
		var after := verdict_at + WINNER_PAUSE + TITLE_AFTER_DRAW
		if _holder >= 0:
			var champ := "%s!" % boxers[_holder].billing_name().to_upper()
			_at(after, _say.bind(_title_line(_holder), champ, Palette.corner_color(_holder)))
		else:
			_at(after, _say.bind("THE %s %s TITLE..." % [Rankings.TITLE_NAME, _division], "REMAINS VACANT", Palette.UI_GOLD))
		buttons_at = after + BUTTONS_AFTER
	_at(buttons_at, _show_buttons)


func _plan_stoppage(result: Dictionary, boxers: Array, judges: Judges) -> void:
	for j in judges.panel.size():
		_at(0.0, judge_revealed.emit.bind(j))
	var winner: int = result["winner"]
	var how := "KNOCKOUT" if result["method"] == "KO" else "TKO"
	var lead_in := "AND THE WINNER, BY %s IN ROUND %d AT %s..." % [how, result["round"], result["time"]]
	_at(STOPPAGE_VERDICT_AT, _say.bind(lead_in, "", Palette.UI_TEXT))
	var name_at := STOPPAGE_VERDICT_AT + WINNER_PAUSE
	var name_lead := _title_line(winner) if _title else lead_in
	_at(name_at, _announce.bind(name_lead, "%s!" % boxers[winner].billing_name().to_upper(), Palette.corner_color(winner)))
	_at(name_at + BUTTONS_AFTER, _show_buttons)


## "...AND STILL IBC HEAVYWEIGHT CHAMPION" for a champion who keeps his
## title, "...AND NEW IBC HEAVYWEIGHT CHAMPION" for anyone else.
func _title_line(corner: int) -> String:
	var still := corner == _holder
	return "...AND %s %s %s CHAMPION" % ["STILL" if still else "NEW", Rankings.TITLE_NAME, _division]


func _at(time: float, action: Callable) -> void:
	_steps.append([time, action])
	_steps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


## Shows a lead-in line and (optionally) its payoff under it.
func _say(lead: String, payoff: String, colour: Color) -> void:
	_set_text(_lead, lead, Palette.UI_TEXT, UiTheme.LARGE)
	_set_text(_payoff, payoff, colour, UiTheme.TITLE)


## The crowd hears a judge's score: a small cheer if it looks fair, an
## "oooh" if it does not. "Fair" is judged against a neutral card of the
## fight (what the crowd saw): the same boxer ahead (or both level) and no
## more than 2 points out - or, in a toss-up fight, any close card.
func _crowd_reacts(card: Array, fair: Array) -> void:
	var judge_margin: int = card[0] - card[1]
	var fair_margin: int = fair[0] - fair[1]
	var same_call := signi(judge_margin) == signi(fair_margin) and absi(judge_margin - fair_margin) <= 2
	var toss_up := absi(fair_margin) <= 1 and absi(judge_margin) <= 1
	if same_call or toss_up:
		Sfx.cheer()
	else:
		Sfx.oooh()


func _announce(lead: String, verdict: String, colour: Color) -> void:
	_set_text(_lead, lead, Palette.UI_TEXT, UiTheme.LARGE)
	_set_text(_payoff, verdict, colour, UiTheme.TITLE)
	if not _announced:
		_announced = true
		Sfx.roar(1.0)
		winner_announced.emit()


func _set_text(label: Label, text: String, colour: Color, font_size: int) -> void:
	label.text = text
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", font_size)
	UiTheme.fit(label, label.size.x)


func _show_buttons() -> void:
	_buttons.visible = true
	_first_button.grab_focus()


func _button(text: String, x: float, pressed_signal: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, 0, BUTTON_W, BUTTON_H)
	b.pressed.connect(func() -> void: pressed_signal.emit())
	_buttons.add_child(b)
	return b
