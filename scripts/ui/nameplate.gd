class_name Nameplate
extends Control
## Boxer name plate shown above the ring (520 x 56).
##
##   |#| MARCUS JOHNSON                    22-3-1 (14 KO)   <- name, record
##   |#| "THE HAMMER"                                       <- nickname
##
## Everything is 16 px text. The name and nickname sit nearest the colour
## stripe; the record is at the far end of the top line. The red corner's
## plate reads from the left with its stripe on the left; the blue corner's
## plate is the mirror image. A name too long to share the line with the
## record is shortened to an initial and surname ("T. WASHINGTON"). A
## champion's IBC belt (BeltIcon, 48 x 16) sits under his record, at the far
## end of the nickname line, so it never squeezes the name.
##
## Rows (measured on screen): 8 px border-to-name, 8 px name-to-nickname and
## 8 px nickname-to-border. The label tops below include the font's leading.

const W := 520
const H := 56
const STRIPE := 8
const PAD := 16
const NAME_Y := 6
const NICK_Y := 28


func setup(boxer: BoxerData, corner: int) -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_side := corner == 0
	var accent := Palette.corner_color(corner)

	add_child(UiTheme.panel(0, 0, W, H, Palette.UI_PANEL_DARK))
	add_child(UiTheme.block(accent, 2 if left_side else W - 2 - STRIPE, 2, STRIPE, H - 4))

	var text_x := 2 + STRIPE + PAD if left_side else PAD
	var text_w := W - (2 + STRIPE + PAD) - PAD
	var near := HORIZONTAL_ALIGNMENT_LEFT if left_side else HORIZONTAL_ALIGNMENT_RIGHT
	var far := HORIZONTAL_ALIGNMENT_RIGHT if left_side else HORIZONTAL_ALIGNMENT_LEFT

	var record_text := boxer.record_with_kos()
	var record := UiTheme.label(record_text, UiTheme.BODY, Palette.UI_TEXT_DIM, far)
	add_child(UiTheme.place(record, text_x, NAME_Y, text_w, UiTheme.ROW_H))

	var name_w := text_w - record_text.length() * UiTheme.CHAR_W - UiTheme.GAP
	var name_text := boxer.display_name().to_upper()
	if name_text.length() * UiTheme.CHAR_W > name_w:
		name_text = "%s. %s" % [boxer.first_name.substr(0, 1).to_upper(), boxer.last_name.to_upper()]
	var name_label := UiTheme.label(name_text, UiTheme.BODY, Palette.UI_TEXT, near)
	UiTheme.fit(name_label, name_w)
	var name_x := text_x if left_side else text_x + text_w - name_w
	add_child(UiTheme.place(name_label, name_x, NAME_Y, name_w, UiTheme.ROW_H))
	if GameState.is_champion(boxer):
		# Level with the nickname's capitals (4 px into its 24 px row).
		var belt := BeltIcon.new(2)
		var belt_x: float = text_x + text_w - belt.size.x if left_side else text_x
		belt.position = Vector2(belt_x, NICK_Y + 4)
		add_child(belt)

	if not boxer.nickname.is_empty():
		var nick := UiTheme.label("\"%s\"" % boxer.nickname.to_upper(), UiTheme.BODY, Palette.UI_GOLD, near)
		add_child(UiTheme.place(nick, text_x, NICK_Y, text_w, UiTheme.ROW_H))
