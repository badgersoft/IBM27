extends Control
## Developer tool: the IBC belt designs side by side, to choose from. The
## current belt (BeltIcon) is first, then the candidates, each at the sizes
## the game uses (x2 on the name plates, x3 in the Boxers list, x4 on the
## profile) and in a Boxers list row next to a champion's name.
##
##   godot --path . scenes/debug/belt_sheet.tscn -- --capture=/tmp/belts.png

const FRAME_SIZE := Vector2(1280, 800)
const FIRST_ROW_Y := 104
const ROW_H := 136
const ROW_GAP := 0
## Column x positions: label, x2, x3, x4, then the list row.
const LABEL_X := 32
const SCALE_X := [336, 432, 560]
const SCALES := [2, 3, 4]
const LIST_X := 736
const LIST_W := 496

const NOTES := [
	"Strap with square plates",
	"Oval plate, engraved ring and star",
	"Shield plate engraved IBC",
	"Round plate engraved with a globe",
	"Oval plate set with a red stone",
]

const PALETTE := {
	"K": Color("4a4a54"),
	"k": Color("161618"),
	"z": Color("08080a"),
	"x": Color("8a8a94"),
	"o": Color("3c4048"),
	"d": Color("7e8494"),
	"s": Color("c4c8d2"),
	"w": Color("f4f6fa"),
	"g": Color("5c6270"),
	"R": Color("c0202a"),
	"r": Color("ff7078"),
}
const DESIGNS := [
	["CLASSIC", [
		".............oooooo.............",
		"...........oowwwsssoo...........",
		"...oooo...owwwwsssssso...oooo...",
		".KowwwwoKKowwwggggsssoKKowwwwoK.",
		"kkowssdoxowwsgswwsgsssokowssdokk",
		"kkowggdokowsgswwwwsgddokowggdokk",
		"kkowggdokossgswwwwsgddokowggdokk",
		"kkowssdoxosssgswwsgdddokowssdokk",
		".zowdddozzosssggggdddozzowdddoz.",
		"...oooo...osssssdddddo...oooo...",
		"...........oossddddoo...........",
		".............oooooo.............",
	]],
	["CREST", [
		"..........ooooooooooooo.........",
		".........owwwwwwwwwwwwwo........",
		"...oooo..owgggsggsssggdo.oooo...",
		".KowwwwoKowsgssgsgsgssdoowwwwoK.",
		"kkowssdoxowsgssggssgssdoowssdokk",
		"kkowssdokowsgssgsgsgssdoowssdokk",
		"kkkowdokkkogggsggsssggokkowdokkk",
		"kkxowdokxkxowsssssssdoxkxowdokkk",
		".zzzoozzzzzzowsssssdozzzzzoozzz.",
		"....oo.......owsssdo......oo....",
		"..............owddo.............",
		"...............ooo..............",
	]],
	["GLOBE", [
		"..............oooo..............",
		"............oowwssoo............",
		"....oo.....owwggggsso.....oo....",
		".KKowsoKKKKowggggsgsoKKKKowsoKK.",
		"kkowsssoxkowgssgsssgsoxkowsssokk",
		"kkossssokkowggggggggdokkossssokk",
		"kkosssdokkosgssgsssgdokkosssdokk",
		"kkosssdoxkosgssgssdgdoxkosssdokk",
		".zzosdozzzzosggggdgdozzzzosdozz.",
		"....oo.....ossggggddo.....oo....",
		"............oosdddoo............",
		"..............oooo..............",
	]],
	["JEWEL", [
		".............oooooo.............",
		"...........oowwwsssoo...........",
		"....oo....owwwwssssswo....oo....",
		".KKowsoKKKowwwoooosssoKKKowsoKK.",
		"kkowsssoxowwsorrRRosssokowsssokk",
		"kkosrRsokowssorRRRosddokosrRsokk",
		"kkosRRdokosssoRRRRoddwokosRRdokk",
		"kkosssdoxosssoRRRRodddokosssdokk",
		".zzosdozzzosssoooodddozzzosdozz.",
		"....oo....owssssddddwo....oo....",
		"...........oossdwddoo...........",
		".............oooooo.............",
	]],
]


