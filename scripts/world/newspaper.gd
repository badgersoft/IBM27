class_name Newspaper
extends RefCounted
## Writes the monthly newspaper, THE RINGSIDE GAZETTE, from the month's
## results.
##
##   * The main headline is a title fight: a new champion first, then a
##     successful defence, heaviest division first. Any other title fights
##     get stories of their own under it. With no title fight, the month's
##     most exciting fight (or biggest upset) leads instead.
##   * A professional fight rated 9 or more out of 10 for excitement, with a
##     man ranked in the top ten (or the champion) in it, gets a feature
##     shouting about how good it was.
##   * The player's own fight gets a story of its own, marked "player": it
##     leads the paper unless there is a title fight or a feature, and
##     otherwise comes straight after the main story. If his fight was for
##     a title, the title story is his.
##   * Side notes: anyone in the player's division (Season.player_division)
##     who moved up the rankings, then retirements and new faces.
##
##   * A round-up of the other results: the player's own fight first, then
##     the biggest fights.
##
## A rematch says so, with the head to head after it: "IT WAS THEIR SECOND
## MEETING: COTE LEADS THEIR SERIES 2-0." In the round-up each fight is one
## line of at most ROUNDUP_CHARS: "COTE BEAT SMITH (KO R3), LEADS 2-0." (the
## series only if it fits). A decision is just "(POINTS)"; the results page
## has the full verdict.
##
## Returns {"month", "date", "headline", "standfirst", "headline_player"
## (true if the main story is the player's fight), "stories": [{"title",
## "text", "player"}], "roundup": [String], "notes": [String], "results":
## [Fixture]}. Everything is upper case, like the rest of the game's text.

const NAME := "THE RINGSIDE GAZETTE"
## A feature needs this excitement rating, in a professional fight with a
## man ranked this high or better (0 = champion).
const FEATURE_EXCITEMENT := 9.0
const FEATURE_RANK := 10
## Most stories under the main one, and lines in the round-up.
const MAX_STORIES := 3
const ROUNDUP_LINES := 8
## The most characters on a round-up line, so it never wraps: the front
## page's main column is 792 px, and the 16 px font is 16 px a character.
const ROUNDUP_CHARS := 49

const NEW_CHAMPION_HEADLINES: Array[String] = [
	"{W} IS THE NEW {DIV} CHAMPION!",
	"{W} DETHRONES {L}!",
	"NEW KING OF THE {DIV}S: {W}!",
	"{L} FALLS - {W} TAKES THE BELT!",
]
const VACANT_HEADLINES: Array[String] = [
	"{W} CLAIMS THE VACANT {DIV} TITLE!",
	"{W} FILLS THE {DIV} THRONE!",
]
const DEFENCE_HEADLINES: Array[String] = [
	"{W} KEEPS HIS {DIV} CROWN",
	"{W} STILL THE {DIV} KING",
	"{W} TURNS BACK {L}",
	"NO WAY PAST {W}",
]
const TITLE_DRAW_HEADLINES: Array[String] = [
	"{W} CLINGS ON TO {DIV} TITLE AFTER DRAW",
	"DRAW! {W} KEEPS HIS BELT - JUST",
]
const FEATURE_HEADLINES: Array[String] = [
	"WHAT A FIGHT!",
	"A CLASSIC AT THE {VENUE}!",
	"FIGHT OF THE YEAR ALREADY?",
	"THEY'LL TALK ABOUT THIS ONE FOR YEARS",
]
const FEATURE_OPENERS: Array[String] = [
	"WHAT A NIGHT AT THE {VENUE}!",
	"IF YOU WERE AT THE {VENUE}, YOU WILL NEVER FORGET IT.",
	"BOXING DOES NOT GET MUCH BETTER THAN THIS.",
	"HOLD THE FRONT PAGE: WE HAVE A CLASSIC.",
]
const UPSET_HEADLINES: Array[String] = [
	"SHOCK! {W} STUNS {L}",
	"UPSET OF THE MONTH: {W} BEATS {L}",
]
const LEAD_HEADLINES: Array[String] = [
	"{W} WINS THE FIGHT OF THE MONTH",
	"{W} SHINES AT THE {VENUE}",
]
const QUIET_HEADLINE := "A QUIET MONTH IN THE RING"
## The player's fight, from his side: {P} is him, {O} his opponent, {N} the
## round in words.
const PLAYER_STOPPAGE_HEADLINES: Array[String] = ["{P} STOPS {O} IN {N}", "{O} NO MATCH FOR {P}", "{P} TOO STRONG FOR {O}"]
const PLAYER_KO_HEADLINES: Array[String] = ["{P} KNOCKS OUT {O} IN {N}", "{P} FLATTENS {O} IN {N}"]
const PLAYER_POINTS_HEADLINES: Array[String] = ["{P} OUTPOINTS {O}", "{P} TOO GOOD FOR {O}", "POINTS WIN FOR {P}"]
const PLAYER_STOPPED_HEADLINES: Array[String] = ["{O} STOPS {P} IN {N}", "NIGHT TO FORGET FOR {P}"]
const PLAYER_OUTPOINTED_HEADLINES: Array[String] = ["{O} OUTPOINTS {P}", "DEFEAT FOR {P} AGAINST {O}"]
const PLAYER_FIRST_DEFEAT := "{O} HANDS {P} HIS FIRST DEFEAT"
const PLAYER_DRAW_HEADLINES: Array[String] = ["{P} AND {O} FIGHT TO A DRAW", "HONOURS EVEN FOR {P}"]
const ROUND_WORDS: Array[String] = ["", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT",
		"NINE", "TEN", "ELEVEN", "TWELVE"]
