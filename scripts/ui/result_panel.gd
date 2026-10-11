class_name ResultPanel
extends Control
## The end-of-fight panel.
##
## STOPPAGE (KO / TKO) - shown all at once (720 x 352):
##   KNOCKOUT!
##   JOEY JOHNSON WINS
##   ROUND 2  -  2:42  -  COUNTED OUT
##   SCORECARDS AT THE STOPPAGE
##   HAROLD PEMBERTON         10-9
##   ...
##   [ NEW FIGHT ]   [ MAIN MENU ]
##
## DECISION - read out one line at a time, like a ring announcer (800 x 456):
##   THE JUDGES' SCORECARDS
##   JUDGE H. PEMBERTON SCORES THE BOUT
##   29-28 IN FAVOUR OF JOHNSON
##   ... (three judges) ...
##   AND THE WINNER, BY SPLIT DECISION...
##   JOEY JOHNSON!
##   [ NEW FIGHT ]   [ MAIN MENU ]
##
## Tap, click or press Space during the announcement to reveal it all at once.

signal new_fight_pressed
signal menu_pressed
## Emitted the moment the winner (or draw) is read out.
signal winner_announced

const BUTTON_W := 256
const BUTTON_H := 56
const BUTTON_GAP := 32

# --- Stoppage layout --------------------------------------------------------
const STOP_W := 720
const STOP_H := 352
const STOP_NAME_W := 192

# --- Decision layout --------------------------------------------------------
const DEC_W := 800
const DEC_H := 456
const JUDGE_FIRST_Y := 72
const JUDGE_BLOCK_H := 64      # Two lines of text and a gap per judge.
const VERDICT_Y := 280
const WINNER_Y := 312
const DEC_BUTTON_Y := 376

## Seconds into the announcement when each step appears.
const FIRST_JUDGE_AT := 1.2
const JUDGE_EVERY := 2.6
const SCORE_AFTER := 1.0       # Judge's name first, then their score.
const WINNER_PAUSE := 1.4      # Drum roll between "and the winner..." and the name.

const METHOD_TITLES := {
	"KO": "KNOCKOUT!",
	"TKO": "TECHNICAL KNOCKOUT",
	"UD": "UNANIMOUS DECISION",
	"MD": "MAJORITY DECISION",
	"SD": "SPLIT DECISION",
	"DRAW": "IT'S A DRAW",
}

var _first_button: Button
var _steps: Array = []          # [time, Control] revealed in order.
var _clock := 0.0
var _announcing := false
var _announced := false
var _winner_step: Control


func setup(result: Dictionary, red: BoxerData, blue: BoxerData, judges: Judges) -> void:
	if result["method"] in ["KO", "TKO"]:
		_build_stoppage(result, red, blue, judges)
	else:
		_build_decision(result, red, blue, judges)


func focus_default() -> void:
	_first_button.grab_focus()


## Shows everything at once (skips the announcement).
func reveal_all() -> void:
	_clock = 9999.0
	_process(0.0)


func _process(delta: float) -> void:
	if not _announcing:
		return
	_clock += delta
	var all_shown := true
	for step in _steps:
		var item: Control = step[1]
		if not item.visible:
			if _clock >= step[0]:
				item.visible = true
				_on_step_shown(item)
			else:
				all_shown = false
	if all_shown:
		_announcing = false
		_first_button.grab_focus()


func _gui_input(event: InputEvent) -> void:
	if _announcing and event is InputEventMouseButton and event.pressed:
		reveal_all()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if _announcing and event.is_action_pressed("ui_accept"):
		reveal_all()
		get_viewport().set_input_as_handled()


func _on_step_shown(item: Control) -> void:
	if item == _winner_step:
		if not _announced:
			_announced = true
			Sfx.roar(1.0)
			winner_announced.emit()
	elif item is Label:
		Sfx.reveal()


# ============================================================================
#  Stoppage
# ============================================================================

