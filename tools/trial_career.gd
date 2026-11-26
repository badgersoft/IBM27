extends SceneTree
## Trial careers: plays whole careers for the player's boxer with no
## graphics, run by a simple manager, and reports how long he takes to
## become a contender (close enough to the champion to challenge him) and
## the champion. Used to check the balance of training, purses, sponsors and
## the rankings after a change.
##
##   godot --headless --path . -s tools/trial_career.gd -- [options]
##
##   --careers=<n>        careers to play (default 6)
##   --division=<0|1|2>   lightweight, middleweight, heavyweight (default 1)
##   --style=<name>       brawler, slugger, boxer (default), counter, evasive
##                        or showboat
##   --manager=<name>     ambitious (default): always the highest-ranked man
##                        he may fight, the best gym he can afford; casual:
##                        men who asked for the fight first, a cheaper gym
##   --months=<n>         longest career to play (default 180, 15 years)
##   --seed=<n>           first career's seed (default 1)
##   --yearly             also print his overall and ranking each year
##   --field              also print how strong his division is each year
##                        (average overall of the champion, places 1-5,
##                        6-10, 11-20, 21-30 and the weakest man), from the
##                        start; plays every month (implies --yearly)
##   --whole-world        also fight the other two divisions' fights (by
##                        default they are called off: they can't affect
##                        his career, and skipping them is three times as
##                        fast - about 4 s a month instead of 13)
##
## To use all the cores, run several at once with different seeds, e.g.
##   for s in 1 2 3 4; do godot --headless --path . -s tools/trial_career.gd \
##       -- --careers=1 --seed=$s & done; wait
##
## Each career is a fresh world (GameState.start_career), so careers with
## the same seed and options play out the same way. The month's other fights
## are fought by Season.play_month, his included, exactly as on fight night.

const SKILLS: Array[String] = ["power", "speed", "stamina", "chin", "strength", "intelligence"]
## Where his 45 starting points go: a share each (in SKILLS order).
const SPEND: Array[float] = [0.25, 0.2, 0.15, 0.2, 0.1, 0.1]
## Weeks of rent he must have in the bank, after the next stake, before
## moving up to a gym (ambitious, casual).
const GYM_RESERVE_WEEKS: Array[int] = [16, 40]
const RECOVERY_RESERVE_WEEKS: Array[int] = [24, 60]
## Below this health he spends the week on RECOVERY.
const REST_BELOW := 80.0
## Fight offers tried per week.
const TRIES_PER_WEEK := 3

var _gs: Node
var _manager := 0   # 0 ambitious, 1 casual
var _field := false


func _initialize() -> void:
	await process_frame
	_gs = root.get_node("GameState")
	var careers := 6
	var division := 1
	var style := BoxerData.Style.BOXER
	var whole_world := false
	var months := 180
	var seed_value := 1
	var yearly := false
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		match kv[0]:
			"careers": careers = int(kv[1])
			"division": division = clampi(int(kv[1]), 0, 2)
			"style": style = maxi(BoxerData.STYLE_NAMES.map(func(n: String) -> String: return n.to_lower()).find(kv[1].to_lower()), 0)
			"whole-world": whole_world = true
			"manager": _manager = 1 if kv[1] == "casual" else 0
			"months": months = int(kv[1])
			"seed": seed_value = int(kv[1])
			"yearly": yearly = true
			"field": _field = true
	print("TRIAL CAREERS: %d x %s, %s, %s manager, up to %d months" % [careers,
			Divisions.get_division(division)["name"], BoxerData.STYLE_NAMES[style],
			"casual" if _manager == 1 else "ambitious", months])
	var results: Array[Dictionary] = []
	for c in careers:
		results.append(_career(seed_value + c, division, style, months, yearly, whole_world))
	_summary(results)
	quit()


## Plays one career. Returns {"contender", "champion", "record", "overall",
## "money", "age"} (months as -1 if never reached).
func _career(seed_value: int, division: int, style: int, months: int, yearly: bool, whole_world: bool) -> Dictionary:
	var b: BoxerData = BoxerGenerator.new(seed_value).generate_player(division as Divisions.Id)
	b.style = style as BoxerData.Style
	b.first_name = "Trial"
	b.last_name = "Boxer%d" % seed_value
	var pool := PlayerCareer.START_POOL
	for i in SKILLS.size():
		var add := roundi(PlayerCareer.START_POOL * SPEND[i]) if i < SKILLS.size() - 1 else pool
		add = mini(add, pool)
		b.set(SKILLS[i], b.get(SKILLS[i]) + add)
		pool -= add
	_gs.start_career(b, false)
	var career: PlayerCareer = _gs.career
	career._rng.seed = seed_value
	var season: Season = _gs.season
	var out := {"contender": -1, "champion": -1}
	yearly = yearly or _field
	if _field:
		_print_field(season.rankings_of(b), b, 0)
	for m in months:
		for week in PlayerCareer.WEEKS_PER_MONTH:
			_week(career, season)
			if week < PlayerCareer.WEEKS_PER_MONTH - 1:
				career.end_week()
		if not whole_world:
			for f in season.fixtures_in(season.month):
				if f.division != division:
					season.cancel_fixture(f)
		season.play_month()
		career.end_month(season)
		var table := season.rankings_of(b)
		if out["contender"] < 0 and table.index_of(b) <= Matchmaker.ABOVE:
			out["contender"] = m + 1
		if out["champion"] < 0 and table.is_champion(b):
			out["champion"] = m + 1
		if yearly and (m + 1) % 12 == 0:
			print("    year %2d  age %d  overall %d  %-8s %s  %s" % [int((m + 1) / 12.0), b.age, b.overall(),
					table.rank_text(b), b.record(), Purse.money_text(career.money)])
		if _field and (m + 1) % 12 == 0:
			_print_field(season.rankings_of(b), b, int((m + 1) / 12.0))
		if out["champion"] >= 0 and not yearly:
			break
	out["record"] = b.record()
	out["overall"] = b.overall()
	out["money"] = career.money
	out["age"] = b.age
	print("  career %d: contender %s, champion %s - %s, overall %d, age %d, %s" % [seed_value,
			_months(out["contender"]), _months(out["champion"]), out["record"], out["overall"], out["age"],
			Purse.money_text(out["money"])])
	return out