const ORDINALS: Array[String] = ["", "FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH", "SIXTH"]
const ORDINAL_ROUNDS: Array[String] = ["", "FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH", "SIXTH",
		"SEVENTH", "EIGHTH", "NINTH", "TENTH", "ELEVENTH", "TWELFTH"]


static func write(season: Season, month: int, rng: RandomNumberGenerator) -> Dictionary:
	var results := season.fixtures_in(month)
	var paper := {
		"month": month,
		"date": Season.date_text(month),
		"headline": QUIET_HEADLINE,
		"headline_player": false,
		"standfirst": "NO FIGHTS OF NOTE THIS MONTH. THE MANAGERS ARE BUSY ON THE PHONES.",
		"stories": [],
		"roundup": [],
		"notes": [],
		"results": results,
	}

	# Title fights: new champions first, then defences, heaviest first.
	var titles: Array[Fixture] = []
	for f in results:
		if f.title and f.is_done():
			titles.append(f)
	titles.sort_custom(func(a: Fixture, b: Fixture) -> bool:
		var a_new: bool = a.summary.get("new_champion", false)
		var b_new: bool = b.summary.get("new_champion", false)
		if a_new != b_new:
			return a_new
		return a.division > b.division)

	var stories: Array = []
	var covered: Array[Fixture] = []
	for f in titles:
		stories.append(_with_series(_title_story(f, rng), f, season))
		covered.append(f)

	# Features: great professional fights with a top man in them.
	for f in results:
		if f.is_done() and not titles.has(f) and _is_feature(f):
			stories.append(_with_series(_feature_story(f, rng), f, season))
			covered.append(f)
	# A title fight that was also a classic gets the feature's praise too.
	for i in titles.size():
		if _is_feature(titles[i]):
			stories[i]["text"] += " " + _excitement_line(titles[i], rng)

	# His own fight: his story (or the title story, if it was for a title).
	var mine := _players_fight(results, season)
	if mine != null:
		var at := covered.find(mine)
		if at >= 0:
			stories[at]["player"] = true
			stories[at]["text"] += " " + _record_line(mine, season.player)
			if at > 1:
				# Straight after the main story, so it is always shown.
				stories.insert(1, stories.pop_at(at))
				covered.insert(1, covered.pop_at(at))
		else:
			var story := _with_series(_player_story(mine, season.player, rng), mine, season)
			var where := mini(1, stories.size())
			stories.insert(where, story)
			covered.insert(where, mine)

	if stories.is_empty():
		var lead := _lead_fight(results)
		if lead != null:
			stories.append(_with_series(_lead_story(lead, rng), lead, season))
			covered.append(lead)
	if not stories.is_empty():
		paper["headline"] = stories[0]["title"]
		paper["standfirst"] = stories[0]["text"]
		paper["headline_player"] = stories[0].get("player", false)
		paper["stories"] = stories.slice(1, 1 + MAX_STORIES)

	covered.resize(mini(covered.size(), 1 + MAX_STORIES))
	paper["roundup"] = _roundup(results, covered, season)
	paper["notes"] = _movers(results, season.player_division, season.player if mine != null else null) + season.notes
	return paper


