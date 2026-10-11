class_name ResultPanel
extends Control
## End-of-fight result (720 x 320) with the final cards and what to do next.

signal new_fight_pressed
signal menu_pressed

const W := 720
const H := 320
const BUTTON_W := 256
const BUTTON_H := 56

const METHOD_TITLES := {
	"KO": "KNOCKOUT!",
	"TKO": "TECHNICAL KNOCKOUT",
	"UD": "UNANIMOUS DECISION",
	"MD": "MAJORITY DECISION",
	"SD": "SPLIT DECISION",
	"DRAW": "IT'S A DRAW",
}

var _first_button: Button


func setup(result: Dictionary, red: BoxerData, blue: BoxerData) -> void:
	size = Vector2(W, H)
	add_child(UiTheme.panel(0, 0, W, H, Palette.UI_PANEL, Palette.UI_BORDER, 4))

	var title := UiTheme.label(METHOD_TITLES.get(result["method"], "FIGHT OVER"), UiTheme.TITLE, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	add_child(UiTheme.place(title, 0, 24, W, 32))

	var winner: int = result["winner"]
	var headline := "THE JUDGES CAN'T SEPARATE THEM"
	var colour := Palette.UI_TEXT
	if winner >= 0:
		var boxer := red if winner == 0 else blue
		headline = "%s WINS" % boxer.display_name().to_upper()
		colour = Palette.corner_color(winner)
	var head_label := UiTheme.label(headline, UiTheme.BODY, colour, HORIZONTAL_ALIGNMENT_CENTER)
	UiTheme.fit(head_label, W - 32)
	add_child(UiTheme.place(head_label, 16, 72, W - 32, 24))

	var detail := "AFTER %d ROUNDS" % FightSim.ROUNDS
	if result["method"] in ["KO", "TKO"]:
		detail = "ROUND %d  -  %s" % [result["round"], result["time"]]
		if not str(result["detail"]).is_empty():
			detail += "  -  %s" % str(result["detail"]).to_upper()
	add_child(UiTheme.place(UiTheme.label(detail, UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER), 0, 104, W, 12))

	# Cards, centred as a block: label column + score column.
	var stopped: bool = result["method"] in ["KO", "TKO"]
	var cards_title := "SCORECARDS AT THE STOPPAGE" if stopped else "FINAL SCORECARDS"
	add_child(UiTheme.place(UiTheme.label(cards_title, UiTheme.CAPTION, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_CENTER), 0, 128, W, 12))
	var block_w := 128 + ScorePair.WIDTH
	var block_x := (W - block_w) / 2.0
	for j in Judges.JUDGE_NAMES.size():
		var y := 144 + j * UiTheme.ROW_H
		add_child(UiTheme.place(UiTheme.label(Judges.JUDGE_NAMES[j], UiTheme.CAPTION), block_x, y, 128, UiTheme.ROW_H))
		var pair := ScorePair.new()
		pair.position = Vector2(block_x + 128, y)
		var card: Array = result["cards"][j]
		pair.set_score(card[0], card[1])
		add_child(pair)

	var gap := 32
	var left := (W - BUTTON_W * 2 - gap) / 2.0
	_first_button = _button("NEW FIGHT", left, new_fight_pressed)
	_button("MAIN MENU", left + BUTTON_W + gap, menu_pressed)


func focus_default() -> void:
	_first_button.grab_focus()


func _button(text: String, x: float, pressed_signal: Signal) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	UiTheme.place(b, x, 240, BUTTON_W, BUTTON_H)
	b.pressed.connect(func() -> void: pressed_signal.emit())
	add_child(b)
	return b
