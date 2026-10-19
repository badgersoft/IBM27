class_name UiTheme
extends RefCounted
## One place for the look of every menu and panel.
##
## Layout rules used throughout the UI (please keep to them):
##  - Everything sits on an 8 px grid; outer margins and gaps are 16 px.
##  - Only these font sizes are used, all multiples of the pixel font's 8 px
##    design grid so letters stay crisp: CAPTION 8, BODY 16, LARGE 24, TITLE 32,
##    HUGE 48.
##  - Tables use fixed column widths in multiples of 16 (one character), and
##    numbers are right-aligned, so columns of figures always line up.

const FONT := preload("res://assets/fonts/PressStart2P.woff2")

const CAPTION := 8
const BODY := 16
const LARGE := 24
const TITLE := 32
const HUGE := 48

## Width of one character at BODY size (the font is monospaced).
const CHAR_W := 16
const ROW_H := 24
const GAP := 16

static var _theme: Theme


## The shared Theme. Built once, on first use.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = FONT
	_theme.default_font_size = BODY

	_theme.set_color("font_color", "Label", Palette.UI_TEXT)

	_theme.set_stylebox("normal", "Button", box(Palette.UI_PANEL, Palette.UI_BORDER, 4))
	_theme.set_stylebox("hover", "Button", box(Palette.UI_PANEL.lightened(0.12), Palette.UI_GOLD, 4))
	_theme.set_stylebox("pressed", "Button", box(Palette.UI_PANEL_DARK, Palette.UI_GOLD, 4))
	_theme.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Palette.UI_TEXT, 2))
	_theme.set_color("font_color", "Button", Palette.UI_TEXT)
	_theme.set_color("font_hover_color", "Button", Palette.UI_GOLD)
	_theme.set_color("font_pressed_color", "Button", Palette.UI_GOLD)
	_theme.set_color("font_focus_color", "Button", Palette.UI_TEXT)
	# Greyed out: no gold, dim text.
	_theme.set_stylebox("disabled", "Button", box(Palette.UI_PANEL_DARK, Color(Palette.UI_TEXT_DIM, 0.35), 4))
	_theme.set_color("font_disabled_color", "Button", Color(Palette.UI_TEXT_DIM, 0.55))

	# Text boxes (names) and scrolling lists (countries, cities, nicknames).
	_theme.set_stylebox("normal", "LineEdit", box(Palette.UI_PANEL_DARK, Color(Palette.UI_TEXT_DIM, 0.6), 2, 8))
	_theme.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), Palette.UI_GOLD, 2))
	_theme.set_color("font_color", "LineEdit", Palette.UI_TEXT)
	_theme.set_color("caret_color", "LineEdit", Palette.UI_GOLD)
	_theme.set_stylebox("panel", "ItemList", box(Palette.UI_PANEL_DARK, Color(Palette.UI_TEXT_DIM, 0.6), 2, 8))
	_theme.set_stylebox("focus", "ItemList", box(Color(0, 0, 0, 0), Palette.UI_GOLD, 2))
	_theme.set_stylebox("selected", "ItemList", box(Palette.UI_PANEL.lightened(0.15), Palette.UI_GOLD, 2))
	_theme.set_stylebox("selected_focus", "ItemList", box(Palette.UI_PANEL.lightened(0.15), Palette.UI_GOLD, 2))
	_theme.set_stylebox("hovered", "ItemList", box(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 0))
	_theme.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	_theme.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	_theme.set_color("font_color", "ItemList", Palette.UI_TEXT)
	_theme.set_color("font_selected_color", "ItemList", Palette.UI_GOLD)
	_theme.set_color("font_hovered_color", "ItemList", Palette.UI_GOLD)
	_theme.set_constant("v_separation", "ItemList", 8)
	_theme.set_color("guide_color", "ItemList", Color(0, 0, 0, 0))

	_theme.set_stylebox("panel", "Panel", box(Palette.UI_PANEL, Palette.UI_BORDER, 2))
	_theme.set_stylebox("panel", "PanelContainer", box(Palette.UI_PANEL, Palette.UI_BORDER, 2))
	return _theme


## A flat, square-cornered box with a border - the only panel style we use.
static func box(bg: Color, border: Color, border_width: int, padding: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.set_content_margin_all(padding)
	return s


## Creates a Label. [param width] > 0 fixes its width (handy for table cells).
static func label(text: String, size: int = BODY, color: Color = Palette.UI_TEXT,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = 0.0) -> Label:
	var l := Label.new()
	l.text = text
	# Set the font directly (not only via the Theme) so the label measures its
	# height correctly before it is added to the scene - otherwise small text
	# is positioned using the engine's fallback font and sits a few px low.
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	if width > 0.0:
		l.custom_minimum_size.x = width
	return l


## Places [param node] at an exact position and size inside its parent.
static func place(node: Control, x: float, y: float, w: float, h: float) -> Control:
	node.position = Vector2(x, y)
	node.size = Vector2(w, h)
	return node


## A solid colour block (used for accent stripes and dividers).
static func block(color: Color, x: float, y: float, w: float, h: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	place(r, x, y, w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A panel drawn as a plain Panel node with our box style.
static func panel(x: float, y: float, w: float, h: float, bg: Color = Palette.UI_PANEL,
		border: Color = Palette.UI_BORDER, border_width: int = 2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", box(bg, border, border_width))
	place(p, x, y, w, h)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Steps text down through the standard sizes until it fits [param width]
## (keeps tables tidy with unusually long names instead of overflowing).
static func fit(l: Label, width: float) -> void:
	var size := l.get_theme_font_size("font_size")
	for smaller in [HUGE, TITLE, LARGE, BODY, CAPTION]:
		if l.text.length() * size <= width:
			break
		if smaller < size:
			size = smaller
	l.add_theme_font_size_override("font_size", size)


## Gives a Label a dark pixel outline so it reads over the busy arena.
static func outline(l: Label, thickness: int = 8) -> void:
	l.add_theme_constant_override("outline_size", thickness)
	l.add_theme_color_override("font_outline_color", Color("08080c"))