## Draws one of DESIGNS: a grid of palette letters, [member pixel] screen
## pixels to a grid square ("." is see-through).
class GridBelt extends Control:
	var rows: Array = []
	var pixel := 2

	func _init(grid: Array, pixel_size: int) -> void:
		rows = grid
		pixel = pixel_size
		size = Vector2(str(rows[0]).length(), rows.size()) * pixel
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for y in rows.size():
			var row: String = rows[y]
			for x in row.length():
				var c := row[x]
				if c != ".":
					draw_rect(Rect2(x * pixel, y * pixel, pixel, pixel), PALETTE[c])


func _ready() -> void:
	theme = UiTheme.get_theme()
	add_child(UiTheme.block(Palette.UI_BACKGROUND, 0, 0, FRAME_SIZE.x, FRAME_SIZE.y))
	add_child(UiTheme.place(UiTheme.label("IBC BELT DESIGNS", UiTheme.TITLE, Palette.UI_GOLD), 24, 24, 640, UiTheme.TITLE))
	var captions := ["NAME PLATE X2", "LIST X3", "PROFILE X4"]
	for i in 3:
		add_child(UiTheme.place(UiTheme.label(captions[i], UiTheme.CAPTION, Palette.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER),
				SCALE_X[i] - 24, 80, 144 + 0 if i == 2 else 128, UiTheme.CAPTION))
	add_child(UiTheme.place(UiTheme.label("IN THE BOXERS LIST", UiTheme.CAPTION, Palette.UI_TEXT_DIM), LIST_X + 16, 80, 320, UiTheme.CAPTION))

	var count := 1 + DESIGNS.size()
	for i in count:
		var y := FIRST_ROW_Y + i * ROW_H
		add_child(UiTheme.panel(16, y, FRAME_SIZE.x - 32, ROW_H - 16))
		var title := "%s  %s" % [char(65 + i), "CURRENT" if i == 0 else str(DESIGNS[i - 1][0])]
		add_child(UiTheme.place(UiTheme.label(title, UiTheme.LARGE, Palette.UI_GOLD if i > 0 else Palette.UI_TEXT), LABEL_X, y + 28, 288, UiTheme.LARGE))
		add_child(UiTheme.place(UiTheme.label(NOTES[i].to_upper(), UiTheme.CAPTION, Palette.UI_TEXT_DIM), LABEL_X, y + 72, 296, UiTheme.CAPTION))
		var mid := y + (ROW_H - 16) / 2.0
		for s in 3:
			var belt := _belt(i, SCALES[s])
			belt.position = Vector2(SCALE_X[s] + (80 if s == 0 else (112 if s == 1 else 144)) / 2.0 - belt.size.x / 2.0, mid - belt.size.y / 2.0).round()
			add_child(belt)
		# A Boxers list row: rank, name, then the belt at x3.
		add_child(UiTheme.block(Color(1, 1, 1, 0.04), LIST_X, y + 24, LIST_W, 72))
		add_child(UiTheme.place(UiTheme.label("C", UiTheme.BODY, Palette.UI_GOLD, HORIZONTAL_ALIGNMENT_RIGHT), LIST_X + 8, mid - 12, 32, UiTheme.ROW_H))
		var name_text := "A. PEREIRA"
		add_child(UiTheme.place(UiTheme.label(name_text, UiTheme.BODY, Palette.UI_TEXT), LIST_X + 56, mid - 12, 200, UiTheme.ROW_H))
		var list_belt := _belt(i, 3)
		list_belt.position = Vector2(LIST_X + 56 + name_text.length() * UiTheme.CHAR_W + 16, mid - list_belt.size.y / 2.0).round()
		add_child(list_belt)
		add_child(UiTheme.place(UiTheme.label("\"BRAGA EXPRESS\"", UiTheme.CAPTION, Palette.UI_GOLD), LIST_X + 56, mid + 14, 240, UiTheme.CAPTION))

	if OS.get_cmdline_user_args().size() > 0:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture="):
				_capture(arg.trim_prefix("--capture="))


## Design [param i] (0 = the current BeltIcon) at [param pixel] screen pixels.
func _belt(i: int, pixel: int) -> Control:
	if i == 0:
		return BeltIcon.new(pixel)
	return GridBelt.new(DESIGNS[i - 1][1], pixel)


func _capture(path: String) -> void:
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("Captured ", path)
	get_tree().quit()
