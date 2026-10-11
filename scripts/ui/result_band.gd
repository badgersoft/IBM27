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
##                     [ NEW FIGHT ]   [ MAIN MENU ]    <- on the apron
##
## The top line is the announcer's lead-in and the bigger line under it the
## payoff: each judge's name, then his score, then "AND THE WINNER, BY ...
## DECISION..." and the name. As each judge is read out his row of the
## official scorecard under the ring is filled in (judge_revealed).
## A stoppage gets to the name quickly. Tap, click or Space skips to the end.

signal new_fight_pressed
signal menu_pressed
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
const BUTTON_GAP := 32

## Seconds into the announcement when each step happens.
## Each wait is a second longer than a ring announcer strictly needs: the
## pause is the drama.
const FIRST_JUDGE_AT := 2.0
const JUDGE_EVERY := 3.6
const SCORE_AFTER := 2.0        ## Judge's name first, then his score.
const WINNER_PAUSE := 2.4       ## Drum roll between "and the winner..." and the name.
const STOPPAGE_VERDICT_AT := 0.4
const BUTTONS_AFTER := 1.0

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


## [param buttons_mid_y] is the overlay y the buttons are centred on.
func setup(result: Dictionary, red: BoxerData, blue: BoxerData, judges: Judges, buttons_mid_y: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	var left := roundf((size.x - BUTTON_W * 2 - BUTTON_GAP) / 2.0)
	_first_button = _button("NEW FIGHT", left, new_fight_pressed)
	_button("MAIN MENU", left + BUTTON_W + BUTTON_GAP, menu_pressed)

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

	var verdict_at := FIRST_JUDGE_AT + judges.panel.size() * JUDGE_EVERY
	var winner: int = result["winner"]
	var lead_in := "THIS CONTEST IS SCORED A..."
	var verdict := "%s DRAW!" % str(result["detail"])
	var colour := Palette.UI_GOLD
	if winner >= 0:
		var kind := {"UD": "UNANIMOUS", "SD": "SPLIT", "MD": "MAJORITY"}[result["method"]] as String
		lead_in = "AND THE WINNER, BY %s DECISION..." % kind
		verdict = "%s!" % boxers[winner].display_name().to_upper()
		colour = Palette.corner_color(winner)
	_at(verdict_at, _say.bind(lead_in, "", Palette.UI_TEXT))
	_at(verdict_at + WINNER_PAUSE, _announce.bind(lead_in, verdict, colour))
	_at(verdict_at + WINNER_PAUSE + BUTTONS_AFTER, _show_buttons)


func _plan_stoppage(result: Dictionary, boxers: Array, judges: Judges) -> void:
	for j in judges.panel.size():
		_at(0.0, judge_revealed.emit.bind(j))
	var winner: int = result["winner"]
	var how := "KNOCKOUT" if result["method"] == "KO" else "TKO"
	var lead_in := "AND THE WINNER, BY %s IN ROUND %d AT %s..." % [how, result["round"], result["time"]]
	_at(STOPPAGE_VERDICT_AT, _say.bind(lead_in, "", Palette.UI_TEXT))
	var name_at := STOPPAGE_VERDICT_AT + WINNER_PAUSE
	_at(name_at, _announce.bind(lead_in, "%s!" % boxers[winner].display_name().to_upper(), Palette.corner_color(winner)))
	_at(name_at + BUTTONS_AFTER, _show_buttons)


func _at(time: float, action: Callable) -> void:
	_steps.append([time, action])
	_steps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


## Shows a lead-in line and (optionally) its payoff under it.
func _say(lead: String, payoff: String, colour: Color) -> void:
	_set_text(_lead, lead, Palette.UI_TEXT, UiTheme.LARGE)
	_set_text(_payoff, payoff, colour, UiTheme.TITLE)
	Sfx.reveal()


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
