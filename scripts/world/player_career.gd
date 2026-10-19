class_name PlayerCareer
extends RefCounted
## The player's career: his boxer, his money and his week.
##
## Time runs a week at a time, four weeks to the month (the season's months
## and fight nights carry on as before; see Season). Each week he can do one
## training session (Facilities), pays for any facilities he rents, and gets
## some of his condition back. In the first week of a month new sponsor
## offers may arrive. In the last week the month's fights are fought,
## his own included.
##
## Fights are his to arrange (Schedule): anyone in his division no more than
## Matchmaker.ABOVE places above him or BELOW below, who is free, offered a
## purse at one of PURSE_OFFERS times the usual figure. He must have half the
## purse in the bank to make an offer. A man who has asked to fight him
## (requests, from the other managers) is keen and nearly always says yes;
## anyone else may need a bigger purse to be tempted. One fight at a time;
## calling one off costs FORFEIT of the purse.

const START_MONEY := 20000
const START_POOL := 40
const WEEKS_PER_MONTH := 4
## The purse offers, as a share of the usual purse for the fight, and how
## much each sways an unsure opponent.
const PURSE_OFFERS: Array[float] = [0.6, 0.8, 1.0, 1.25, 1.5]
const PURSE_SWAY: Array[float] = [-0.35, -0.18, 0.0, 0.2, 0.35]
## Chance of a yes at the usual purse: a man who asked for the fight, and
## anyone else (adjusted by his manager and the two men's standing).
const KEEN_ACCEPT := 0.92
const UNSURE_ACCEPT := 0.55
const FORFEIT := 0.25
const MIN_PURSE := 50
## Sponsors: offers come in the first week of the month, at most
## MAX_SPONSOR_OFFERS at a time, for 3, 6 or 12 months (paying 1, 1.8 or
## 3.2 times the three-month figure).
const SPONSOR_MONTHS: Array[int] = [3, 6, 12]
const SPONSOR_SCALE: Array[float] = [1.0, 1.8, 3.2]
const MAX_SPONSOR_OFFERS := 3
const SPONSORS_PATH := "res://data/sponsors.json"

var boxer: BoxerData
var money := START_MONEY
var week := 0                       ## 0 - 3 within the season's month.
var trained := -1                   ## This week's session (Facilities.Session), -1 if not yet.
var last_gains := {}                ## What this week's session added.
var training_facility := 0
var recovery_facility := 0
## The current sponsor, if any: {"name", "tier", "pay", "months_left"}.
var sponsor := {}
var sponsor_offers: Array[Dictionary] = []
## Ids of boxers who have asked to fight him this month.
var requests: Array[int] = []
## Ids of boxers who turned him down this week.
var declined: Array[int] = []
## Lines about what happened lately, newest first (shown on the home page).
var news: Array[String] = []

var _rng := RandomNumberGenerator.new()


func _init(player: BoxerData, seed_value: int = -1) -> void:
	boxer = player
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


# ----------------------------------------------------------------------------
#  The week
# ----------------------------------------------------------------------------

## The first month of a new career: any fight requests and sponsor offers.
func begin(season: Season) -> void:
	requests = season.player_requests.duplicate()
	season.player_requests.clear()
	_log("WELCOME TO THE IBC, %s." % boxer.display_name().to_upper())
	_new_sponsor_offers(season)


## True on the last week of the month, when the month's fights happen.
func fight_week() -> bool:
	return week == WEEKS_PER_MONTH - 1


## "WEEK 2 OF JANUARY 2027"
func date_text(season: Season) -> String:
	return "WEEK %d OF %s" % [week + 1, Season.date_text(season.month)]


## Trains for the week (once a week).
func train(session: int) -> void:
	if trained >= 0:
		return
	trained = session
	last_gains = Facilities.train(boxer, session, training_facility)


## Weekly costs: the facilities he rents. If he can't pay for one he moves
## back to the free one.
func weekly_costs() -> int:
	return int(Facilities.TRAINING[training_facility]["cost"]) + int(Facilities.RECOVERY[recovery_facility]["cost"])


## Ends a week that is not the month's last (the last ends with the
## season's month: see end_month). Pays the rent and recovers.
func end_week() -> void:
	_pay_rent()
	boxer.condition = minf(boxer.condition + Facilities.weekly_recovery(boxer, recovery_facility), 100.0)
	week += 1
	trained = -1
	last_gains = {}
	declined.clear()


## After the season's month end (Season.finish_month): rent, recovery,
## winnings, the sponsor's months, and next month's offers.
func end_month(season: Season) -> void:
	_pay_rent()
	boxer.condition = minf(boxer.condition + Facilities.weekly_recovery(boxer, recovery_facility), 100.0)
	if season.player_winnings > 0:
		money += season.player_winnings
		_log("PURSE BANKED: %s." % Purse.money_text(season.player_winnings))
		season.player_winnings = 0
	week = 0
	trained = -1
	last_gains = {}
	declined.clear()
	requests = season.player_requests.duplicate()
	season.player_requests.clear()
	if not sponsor.is_empty():
		sponsor["months_left"] -= 1
		if sponsor["months_left"] <= 0:
			_log("YOUR DEAL WITH %s HAS ENDED." % str(sponsor["name"]).to_upper())
			sponsor = {}
	_new_sponsor_offers(season)