func _build_stoppage(result: Dictionary, red: BoxerData, blue: BoxerData, judges: Judges) -> void:
	size = Vector2(STOP_W, STOP_H)
	add_child(UiTheme.panel(0, 0, STOP_W, STOP_H, Palette.UI_PANEL, Palette.UI_BORDER, 4))

	var title := UiTheme.label(METHOD_TITLES[result["method"]], UiTheme.TITLE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(title, 0, 24, STOP_W, UiTheme.TITLE))

	var winner: int = result["winner"]
	var boxer := red if winner == 0 else blue
	var head := UiTheme.label("%s WINS" % boxer.display_name().to_upper(), UiTheme.BODY, Palette.corner_color(winner), HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.fit(head, STOP_W - 32)
	add_child(UiTheme.place(head, 16, 80, STOP_W - 32, UiTheme.ROW_H))

	var detail := "ROUND %d  -  %s" % [result["round"], result["time"]]
	if not str(result["detail"]).is_empty():
		detail += "  -  %s" % str(result["detail"]).to_upper()
	add_child(UiTheme.place(UiTheme.label(detail, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), 0, 112, STOP_W, UiTheme.CAPTION))

	add_child(UiTheme.place(UiTheme.label("SCORECARDS AT THE STOPPAGE", UiTheme.CAPTION, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), 0, 152, STOP_W, UiTheme.CAPTION))
	var block_w := STOP_NAME_W + ScorePair.WIDTH
	var block_x := (STOP_W - block_w) / 2.0
	for j in judges.panel.size():
		var y := 176 + j * UiTheme.ROW_H
		add_child(UiTheme.place(UiTheme.label(str(judges.panel[j]["name"]).to_upper(), UiTheme.CAPTION), block_x, y, STOP_NAME_W, UiTheme.ROW_H))
		var pair := ScorePair.new()
		pair.position = Vector2(block_x + STOP_NAME_W, y)
		var card: Array = result["cards"][j]
		pair.set_score(card[0], card[1])
		add_child(pair)

	_add_buttons(STOP_W, 272)


# ============================================================================
#  Decision (announced line by line)
# ============================================================================

func _build_decision(result: Dictionary, red: BoxerData, blue: BoxerData, judges: Judges) -> void:
	size = Vector2(DEC_W, DEC_H)
	add_child(UiTheme.panel(0, 0, DEC_W, DEC_H, Palette.UI_PANEL, Palette.UI_BORDER, 4))
	var text_w := DEC_W - 32

	var title := UiTheme.label("THE JUDGES' SCORECARDS", UiTheme.LARGE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(title, 0, 24, DEC_W, UiTheme.LARGE))

	var boxers := [red, blue]
	for j in judges.panel.size():
		var y := JUDGE_FIRST_Y + j * JUDGE_BLOCK_H
		var at := FIRST_JUDGE_AT + j * JUDGE_EVERY
		var who := UiTheme.label("JUDGE %s SCORES THE BOUT" % Officials.short_name(judges.panel[j]), UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.fit(who, text_w)
		_add_step(who, Rect2(16, y, text_w, UiTheme.ROW_H), at)

		var card: Array = result["cards"][j]
		var line := "%d-%d  EVEN" % [card[0], card[1]]
		var colour := Palette.UI_TEXT
		if card[0] != card[1]:
			var leader := 0 if card[0] > card[1] else 1
			line = "%d-%d IN FAVOUR OF %s" % [maxi(card[0], card[1]), mini(card[0], card[1]), boxers[leader].last_name.to_upper()]
			colour = Palette.corner_color(leader)
		var score := UiTheme.label(line, UiTheme.BODY, colour, HORIZONTAL_ALIGNMENT_CENTER)
		UiTheme.fit(score, text_w)
		_add_step(score, Rect2(16, y + 28, text_w, UiTheme.ROW_H), at + SCORE_AFTER)

	var verdict_at := FIRST_JUDGE_AT + judges.panel.size() * JUDGE_EVERY
	var winner: int = result["winner"]
	var lead_in := ""
	var big := ""
	var big_colour := Palette.UI_GOLD
	if winner >= 0:
		var kind := {"UD": "UNANIMOUS", "SD": "SPLIT", "MD": "MAJORITY"}[result["method"]] as String
		lead_in = "AND THE WINNER, BY %s DECISION..." % kind
		big = "%s!" % boxers[winner].display_name().to_upper()
		big_colour = Palette.corner_color(winner)
	else:
		lead_in = "THIS CONTEST IS SCORED A..."
		big = "%s DRAW!" % str(result["detail"])
	var lead := UiTheme.label(lead_in, UiTheme.BODY, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.fit(lead, text_w)
	_add_step(lead, Rect2(16, VERDICT_Y, text_w, UiTheme.ROW_H), verdict_at)

	var name_label := UiTheme.label(big, UiTheme.TITLE, big_colour, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.fit(name_label, text_w)
	_winner_step = _add_step(name_label, Rect2(16, WINNER_Y, text_w, UiTheme.TITLE + 8), verdict_at + WINNER_PAUSE)

	var buttons := _add_buttons(DEC_W, DEC_BUTTON_Y)
	buttons.visible = false
	_steps.append([verdict_at + WINNER_PAUSE + 1.0, buttons])
	_announcing = true


func _add_step(item: Control, rect: Rect2, at: float) -> Control:
	UiTheme.place(item, rect.position.x, rect.position.y, rect.size.x, rect.size.y)
	item.visible = false
	add_child(item)
	_steps.append([at, item])
	return item


## The two buttons, centred, in a container so they can be revealed together.
func _add_buttons(panel_w: float, y: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.place(holder, 0, y, panel_w, BUTTON_H))
	var left := (panel_w - BUTTON_W * 2 - BUTTON_GAP) / 2.0
	_first_button = _button(holder, "NEW FIGHT", left, new_fight_pressed)
	_button(holder, "MAIN MENU", left + BUTTON_W + BUTTON_GAP, menu_pressed)
	return holder


func _button(parent: Control, text: String, x: float, pressed_signal: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, 0, BUTTON_W, BUTTON_H)
	b.pressed.connect(func() -> void: pressed_signal.emit())
	parent.add_child(b)
	return b