## One line for each fight not in a story: the longest (best) fights first.
static func _roundup(results: Array[Fixture], covered: Array[Fixture], season: Season) -> Array[String]:
	var rest: Array[Fixture] = []
	for f in results:
		if f.is_done() and not covered.has(f):
			rest.append(f)
	var player := season.player
	rest.sort_custom(func(a: Fixture, b: Fixture) -> bool:
		var a_mine := player != null and a.involves(player)
		var b_mine := player != null and b.involves(player)
		if a_mine != b_mine:
			return a_mine
		if a.rounds != b.rounds:
			return a.rounds > b.rounds
		return a.purse > b.purse)
	var out: Array[String] = []
	for f: Fixture in rest.slice(0, ROUNDUP_LINES):
		out.append(_roundup_line(f, season))
	return out


## One round-up line: "COTE BEAT SMITH (KO R3).", "COTE BEAT SMITH
## (POINTS), LEADS 2-0." or "COTE AND SMITH DREW, LEVEL 1-1-1.". The series
## goes on the end of a rematch only if the line still fits ROUNDUP_CHARS.
static func _roundup_line(f: Fixture, season: Season) -> String:
	var w := f.winner()
	var line := ""
	var h := season.head_to_head(f.red, f.blue)
	var series := ""
	if w == null:
		line = "%s AND %s DREW" % [f.red.last_name.to_upper(), f.blue.last_name.to_upper()]
		if h[0] == h[1]:
			series = ", LEVEL %s" % Season.series_score(h)
	else:
		line = "%s BEAT %s (%s)" % [w.last_name.to_upper(), f.opponent_of(w).last_name.to_upper(), _result_short(f)]
		# The series from the winner's side.
		var mine := h[0] if w == f.red else h[1]
		var theirs := h[1] if w == f.red else h[0]
		var score := Season.series_score(h, w == f.red)
		if mine > theirs:
			series = ", LEADS %s" % score
		elif mine == theirs:
			series = ", LEVEL %s" % score
		else:
			series = ", TRAILS %s" % score
	if h[0] + h[1] + h[2] > 1 and line.length() + series.length() + 1 <= ROUNDUP_CHARS:
		line += series
	return line + "."


## "KO R3", "TKO R10", or "POINTS" for any decision.
static func _result_short(f: Fixture) -> String:
	var method: String = f.result["method"]
	if method in ["KO", "TKO"]:
		return "%s R%d" % [method, f.result["round"]]
	return "POINTS"


## Adds the head to head to [param story] if [param f] was a rematch.
static func _with_series(story: Dictionary, f: Fixture, season: Season) -> Dictionary:
	var h := season.head_to_head(f.red, f.blue)
	var meetings := h[0] + h[1] + h[2]
	if meetings > 1:
		var nth: String = ORDINALS[meetings] if meetings < ORDINALS.size() else "%dTH" % meetings
		story["text"] += " IT WAS THEIR %s MEETING: %s." % [nth, Season.series_text(f.red, f.blue, h)]
	return story


# ----------------------------------------------------------------------------
#  Stories
# ----------------------------------------------------------------------------

