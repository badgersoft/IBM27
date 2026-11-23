extends SceneTree
## Style balance: every style against every other, with nothing else
## different - both men are copies of one boxer (same skills, size and
## recovery), only the style changes. Each pairing is fought --fights times,
## half of them with the corners swapped.
##
##   godot --headless --path . -s tools/style_matrix.gd -- [--level=85] [--fights=40] [--division=1] [--rounds=10]
##
## Prints each style's win share against each other style and overall, and
## what it does in a fight (punches thrown and landed, big punches, clean
## work taken) per boxer per fight.

const STEP := 1.0 / 60.0
const SKILLS: Array[String] = ["power", "speed", "stamina", "chin", "strength", "intelligence"]
const STYLES := 6


func _initialize() -> void:
	var level := 85
	var fights := 40
	var division := 1
	var rounds := 10
	var seed_value := 1
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=")
		match kv[0]:
			"level": level = int(kv[1])
			"fights": fights = int(kv[1])
			"division": division = int(kv[1])
			"rounds": rounds = int(kv[1])
			"seed": seed_value = int(kv[1])
	var base: BoxerData = BoxerGenerator.new(seed_value).generate_boxer([], division as Divisions.Id)
	base.special = BoxerData.Special.NONE
	for s in SKILLS:
		base.set(s, level)
	base.recovery = level
	base.start_health = 95.0
	var size := Divisions.get_division(division)
	base.height_cm = roundi((size["height_cm"][0] + size["height_cm"][1]) / 2.0)
	base.weight_lb = roundi((size["weight_lb"][0] + size["weight_lb"][1]) / 2.0)

	var wins := []      # wins[a][b]: a's wins over b
	var played := []
	var stats := []     # per style: thrown, landed, big, landed on him, fights, stoppages won
	for a in STYLES:
		wins.append([0, 0, 0, 0, 0, 0])
		played.append([0, 0, 0, 0, 0, 0])
		stats.append([0.0, 0.0, 0.0, 0.0, 0, 0])
	var n := 0
	for a in STYLES:
		for b in range(a + 1, STYLES):
			for i in fights:
				var red := _copy(base, a if i % 2 == 0 else b, 1)
				var blue := _copy(base, b if i % 2 == 0 else a, 2)
				var sim := FightSim.new(red, blue, seed_value * 7919 + n, rounds)
				n += 1
				sim.start_fight()
				var guard := 0
				while sim.phase != FightSim.Phase.FINISHED and guard < 60 * 1500:
					sim.step(STEP)
					guard += 1
				var r: Dictionary = sim.result
				for f in sim.fighters:
					var me: int = f.data.style
					var them: int = sim.opponent_of(f).data.style
					played[me][them] += 1
					stats[me][0] += f.fight_stats["thrown"]
					stats[me][1] += f.fight_stats["landed"]
					stats[me][2] += f.fight_stats["big"]
					stats[me][3] += sim.opponent_of(f).fight_stats["landed"]
					stats[me][4] += 1
					if r["winner"] == f.corner:
						wins[me][them] += 1
						if r["method"] in ["KO", "TKO"]:
							stats[me][5] += 1
	print("")
	print("STYLE MATRIX: skills %d, %s, %d rounds, %d fights a pairing (draws count as half)" % [level,
			Divisions.division_name(division).to_upper(), rounds, fights])
	var header := "            "
	for b in STYLES:
		header += "%9s" % BoxerData.STYLE_NAMES[b].substr(0, 8)
	print(header + "    ALL   THROWN LANDED  BIG  TAKEN  KO WINS")
	for a in STYLES:
		var line := "  %-9s " % BoxerData.STYLE_NAMES[a]
		var all_w := 0.0
		var all_p := 0
		for b in STYLES:
			if a == b:
				line += "%9s" % "-"
				continue
			var draws: int = played[a][b] - wins[a][b] - wins[b][a]
			var share: float = (wins[a][b] + 0.5 * draws) / maxf(played[a][b], 1.0)
			all_w += wins[a][b] + 0.5 * draws
			all_p += played[a][b]
			line += "%8.0f%%" % (100.0 * share)
		var k: float = maxf(stats[a][4], 1.0)
		line += "  %4.0f%%  %6.0f %6.0f %4.1f %6.0f %5d" % [100.0 * all_w / maxf(all_p, 1), stats[a][0] / k,
				stats[a][1] / k, stats[a][2] / k, stats[a][3] / k, stats[a][5]]
		print(line)
	print("")
	quit()


static func _copy(base: BoxerData, style: int, id: int) -> BoxerData:
	var b := base.duplicate() as BoxerData
	b.style = style as BoxerData.Style
	b.id = id
	return b
