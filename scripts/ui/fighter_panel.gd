class_name FighterPanel
extends Control
## Live condition and punch stats for one boxer (352 x 176).
##
##   RED CORNER                      BOXER
##   HEALTH   [##########      ]      87
##   ENERGY   [#######         ]      64
##   THROWN                           61
##   LANDED                           23
##   SIG. STRIKES                      6    <- hard, clean shots that hurt
##
## Column positions are constants so both panels line up exactly. Rows without
## a bar let their label use the bar's space ("SIG. STRIKES" is long).
## Spacing (measured on screen): 13 px of panel above the caption, between
## the caption and the first row and below the last row; 14 px between rows.

const W := 352
const H := 176
const PAD := 16
const LABEL_W := 112
const BAR_W := 144
const BAR_H := 16
const VALUE_W := 64
const CAPTION_Y := 8
const FIRST_ROW_Y := 31
const ROW_PITCH := 28

var _health_bar: ProgressBar
var _energy_bar: ProgressBar
var _health_fill: StyleBoxFlat
var _values: Dictionary = {}


func setup(boxer: BoxerData, corner: int) -> void:
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiTheme.panel(0, 0, W, H))

	var corner_name := "RED CORNER" if corner == 0 else "BLUE CORNER"
	var title := UiTheme.label(corner_name, UiTheme.CAPTION, Palette.corner_color(corner))
	var style := UiTheme.label(boxer.style_name().to_upper(), UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	add_child(UiTheme.place(title, PAD, CAPTION_Y, W / 2.0 - PAD, 12))
	add_child(UiTheme.place(style, W / 2.0, CAPTION_Y, W / 2.0 - PAD, 12))

	var rows := ["HEALTH", "ENERGY", "THROWN", "LANDED", "SIG. STRIKES"]
	for i in rows.size():
		var y := FIRST_ROW_Y + i * ROW_PITCH
		var has_bar := i < 2
		var label_w := LABEL_W if has_bar else LABEL_W + BAR_W
		add_child(UiTheme.place(UiTheme.label(rows[i]), PAD, y, label_w, UiTheme.ROW_H))
		var value := UiTheme.label("0", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		add_child(UiTheme.place(value, PAD + LABEL_W + BAR_W, y, VALUE_W, UiTheme.ROW_H))
		_values[rows[i]] = value

	_health_fill = UiTheme.box(Palette.UI_GOOD, Palette.UI_GOOD, 0)
	_health_bar = _make_bar(FIRST_ROW_Y, _health_fill)
	_energy_bar = _make_bar(FIRST_ROW_Y + ROW_PITCH, UiTheme.box(Palette.UI_GOLD, Palette.UI_GOLD, 0))


func refresh(f: Fighter) -> void:
	_health_bar.value = f.health
	_energy_bar.value = f.energy
	_values["HEALTH"].text = str(ceili(f.health))
	_values["ENERGY"].text = str(ceili(f.energy))
	_values["THROWN"].text = str(int(f.fight_stats["thrown"]))
	_values["LANDED"].text = str(int(f.fight_stats["landed"]))
	_values["SIG. STRIKES"].text = str(int(f.fight_stats["significant"]))
	var colour := Palette.UI_GOOD
	if f.health < 30.0:
		colour = Palette.UI_BAD
	elif f.health < 60.0:
		colour = Palette.UI_WARN
	_health_fill.bg_color = colour


func _make_bar(row_y: float, fill: StyleBoxFlat) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", UiTheme.box(Palette.UI_PANEL_DARK, Palette.UI_TEXT_DIM, 2))
	fill.set_content_margin_all(0)
	bar.add_theme_stylebox_override("fill", fill)
	UiTheme.place(bar, PAD + LABEL_W, row_y + (UiTheme.ROW_H - BAR_H) / 2.0, BAR_W, BAR_H)
	add_child(bar)
	return bar