static func _title_story(f: Fixture, rng: RandomNumberGenerator) -> Dictionary:
	var winner := f.winner()
	var templates := DEFENCE_HEADLINES
	var champ := winner
	if winner == null:
		templates = TITLE_DRAW_HEADLINES
		champ = f.red if f.summary.get("red_rank", -1) == 0 else f.blue
	elif f.vacant:
		templates = VACANT_HEADLINES
	elif f.summary.get("new_champion", false):
		templates = NEW_CHAMPION_HEADLINES
	var other := f.opponent_of(champ)
	var title := _fill(_pick(templates, rng), f, champ, other)
	var text := ""
	if winner == null:
		text = "%s AND %s COULD NOT BE SEPARATED AT THE %s, AND A %s MEANS %s KEEPS THE IBC %s TITLE." % [
				_full(f.red), _full(f.blue), _venue(f), _draw_kind(f), _full(champ), _division(f)]
	else:
		var won := "KEEP THE IBC %s TITLE" % _division(f)
		if f.vacant:
			won = "WIN THE VACANT IBC %s TITLE" % _division(f)
		elif f.summary.get("new_champion", false):
			won = "BECOME THE NEW IBC %s CHAMPION" % _division(f)
		text = "%s %s %s AT THE %s TO %s." % [_full(winner), _how(f), _full(other), _venue(f), won]
	text += " " + _purse_line(f)
	return {"title": title, "text": text}


static func _feature_story(f: Fixture, rng: RandomNumberGenerator) -> Dictionary:
	var winner := f.winner()
	var title := _fill(_pick(FEATURE_HEADLINES, rng), f, winner, f.opponent_of(winner) if winner else f.blue)
	var text := _fill(_pick(FEATURE_OPENERS, rng), f, winner, null)
	text += " " + _action_line(f)
	if winner != null:
		text += " IN THE END %s %s %s." % [_full(winner), _how(f), _full(f.opponent_of(winner))]
	else:
		text += " IN THE END NOTHING COULD SEPARATE THEM: A %s." % _draw_kind(f)
	text += " " + _excitement_line(f, rng)
	return {"title": title, "text": text}


## The player's finished fight this month, or null.
static func _players_fight(results: Array[Fixture], season: Season) -> Fixture:
	if season.player == null:
		return null
	for f in results:
		if f.is_done() and f.involves(season.player):
			return f
	return null


## The player's fight, told from his side: what happened, his share of the
## purse, what it did to his ranking, and his record now.
static func _player_story(f: Fixture, me: BoxerData, rng: RandomNumberGenerator) -> Dictionary:
	var other := f.opponent_of(me)
	var winner := f.winner()
	var method: String = f.result["method"]
	var stoppage := method in ["KO", "TKO"]
	var round_number: int = f.result["round"]
	var templates := PLAYER_DRAW_HEADLINES
	var text := ""
	var when := "IN THE %s ROUND" % ORDINAL_ROUNDS[round_number] if stoppage else "OVER %d ROUNDS" % f.rounds
	if winner == me:
		templates = PLAYER_POINTS_HEADLINES
		if stoppage:
			templates = PLAYER_STOPPAGE_HEADLINES.duplicate()
			if method == "KO":
				templates.append_array(PLAYER_KO_HEADLINES)
		text = "%s %s %s %s AT THE %s." % [_full(me), _how(f), _full(other), when, _venue(f)]
	elif winner == other:
		templates = PLAYER_STOPPED_HEADLINES if stoppage else PLAYER_OUTPOINTED_HEADLINES
		if me.losses == 1:
			templates = [PLAYER_FIRST_DEFEAT]
		text = "%s WAS %s BY %s %s AT THE %s." % [_full(me), _how_beaten(f), _full(other), when, _venue(f)]
	else:
		text = "%s AND %s FOUGHT TO A %s %s AT THE %s." % [_full(me), _full(other), _draw_kind(f), when, _venue(f)]
	var title := _pick(templates, rng).replace("{P}", me.last_name.to_upper()).replace(
			"{O}", other.last_name.to_upper()).replace("{N}", ROUND_WORDS[mini(round_number, ROUND_WORDS.size() - 1)])
	text += " " + _action_line(f)
	var won: bool = winner == me
	var share: int = f.summary.get("winner_purse", 0) if won or winner == null else f.summary.get("loser_purse", 0)
	text += " HE TAKES HOME %s %s." % [Purse.money_text(share), _ranking_move(f, me)]
	text += " " + _record_line(f, me)
	return {"title": title, "text": text, "player": true}


