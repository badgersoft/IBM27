class_name BoxerData
extends Resource
## Everything we know about a boxer *before* a fight starts.
##
## Nothing in here changes during a fight - the live, changing values (health,
## energy, position...) live on Fighter instead. Keeping the two apart means a
## boxer can be saved, loaded or reused for another fight without clean-up.

enum Style { BRAWLER, SLUGGER, BOXER, COUNTER, EVASIVE, SHOWBOAT }
## A few boxers are out of the ordinary (see BoxerGenerator._assign_specials):
##   MONSTER    - a knockout artist: huge power, a granite chin, and a
##                record full of knockouts; dominant in the ring.
##   GLASS_JAW  - looks like a monster on paper, but a hard, clean shot on
##                the chin can put him down (and out) far more easily.
enum Special { NONE, MONSTER, GLASS_JAW }

const STYLE_NAMES: Array[String] = ["Brawler", "Slugger", "Boxer", "Counter", "Evasive", "Showboat"]
## Three-letter short forms for tight tables (the Boxers list).
const STYLE_SHORT: Array[String] = ["BRL", "SLG", "BOX", "CNR", "EVA", "SHW"]

## Short one-line description of each style, shown on the boxer's profile.
## At most 50 characters so it fits the profile at full size.
const STYLE_BLURBS: Array[String] = [
	"Plants his feet and trades from mid range.",
	"Walks forward and fights toe to toe.",
	"Hits, moves back, and picks his moments.",
	"Waits, slips, and punishes mistakes.",
	"Stays on the move and saves himself late.",
	"Quick and flashy; drops his guard for the crowd.",
]

# --- Identity --------------------------------------------------------------
@export var first_name: String = ""
@export var last_name: String = ""
@export var nickname: String = ""        ## Empty when the boxer has no nickname.
@export var city: String = ""
@export var country: String = ""         ## Display name, e.g. "Ireland".
@export var country_code: String = ""    ## Three letters, e.g. "IRL".

# --- Career ----------------------------------------------------------------
## Placeholder records for now (made up by BoxerGenerator, then updated after
## every fight in this session).
@export_range(18, 40) var age: int = 26
@export var wins: int = 0
@export var losses: int = 0
@export var draws: int = 0
@export var kos: int = 0                 ## Wins by knockout (counted inside wins).

# --- Business ----------------------------------------------------------------
@export var id: int = 0                  ## Unique across every division.
@export var manager: ManagerData         ## Arranges his fights (see ManagerData.Type).
@export var earnings: int = 0            ## Career prize money, in dollars.
## Ranking points, used when the rankings run on points (see Rankings).
@export var rank_points: float = 0.0
## The career player's own boxer (managed by the player, not the computer).
@export var is_player: bool = false
## How fit he is between fights (percent). Only the player's boxer carries
## knocks from one fight to the next; he starts a fight with less health
## when he is not fully recovered (see Fighter).
@export_range(0.0, 100.0) var condition: float = 100.0

# --- Season ------------------------------------------------------------------
@export var birth_month: int = 0          ## 0 = January: he turns a year older then.
@export var last_fight_month: int = -99   ## Season month of his last fight (see Season).
## Training and age add or take away fractions of a skill point each month;
## whole points are applied as they build up (see Training).
@export var skill_progress: Dictionary = {}

# --- Body ------------------------------------------------------------------
## Weight division (see Divisions); height and weight ranges depend on it.
@export var division: Divisions.Id = Divisions.Id.MIDDLEWEIGHT
@export_range(150, 210) var height_cm: int = 180
@export_range(120, 300) var weight_lb: int = 157
@export var skin_index: int = 0          ## Index into Palette.SKIN_TONES.
@export var hair_index: int = 0          ## Index into Palette.HAIR_TONES (0 = none).
@export var hair_style: int = 0          ## Index into Palette.HAIR_STYLES.
@export var trunks_index: int = 0        ## Index into Palette.TRUNKS.
@export var boots_index: int = 0         ## Index into Palette.BOOTS.
## His own gloves (the player's choice), an index into Palette.TRUNKS for the
## colour; -1 = the usual gloves in his corner's colour.
@export var gloves_index: int = -1

# --- Skills (1 - 99) ---------------------------------------------------------
@export_range(1, 99) var power: int = 50         ## How hard he punches.
@export_range(1, 99) var speed: int = 50         ## How fast he punches and moves.
@export_range(1, 99) var stamina: int = 50       ## How slowly the other skills tire.
@export_range(1, 99) var chin: int = 50          ## How well he takes a big head shot.
@export_range(1, 99) var strength: int = 50      ## How little being hit drains him.
@export_range(1, 99) var intelligence: int = 50  ## How well he picks attack or defence.

@export var style: Style = Style.BOXER
@export var special: Special = Special.NONE

# --- Condition ---------------------------------------------------------------
## Health going into the fight (percent). Linked to fitness and pain tolerance.
@export_range(1.0, 100.0) var start_health: float = 92.0
## How much damage he shakes off in the corner between rounds (and, in
## future builds, how quickly health returns between fights).
@export_range(1, 99) var recovery: int = 50


## "Barry McGuigan"
func display_name() -> String:
	return "%s %s" % [first_name, last_name]


## 'Barry "The Badger" McGuigan' - or the plain name when there is no nickname.
func billing_name() -> String:
	if nickname.is_empty():
		return display_name()
	return "%s \"%s\" %s" % [first_name, nickname, last_name]


## "Belfast, GBR"
func hometown() -> String:
	return "%s, %s" % [city, country_code]


func division_name() -> String:
	return Divisions.division_name(division)


func style_name() -> String:
	return STYLE_NAMES[style]


func style_short() -> String:
	return STYLE_SHORT[style]


## "22-3-1"  (wins - losses - draws, the usual boxing order).
func record() -> String:
	return "%d-%d-%d" % [wins, losses, draws]


## "22-3-1 (14 KO)"
func record_with_kos() -> String:
	return "%s (%d KO)" % [record(), kos]


func total_fights() -> int:
	return wins + losses + draws


## Adds the result of a fight to the record. [param result] is "W", "L" or "D".
func add_result(result: String, by_ko: bool) -> void:
	match result:
		"W":
			wins += 1
			if by_ko:
				kos += 1
		"L":
			losses += 1
		_:
			draws += 1


## Average of the six skills - a quick "overall" rating for menus.
func overall() -> int:
	return roundi((power + speed + stamina + chin + strength + intelligence) / 6.0)


## Height in feet and inches, e.g. 5' 11".
func height_imperial() -> String:
	var total_inches := roundi(height_cm / 2.54)
	return "%d' %d\"" % [total_inches / 12, total_inches % 12]
