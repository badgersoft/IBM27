class_name Nameplate
extends Control
## Boxer name plate shown above the ring (456 x 48).
##
##   |#| MARCUS JOHNSON                          <- name, BODY size
##   |#| "THE HAMMER"   22-3-1 (14 KO)           <- caption size
##
## The red corner's plate reads from the left with its colour stripe on the
## left; the blue corner's plate is the mirror image.

const W := 456
const H := 48
const STRIPE := 8
const PAD := 16


func setup(boxer: BoxerData, corner: int) -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left_side := corner == 0
	var accent := Palette.corner_color(corner)

	add_child(UiTheme.panel(0, 0, W, H, Palette.UI_PANEL_DARK))
	add_child(UiTheme.block(accent, 2 if left_side else W - 2 - STRIPE, 2, STRIPE, H - 4))

	var text_x := 2 + STRIPE + PAD if left_side else PAD
	var text_w := W - (2 + STRIPE + PAD) - PAD
	var align := HORIZONTAL_ALIGNMENT_LEFT if left_side else HORIZONTAL_ALIGNMENT_RIGHT

	var name_label := UiTheme.label(boxer.display_name().to_upper(), UiTheme.BODY, Palette.UI_TEXT, align)
	UiTheme.fit(name_label, text_w)
	add_child(UiTheme.place(name_label, text_x, 6, text_w, 24))

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", UiTheme.GAP)
	line.alignment = BoxContainer.ALIGNMENT_BEGIN if left_side else BoxContainer.ALIGNMENT_END
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.place(line, text_x, 30, text_w, 12))
	var nick := UiTheme.label("", UiTheme.CAPTION, Palette.UI_GOLD)
	var record := UiTheme.label(boxer.record_with_kos(), UiTheme.CAPTION, Palette.UI_TEXT_DIM)
	nick.clip_text = false
	record.clip_text = false
	if not boxer.nickname.is_empty():
		nick.text = "\"%s\"" % boxer.nickname.to_upper()
	# Keep the nickname nearest the stripe on both plates.
	if left_side:
		line.add_child(nick)
		line.add_child(record)
	else:
		line.add_child(record)
		line.add_child(nick)
	nick.visible = not nick.text.is_empty()