## "AND CLIMBS FROM NO. 25 TO NO. 21 IN THE LIGHTWEIGHT RANKINGS".
static func _ranking_move(f: Fixture, me: BoxerData) -> String:
	var red := f.red == me
	var before: int = f.summary.get("red_rank" if red else "blue_rank", -1)
	var after: int = f.summary.get("red_rank_after" if red else "blue_rank_after", -1)
	var table := " IN THE %s RANKINGS" % _division(f)
	if before < 0 or after < 0:
		return ""
	if after == 0:
		return "AS THE NEW IBC %s CHAMPION" % _division(f)
	if after < before:
		return "AND CLIMBS FROM %s TO NO. %d%s" % [_place(before), after, table]
	if after > before:
		return "AND DROPS FROM %s TO NO. %d%s" % [_place(before), after, table]
	return "AND STAYS AT %s%s" % [_place(after), table]


static func _place(rank: int) -> String:
	return "CHAMPION" if rank == 0 else "NO. %d" % rank


## "HIS RECORD IS NOW 5-1-0 (3 KO)."
static func _record_line(_f: Fixture, me: BoxerData) -> String:
	return "HIS RECORD IS NOW %s." % me.record_with_kos()


## "STOPPED", "OUTPOINTED"... from the loser's side.
static func _how_beaten(f: Fixture) -> String:
	match f.result["method"]:
		"KO":
			return "KNOCKED OUT"
		"TKO":
			return "STOPPED"
		"MD":
			return "EDGED OUT ON A MAJORITY DECISION"
		"SD":
			return "BEATEN ON A SPLIT DECISION"
	return "OUTPOINTED"


## With no title fight or feature: the month's best fight, or its biggest upset.
static func _lead_story(f: Fixture, rng: RandomNumberGenerator) -> Dictionary:
	var winner := f.winner()
	if winner == null:
		return {"title": "HONOURS EVEN AT THE %s" % _venue(f),
				"text": "%s AND %s FOUGHT TO A %s. %s" % [_full(f.red), _full(f.blue), _draw_kind(f), _purse_line(f)]}
	var loser := f.opponent_of(winner)
	var templates := LEAD_HEADLINES
	if _upset_size(f) >= 4:
		templates = UPSET_HEADLINES
	var title := _fill(_pick(templates, rng), f, winner, loser)
	var text := "%s %s %s AT THE %s. %s %s" % [_full(winner), _how(f), _full(loser), _venue(f), _action_line(f), _purse_line(f)]
	return {"title": title, "text": text}


## The fight to lead on when there is no title fight: the biggest upset if
## there was a real one, otherwise the most exciting fight.
static func _lead_fight(results: Array[Fixture]) -> Fixture:
	var best: Fixture = null
	var upset: Fixture = null
	for f in results:
		if not f.is_done():
			continue
		if best == null or f.excitement > best.excitement:
			best = f
		if _upset_size(f) >= 4 and (upset == null or _upset_size(f) > _upset_size(upset)):
			upset = f
	return upset if upset != null else best


## How many places the winner was below the loser (0 if he was above).
static func _upset_size(f: Fixture) -> int:
	var w := f.winner()
	if w == null or f.across_divisions():
		return 0
	var w_rank: int = f.summary["red_rank"] if w == f.red else f.summary["blue_rank"]
	var l_rank: int = f.summary["blue_rank"] if w == f.red else f.summary["red_rank"]
	return maxi(w_rank - l_rank, 0)


static func _is_feature(f: Fixture) -> bool:
	if f.excitement < FEATURE_EXCITEMENT or f.rounds != Rankings.TITLE_ROUNDS:
		return false
	var best_rank := mini(f.summary.get("red_rank", 99), f.summary.get("blue_rank", 99))
	return best_rank >= 0 and best_rank <= FEATURE_RANK


