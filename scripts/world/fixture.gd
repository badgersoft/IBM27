class_name Fixture
extends RefCounted
## One arranged fight in the season: who, when, what for, and (once it has
## been fought) how it went.
##
## A fight is arranged two months ahead (the training camp) and takes place
## at the end of [member month]. The better-ranked man (or, across divisions,
## the man from the heavier division) is in the red corner.

var red: BoxerData
var blue: BoxerData
## The weight the fight is at (the heavier man's division across divisions).
var division: int = Divisions.Id.MIDDLEWEIGHT
var month := 0                 ## Season month it is fought at the end of.
var arranged := 0              ## Season month it was arranged in.
var title := false             ## The IBC title is on the line.
var vacant := false            ## ...and nobody holds it (both men are challengers).
var rounds := 6
var purse := 0
var venue := 0

# --- Once fought --------------------------------------------------------------
var result := {}               ## FightSim.result.
## Season.record_result's summary, plus "red_rank" / "blue_rank" (places
## before the fight, 0 = champion), "red_rank_after" / "blue_rank_after",
## "knockdowns" and "big_punches".
var summary := {}
var excitement := 0.0          ## Out of 10 (see Excitement).
var watched := false           ## Watched in the ring rather than simulated.
## The finished simulation, kept by the season runner until the result is
## recorded on the main thread.
var sim: FightSim


func is_done() -> bool:
	return not result.is_empty()


func involves(b: BoxerData) -> bool:
	return b == red or b == blue


func opponent_of(b: BoxerData) -> BoxerData:
	return blue if b == red else red


func across_divisions() -> bool:
	return red.division != blue.division


## The winner, or null for a draw or a fight not yet fought.
func winner() -> BoxerData:
	if not is_done() or result["winner"] < 0:
		return null
	return red if result["winner"] == 0 else blue


func loser() -> BoxerData:
	var w := winner()
	if w == null:
		return null
	return blue if w == red else red


## "KO 7", "TKO 3", "UD", "SD", "DRAW" (or "" before the fight).
func result_text() -> String:
	if not is_done():
		return ""
	var method: String = result["method"]
	if method in ["KO", "TKO"]:
		return "%s %d" % [method, result["round"]]
	if method == "DRAW":
		return "DRAW"
	return "POINTS"


## The full verdict, for the record: "UNANIMOUS DECISION", "SPLIT DECISION",
## "MAJORITY DECISION", "SPLIT DRAW" (or UNANIMOUS / MAJORITY DRAW),
## "KNOCKOUT" or "TECHNICAL KNOCKOUT" (three knockdowns in a round).
func verdict_text() -> String:
	if not is_done():
		return ""
	match result["method"]:
		"KO":
			return "KNOCKOUT"
		"TKO":
			return "TECHNICAL KNOCKOUT"
		"UD":
			return "UNANIMOUS DECISION"
		"SD":
			return "SPLIT DECISION"
		"MD":
			return "MAJORITY DECISION"
	return ("%s DRAW" % str(result.get("detail", ""))).strip_edges()


# ----------------------------------------------------------------------------
#  Saving
# ----------------------------------------------------------------------------

## Everything about the fight as plain data (boxers as their ids).
func to_dict() -> Dictionary:
	var saved_summary := summary.duplicate()
	for key in ["winner", "loser"]:
		if saved_summary.has(key):
			saved_summary[key] = (saved_summary[key] as BoxerData).id
	return {
		"red": red.id, "blue": blue.id, "division": division, "month": month, "arranged": arranged,
		"title": title, "vacant": vacant, "rounds": rounds, "purse": purse, "venue": venue,
		"result": result, "summary": saved_summary, "excitement": excitement, "watched": watched,
	}


## A fight from to_dict(); [param by_id] finds each boxer by id.
static func from_dict(d: Dictionary, by_id: Dictionary) -> Fixture:
	var f := Fixture.new()
	f.red = by_id[int(d["red"])]
	f.blue = by_id[int(d["blue"])]
	f.division = int(d["division"])
	f.month = int(d["month"])
	f.arranged = int(d["arranged"])
	f.title = d["title"]
	f.vacant = d["vacant"]
	f.rounds = int(d["rounds"])
	f.purse = int(d["purse"])
	f.venue = int(d["venue"])
	f.result = d["result"]
	f.summary = (d["summary"] as Dictionary).duplicate()
	for key in ["winner", "loser"]:
		if f.summary.has(key):
			f.summary[key] = by_id[int(f.summary[key])]
	f.excitement = float(d["excitement"])
	f.watched = d["watched"]
	return f
