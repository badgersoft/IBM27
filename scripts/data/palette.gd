class_name Palette
extends RefCounted
## Every colour used by the game lives here, so the look can be tweaked in one
## place. Colours are grouped by what they are used for.
##
## Boxer colours come in sets of three (base, shadow, highlight) because the
## pixel-art renderer shades every body part with three tones, Amiga style.


# --------------------------------------------------------------------------
#  Boxer appearance
# --------------------------------------------------------------------------

## Skin tones, lightest to darkest. Index is stored on BoxerData.skin_index.
const SKIN_NAMES: Array[String] = [
	"Very Light Brown",
	"Light Brown",
	"Brown",
	"Dark Brown",
	"Very Dark Brown",
]

## [base, shadow, highlight] for each skin tone above.
const SKIN_TONES: Array = [
	[Color("e9bf98"), Color("c4926c"), Color("f7d9bb")],
	[Color("d29a6a"), Color("a6714a"), Color("e7b98e")],
	[Color("a86d42"), Color("7d4e2b"), Color("c4895b")],
	[Color("7a4a2a"), Color("56321b"), Color("97623f")],
	[Color("4f301c"), Color("351f12"), Color("6c452c")],
]

## Hair colours. Index 0 means the boxer is bald / shaved.
const HAIR_NAMES: Array[String] = [
	"None",
	"Light Brown",
	"Brown",
	"Dark Brown",
	"Black",
	"Red",
]

## [base, shadow] for each hair colour (index 0 is unused).
const HAIR_TONES: Array = [
	[Color(0, 0, 0, 0), Color(0, 0, 0, 0)],
	[Color("a97b4c"), Color("7c5734")],
	[Color("6e4526"), Color("4d2f19")],
	[Color("3f2716"), Color("2a190d")],
	[Color("1d1714"), Color("0f0b09")],
	[Color("b8481e"), Color("853213")],
]

## Hair styles used by the head renderer. Purely cosmetic.
const HAIR_STYLES: Array[String] = ["Crop", "Flat Top", "Curly", "Slick"]

## Trunk colours: name, [base, shadow, highlight], trim (waistband / stripe).
const TRUNKS: Array = [
	{"name": "Red",    "tones": [Color("c8282c"), Color("8e1a1e"), Color("e85a52")], "trim": Color("f2ead2")},
	{"name": "Royal",  "tones": [Color("2a4fc8"), Color("1b338a"), Color("5a7cf0")], "trim": Color("f2ead2")},
	{"name": "White",  "tones": [Color("e8e4dc"), Color("b0aca6"), Color("ffffff")], "trim": Color("c8282c")},
	{"name": "Black",  "tones": [Color("26262c"), Color("121216"), Color("4a4a54")], "trim": Color("e0b43c")},
	{"name": "Gold",   "tones": [Color("dcae38"), Color("a07a1c"), Color("f4d470")], "trim": Color("26262c")},
	{"name": "Green",  "tones": [Color("2a9a4a"), Color("1a6630"), Color("5cc874")], "trim": Color("f2ead2")},
	{"name": "Purple", "tones": [Color("7a3aa8"), Color("4f2270"), Color("a46cd0")], "trim": Color("e0b43c")},
	{"name": "Sky",    "tones": [Color("5ab4e6"), Color("3482b0"), Color("92d4f6")], "trim": Color("26262c")},
	{"name": "Maroon", "tones": [Color("7a1e2c"), Color("50121c"), Color("a43a4a")], "trim": Color("e0b43c")},
	{"name": "Silver", "tones": [Color("a8acb4"), Color("74787e"), Color("d4d8de")], "trim": Color("2a4fc8")},
]

## Boot colours: [base, shadow].
const BOOTS: Array = [
	[Color("f0ede6"), Color("b4b0a8")],
	[Color("222226"), Color("101012")],
	[Color("b02428"), Color("7a161a")],
]

## Gloves are coloured by corner so the two fighters are always easy to tell
## apart: index 0 = red corner, 1 = blue corner. [base, shadow, highlight].
const GLOVES: Array = [
	[Color("d42a2a"), Color("8c1616"), Color("ff7a6a")],
	[Color("2a5ad4"), Color("16348c"), Color("7aa2ff")],
]

## Dark outline drawn around every body part.
const OUTLINE := Color("140c0a")
const EYE := Color("120a08")
const SOCK := Color("f4f2ec")
const LACE := Color("f4f2ec")
const SHADOW := Color(0, 0, 0, 0.35)


# --------------------------------------------------------------------------
#  User interface
# --------------------------------------------------------------------------

const UI_BACKGROUND := Color("0d1020")
const UI_PANEL      := Color("161b33")
const UI_PANEL_DARK := Color("0f1328")
const UI_BORDER     := Color("c8a850")
const UI_TEXT       := Color("f0e9d6")
const UI_TEXT_DIM   := Color("8a90aa")
const UI_GOLD       := Color("f0c850")
const UI_RED        := Color("e04848")
const UI_BLUE       := Color("4a82f0")
const UI_GOOD       := Color("58c85a")
const UI_WARN       := Color("e8b030")
const UI_BAD        := Color("e04848")
## The career's training buttons: a light steel-blue tint, so they read
## differently from the menu buttons.
const UI_TRAIN        := Color("223552")
const UI_TRAIN_BORDER := Color("7aa8d0")

## UI accent colour for a corner (0 = red, 1 = blue).
static func corner_color(corner: int) -> Color:
	return UI_RED if corner == 0 else UI_BLUE


## Returns a colour multiplied towards black - used for "far" limbs and for
## spectators sitting further back in the crowd.
static func darken(c: Color, amount: float) -> Color:
	return Color(c.r * (1.0 - amount), c.g * (1.0 - amount), c.b * (1.0 - amount), c.a)