func _pay_rent() -> void:
	var gym: Dictionary = Facilities.TRAINING[training_facility]
	var spa: Dictionary = Facilities.RECOVERY[recovery_facility]
	for pair in [[gym, Facilities.Kind.TRAINING], [spa, Facilities.Kind.RECOVERY]]:
		var cost: int = pair[0]["cost"]
		if cost > money:
			_log("COULD NOT PAY FOR THE %s - BACK TO THE FREE ONE." % str(pair[0]["name"]).to_upper())
			set_facility(pair[1], 0)
		else:
			money -= cost


func set_facility(kind: Facilities.Kind, index: int) -> void:
	if kind == Facilities.Kind.TRAINING:
		training_facility = index
	else:
		recovery_facility = index


func _log(line: String) -> void:
	news.push_front(line)
	news.resize(mini(news.size(), 8))


# ----------------------------------------------------------------------------
#  Sponsors
# ----------------------------------------------------------------------------

## 0 - 1: how attractive he is to sponsors - his place in the division
## most of all, then his record and ability. A champion is worth the most.
func market_value(rankings: Rankings) -> float:
	if rankings.is_champion(boxer):
		return 1.0
	var place := 1.0 - rankings.index_of(boxer) / float(maxi(rankings.size() - 1, 1))
	var record := float(boxer.wins) / (boxer.total_fights() + 3.0)
	var ability := clampf((boxer.overall() - 30.0) / 60.0, 0.0, 1.0)
	return clampf(0.6 * place + 0.25 * record + 0.15 * ability, 0.0, 1.0)


func _new_sponsor_offers(season: Season) -> void:
	sponsor_offers.clear()
	if not sponsor.is_empty():
		return   # One sponsor at a time.
	var data := _sponsor_data()
	var value := market_value(season.rankings_of(boxer))
	# Few offers for an unknown; more, and from bigger names, as he rises.
	var count := 0
	for i in MAX_SPONSOR_OFFERS:
		if _rng.randf() < 0.25 + value * 0.6:
			count += 1
	var top_tier := clampi(floori(value * 4.0), 0, 3)
	var names: Array = data["sponsors"]
	for i in count:
		var tier := clampi(top_tier - (1 if _rng.randf() < 0.35 else 0), 0, 3)
		var taken := sponsor_offers.map(func(o: Dictionary) -> String: return o["name"])
		var choices := names.filter(func(s: Dictionary) -> bool: return int(s["tier"]) == tier and not s["name"] in taken)
		var pick: Dictionary = choices[_rng.randi_range(0, choices.size() - 1)]
		var pay_range: Array = data["tiers"][tier]["pay"]
		# Where he sits in the tier, give or take a little for each firm.
		var place := clampf(value * 4.0 - tier + _rng.randf_range(-0.1, 0.3), 0.0, 1.0)
		var base := lerpf(pay_range[0], pay_range[1], place)
		var length := _rng.randi_range(0, SPONSOR_MONTHS.size() - 1)
		sponsor_offers.append({
			"name": pick["name"], "tier": tier, "months": SPONSOR_MONTHS[length],
			"pay": roundi(base * SPONSOR_SCALE[length] / 100.0) * 100,
		})
	if count > 0:
		_log("%d SPONSOR OFFER%s IN - SEE FACILITIES." % [count, "S" if count > 1 else ""])


## Takes sponsor offer [param i]: the money is paid at once.
func accept_sponsor(i: int) -> void:
	var offer: Dictionary = sponsor_offers[i]
	sponsor = {"name": offer["name"], "tier": offer["tier"], "pay": offer["pay"], "months_left": offer["months"]}
	money += int(offer["pay"])
	sponsor_offers.clear()
	_log("SIGNED WITH %s: %s FOR %d MONTHS." % [str(offer["name"]).to_upper(), Purse.money_text(offer["pay"]), offer["months"]])


static func _sponsor_data() -> Dictionary:
	var file := FileAccess.open(SPONSORS_PATH, FileAccess.READ)
	if file == null:
		push_error("PlayerCareer: could not open %s" % SPONSORS_PATH)
		return {"tiers": [], "sponsors": []}
	return JSON.parse_string(file.get_as_text())


# ----------------------------------------------------------------------------
#  Arranging fights
# ----------------------------------------------------------------------------

## The month from which a new fight can be arranged (a month after his last).
func free_from(season: Season) -> int:
	return boxer.last_fight_month + Matchmaker.RECOVERY_MONTHS


## True if he can arrange a fight now: none arranged and recovered.
func can_arrange(season: Season) -> bool:
	return season.booking(boxer) == null and season.month >= free_from(season)


