class_name BoxerData
extends Resource
## Everything we know about a boxer *before* a fight starts.
##
## Nothing in here changes during a fight - the live, changing values (health,
## energy, position...) live on Fighter instead. Keeping the two apart means a
## boxer can be saved, loaded or reused for another fight without clean-up.

enum Style { BRAWLER, SLUGGER, BOXER, COUNTER, EVASIVE }

const STYLE_NAMES: Array[String] = ["Brawler", "Slugger", "Boxer", "Counter", "Evasive"]

## Short one-line description of each style, shown in the tale of the tape.
const STYLE_BLURBS: Array[String] = [
	"Plants his feet and trades from mid range.",
	"Walks forward and fights toe to toe.",
	"Hits, moves back, and picks his moments.",
	"Waits, slips, and punishes mistakes.",
	"Stays on the move and saves himself late.",
]

## Weight-class limits for this build (middleweight).
const MIN_WEIGHT_LB := 154
const MAX_WEIGHT_LB := 160
const MIN_HEIGHT_CM := 170
const MAX_HEIGHT_CM := 198

# --- Identity --------------------------------------------------------------
@export var first_name: String = ""
@export var last_name: String = ""
@export var nickname: String = ""        ## Empty when the boxer has no nickname.
@export var city: String = ""
@export var country: String = ""         ## Display name, e.g. "Ireland".
@export var country_code: String = ""    ## Three letters, e.g. "IRL".

# --- Body ------------------------------------------------------------------
@export_range(170, 198) var height_cm: int = 180
@export_range(154, 160) var weight_lb: int = 157
@export var skin_index: int = 0          ## Index into Palette.SKIN_TONES.
@export var hair_index: int = 0          ## Index into Palette.HAIR_TONES (0 = none).
@export var hair_style: int = 0          ## Index into Palette.HAIR_STYLES.
@export var trunks_index: int = 0        ## Index into Palette.TRUNKS.
@export var boots_index: int = 0         ## Index into Palette.BOOTS.

# --- Skills (1 - 99) ---------------------------------------------------------
@export_range(1, 99) var power: int = 50         ## How hard he punches.
@export_range(1, 99) var speed: int = 50         ## How fast he punches and moves.
@export_range(1, 99) var stamina: int = 50       ## How slowly the other skills tire.
@export_range(1, 99) var chin: int = 50          ## How well he takes a big head shot.
@export_range(1, 99) var strength: int = 50      ## How little being hit drains him.
@export_range(1, 99) var intelligence: int = 50  ## How well he picks attack or defence.

@export var style: Style = Style.BOXER

# --- Condition ---------------------------------------------------------------
## Health going into the fight (percent). Linked to fitness and pain tolerance.
@export_range(1.0, 100.0) var start_health: float = 92.0
## Reserved for future builds: how quickly health returns between fights.
@export_range(1, 99) var recovery: int = 50


## "Barry McGuigan"
func display_name() -> String:
	return "%s %s" % [first_name, last_name]


## "Barry 'The Badger' McGuigan" - or the plain name when there is no nickname.
func billing_name() -> String:
	if nickname.is_empty():
		return display_name()
	return "%s '%s' %s" % [first_name, nickname, last_name]


## "Belfast, GBR"
func hometown() -> String:
	return "%s, %s" % [city, country_code]


func style_name() -> String:
	return STYLE_NAMES[style]


## Average of the six skills - a quick "overall" rating for menus.
func overall() -> int:
	return roundi((power + speed + stamina + chin + strength + intelligence) / 6.0)


## Height in feet and inches, e.g. 5' 11".
func height_imperial() -> String:
	var total_inches := roundi(height_cm / 2.54)
	return "%d' %d\"" % [total_inches / 12, total_inches % 12]