# ----------------------------------------------------------------------------
#  Notes
# ----------------------------------------------------------------------------

## Everyone in the player's division who moved up the rankings this month
## (but [param skip], whose own story says so).
static func _movers(results: Array[Fixture], division: int, skip: BoxerData = null) -> Array[String]:
	var out: Array[String] = []
	for f in results:
		if not f.is_done() or f.across_divisions() or f.red.division != division:
			continue
		for corner in 2:
			var b := f.red if corner == 0 else f.blue
			if b == skip:
				continue
			var before: int = f.summary["red_rank" if corner == 0 else "blue_rank"]
			var after: int = f.summary["red_rank_after" if corner == 0 else "blue_rank_after"]
			if after >= 0 and after < before:
				var place := "THE IBC CHAMPION" if after == 0 else "NO. %d" % after
				out.append("%s CLIMBS FROM NO. %d TO %s IN THE %s RANKINGS." % [
						b.display_name().to_upper(), before, place, Divisions.division_name(division).to_upper()])
	return out


# ----------------------------------------------------------------------------
#  Phrases
# ----------------------------------------------------------------------------

## "KNOCKED OUT", "STOPPED", "OUTPOINTED"...
static func _how(f: Fixture) -> String:
	match f.result["method"]:
		"KO":
			return "KNOCKED OUT"
		"TKO":
			return "STOPPED"
		"UD":
			return "OUTPOINTED"
		"MD":
			return "EDGED PAST"
		"SD":
			return "SQUEEZED PAST"
	return "DREW WITH"


static func _draw_kind(f: Fixture) -> String:
	return ("%s DRAW" % str(f.result.get("detail", ""))).strip_edges()


static func _action_line(f: Fixture) -> String:
	var downs := int(f.summary.get("knockdowns", 0))
	var big := int(f.summary.get("big_punches", 0))
	var parts: Array[String] = []
	if downs > 0:
		parts.append("%d KNOCKDOWN%s" % [downs, "S" if downs > 1 else ""])
	if big > 0:
		parts.append("%d BIG PUNCH%s" % [big, "ES" if big > 1 else ""])
	var length := "%d ROUNDS" % f.result["round"]
	if parts.is_empty():
		return "IT WENT %s." % length if f.result["round"] == f.rounds else "IT LASTED %s." % length
	return "%s IN %s." % [" AND ".join(parts), length]


static func _excitement_line(f: Fixture, rng: RandomNumberGenerator) -> String:
	var lines: Array[String] = [
		"OUR RINGSIDE RATING: %.1f OUT OF 10.",
		"WE GIVE IT %.1f OUT OF 10 - AND WE DON'T SAY THAT LIGHTLY.",
		"%.1f OUT OF 10. GET THE REMATCH SIGNED!",
	]
	return _pick(lines, rng) % f.excitement


static func _purse_line(f: Fixture) -> String:
	var w := f.winner()
	if w == null:
		return "THE %s PURSE WAS SHARED EQUALLY." % Purse.money_text(f.purse)
	var shares := Purse.split(f.purse, false)
	return "THE PURSE WAS %s, %s OF IT TO THE WINNER." % [Purse.money_text(f.purse), Purse.money_text(shares[0])]


static func _fill(template: String, f: Fixture, winner: BoxerData, loser: BoxerData) -> String:
	var out := template.replace("{DIV}", _division(f)).replace("{VENUE}", _venue(f))
	if winner != null:
		out = out.replace("{W}", winner.last_name.to_upper())
	if loser != null:
		out = out.replace("{L}", loser.last_name.to_upper())
	return out


static func _full(b: BoxerData) -> String:
	return b.display_name().to_upper()


static func _division(f: Fixture) -> String:
	return Divisions.division_name(f.division).to_upper()


static func _venue(f: Fixture) -> String:
	return Venues.venue_name(f.venue).to_upper()


static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	return list[rng.randi_range(0, list.size() - 1)]