## Everyone he may fight, men who have asked to fight him first (wherever
## they are ranked), then in ranking order: his own division, no more than
## Matchmaker.ABOVE places above or BELOW below. All of them free (no fight
## arranged, recovered).
func opponents(season: Season) -> Array[BoxerData]:
	var table := season.rankings_of(boxer)
	var i := table.index_of(boxer)
	var out: Array[BoxerData] = []
	var free := func(other: BoxerData) -> bool:
		return season.booking(other) == null and season.month - other.last_fight_month >= Matchmaker.RECOVERY_MONTHS
	for j in range(maxi(i - Matchmaker.ABOVE, 0), mini(i + Matchmaker.BELOW, table.size() - 1) + 1):
		var other := table.boxers[j]
		if other != boxer and free.call(other):
			out.append(other)
	for id in requests:
		for other in table.boxers:
			if other.id == id and not out.has(other) and free.call(other):
				out.append(other)
	out.sort_custom(func(a: BoxerData, b: BoxerData) -> bool:
		var ra := requests.has(a.id)
		var rb := requests.has(b.id)
		if ra != rb:
			return ra
		return table.index_of(a) < table.index_of(b))
	return out


## The men who asked to fight him and still can (free, in his division).
func live_requests(season: Season) -> Array[BoxerData]:
	var out: Array[BoxerData] = []
	for b in opponents(season):
		if requests.has(b.id):
			out.append(b)
	return out


## The usual purse for a fight with [param other] (title if he is champion).
func usual_purse(season: Season, other: BoxerData) -> int:
	var table := season.rankings_of(boxer)
	return Purse.for_fight(table.index_of(boxer), table.index_of(other), table.size(), boxer.division, table.is_champion(other))


## The five purses he can offer [param other].
func purse_offers(season: Season, other: BoxerData) -> Array[int]:
	var usual := usual_purse(season, other)
	var out: Array[int] = []
	for share in PURSE_OFFERS:
		out.append(maxi(roundi(usual * share / 10.0) * 10, MIN_PURSE))
	return out


## He must be able to put up half the purse.
func can_offer(purse: int) -> bool:
	return money * 2 >= purse


## Chance [param other] says yes to purse option [param offer] (0 - 4).
func accept_chance(season: Season, other: BoxerData, offer: int) -> float:
	var table := season.rankings_of(boxer)
	if requests.has(other.id):
		return clampf(KEEN_ACCEPT + PURSE_SWAY[offer] * 0.3, 0.0, 0.99)
	var chance := UNSURE_ACCEPT + PURSE_SWAY[offer]
	# A man ranked above him has less to gain; one below, more.
	chance -= (table.index_of(boxer) - table.index_of(other)) * 0.03
	match other.manager.type:
		ManagerData.Type.MONEY:
			chance += PURSE_SWAY[offer] * 0.5
		ManagerData.Type.PROTECTIVE:
			if boxer.overall() > other.overall() + Matchmaker.PROTECTIVE_REFUSES:
				chance -= 0.3
		ManagerData.Type.OLD_SCHOOL:
			chance += 0.1
	return clampf(chance, 0.05, 0.97)


## Offers [param other] a fight for purse option [param offer]. Returns the
## new Fixture, or null if he turned it down.
func challenge(season: Season, other: BoxerData, offer: int) -> Fixture:
	var purse: int = purse_offers(season, other)[offer]
	if not can_offer(purse) or not can_arrange(season) or declined.has(other.id):
		return null
	if _rng.randf() >= accept_chance(season, other, offer):
		declined.append(other.id)
		_log("%s TURNED DOWN YOUR OFFER OF %s." % [other.display_name().to_upper(), Purse.money_text(purse)])
		return null
	var f := season.book_player_fight(boxer, other, purse)
	requests.erase(other.id)
	_log("FIGHT ARRANGED: %s, END OF %s, FOR %s." % [other.display_name().to_upper(), Season.date_text(f.month), Purse.money_text(purse)])
	return f


## What calling off the arranged fight would cost.
func forfeit(season: Season) -> int:
	var f := season.booking(boxer)
	return roundi(f.purse * FORFEIT) if f != null else 0


## Calls off the arranged fight, paying the forfeit.
func cancel_fight(season: Season) -> void:
	var f := season.booking(boxer)
	if f == null:
		return
	var cost := forfeit(season)
	money -= cost
	season.cancel_fixture(f)
	_log("FIGHT WITH %s CALLED OFF. FORFEIT PAID: %s." % [f.opponent_of(boxer).display_name().to_upper(), Purse.money_text(cost)])


# ----------------------------------------------------------------------------
#  Saving
# ----------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"boxer": boxer.id, "money": money, "week": week, "trained": trained, "last_gains": last_gains,
		"training_facility": training_facility, "recovery_facility": recovery_facility,
		"sponsor": sponsor, "sponsor_offers": sponsor_offers, "requests": requests,
		"declined": declined, "news": news,
	}


func load_dict(d: Dictionary) -> void:
	money = int(d["money"])
	week = int(d["week"])
	trained = int(d["trained"])
	last_gains = d["last_gains"]
	training_facility = int(d["training_facility"])
	recovery_facility = int(d["recovery_facility"])
	sponsor = d["sponsor"]
	sponsor_offers.assign(d["sponsor_offers"])
	requests.assign(d["requests"])
	declined.assign(d["declined"])
	news.assign(d["news"])