## One week: sponsor, facilities, a fight if he can arrange one, training.
func _week(career: PlayerCareer, season: Season) -> void:
	if not career.sponsor_offers.is_empty():
		var best := 0
		for i in career.sponsor_offers.size():
			if career.sponsor_offers[i]["pay"] > career.sponsor_offers[best]["pay"]:
				best = i
		career.accept_sponsor(best)
	_choose_facilities(career)
	if career.can_arrange(season):
		_arrange(career, season)
	var b := career.boxer
	if b.condition < REST_BELOW:
		career.train(Facilities.Session.RECOVERY)
	else:
		career.train(_weakest_session(b))


## The best gym (then recovery centre) he can keep paying for.
func _choose_facilities(career: PlayerCareer) -> void:
	for kind in [Facilities.Kind.TRAINING, Facilities.Kind.RECOVERY]:
		var list := Facilities.list(kind)
		var reserve: int = (GYM_RESERVE_WEEKS if kind == Facilities.Kind.TRAINING else RECOVERY_RESERVE_WEEKS)[_manager]
		var pick := 0
		for i in list.size():
			if int(list[i]["cost"]) * reserve <= career.money:
				pick = i
		career.set_facility(kind, pick)


## Tries to book a fight: the ambitious manager goes for the highest-ranked
## man he may fight, the casual one for the men who asked first.
func _arrange(career: PlayerCareer, season: Season) -> void:
	var table := season.rankings_of(career.boxer)
	var options := career.opponents(season)
	if _manager == 0:
		options.sort_custom(func(x: BoxerData, y: BoxerData) -> bool: return table.index_of(x) < table.index_of(y))
	for other in options.slice(0, TRIES_PER_WEEK):
		var offer := 3 if _manager == 0 else 2
		while offer > 0 and not career.can_offer(career.purse_offers(season, other)[offer], offer):
			offer -= 1
		if career.challenge(season, other, offer) != null:
			return


## The session for the skills furthest behind: each session's main skill,
## plus its second skill at half weight.
func _weakest_session(b: BoxerData) -> int:
	var best := 0
	var lowest := INF
	for i in Facilities.Session.RECOVERY:
		var s: Array = Facilities.SESSIONS[i]
		var value := float(b.get(s[1])) + 0.5 * float(b.get(s[3]))
		if value < lowest:
			lowest = value
			best = i
	return best


## "FIELD year 3: champion 84 | 1-5 81 | 6-10 76 | 11-20 69 | 21-30 55 | weakest 44 | him 61 (NO. 17)"
func _print_field(table: Rankings, me: BoxerData, year: int) -> void:
	var avg := func(from: int, to: int) -> float:
		var total := 0.0
		var n := 0
		for i in range(from, mini(to, table.size())):
			if table.boxers[i] != me:
				total += table.boxers[i].overall()
				n += 1
		return total / maxf(n, 1.0)
	var weakest := 99
	for other in table.boxers:
		if other != me:
			weakest = mini(weakest, other.overall())
	var champ := table.champion.overall() if table.champion != null else 0
	print("    FIELD year %2d: champion %d | 1-5 %.0f | 6-10 %.0f | 11-20 %.0f | 21-30 %.0f | weakest %d | him %d (%s)" % [
			year, champ, avg.call(1, 6), avg.call(6, 11), avg.call(11, 21), avg.call(21, 31), weakest, me.overall(), table.rank_text(me)])


func _summary(results: Array[Dictionary]) -> void:
	for key in ["contender", "champion"]:
		var reached := results.filter(func(r: Dictionary) -> bool: return r[key] >= 0)
		var months := reached.map(func(r: Dictionary) -> int: return r[key])
		months.sort()
		var mean := 0.0
		for m in months:
			mean += m
		mean = mean / maxf(months.size(), 1.0)
		if months.is_empty():
			print("%-10s 0 of %d" % [key.to_upper(), results.size()])
		else:
			print("%-10s %d of %d, average month %.0f (%.1f years), range %d - %d" % [key.to_upper(), reached.size(),
					results.size(), mean, mean / 12.0, months[0], months[-1]])


static func _months(m: int) -> String:
	return "never" if m < 0 else "month %d" % m
