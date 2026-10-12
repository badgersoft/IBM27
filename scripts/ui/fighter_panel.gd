class_name FighterPanel
extends Control
## Live condition and punch stats for one boxer (352 x 128).
##
##   RED CORNER                      BOXER
##   HEALTH   [##########      ]      87
##   ENERGY   [#######         ]      64
##   THROWN                           61
##   LANDED                           23
##
## Column positions are constants so both panels line up exactly.

const W := 352
const H := 128
const PAD := 16
const LABEL_W := 112
const BAR_W := 144
const BAR_H := 16
const VALUE_W := 64
const FIRST_ROW_Y := 27

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
	add_child(UiTheme.place(title, PAD, 7, W / 2.0 - PAD, 12))
	add_child(UiTheme.place(style, W / 2.0, 7, W / 2.0 - PAD, 12))

	var rows := ["HEALTH", "ENERGY", "THROWN", "LANDED"]
	for i in rows.size():
		var y := FIRST_ROW_Y + i * UiTheme.ROW_H
		add_child(UiTheme.place(UiTheme.label(rows[i]), PAD, y, LABEL_W, UiTheme.ROW_H))
		var value := UiTheme.label("0", UiTheme.BODY, Palette.UI_TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		add_child(UiTheme.place(value, PAD + LABEL_W + BAR_W, y, VALUE_W, UiTheme.ROW_H))
		_values[rows[i]] = value

	_health_fill = UiTheme.box(Palette.UI_GOOD, Palette.UI_GOOD, 0)
	_health_bar = _make_bar(FIRST_ROW_Y, _health_fill)
	_energy_bar = _make_bar(FIRST_ROW_Y + UiTheme.ROW_H, UiTheme.box(Palette.UI_GOLD, Palette.UI_GOLD, 0))


func refresh(f: Fighter) -> void:
	_health_bar.value = f.health
	_energy_bar.value = f.energy
	_values["HEALTH"].text = str(ceili(f.health))
	_values["ENERGY"].text = str(ceili(f.energy))
	_values["THROWN"].text = str(int(f.fight_stats["thrown"]))
	_values["LANDED"].text = str(int(f.fight_stats["landed"]))
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
