extends SceneTree
## Balance checker: runs many complete fights with no graphics and prints a
## summary, so damage, stamina and AI numbers can be tuned with evidence.
##
##   godot --headless --path . -s tools/simulate_fights.gd -- --fights=200
##
## A fight runs at 60 steps per real second, exactly as in the game.

const STEP := 1.0 / 60.0


func _initialize() -> void:
	var fights := 200
	var seed_value := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fights="):
			fights = int(arg.trim_prefix("--fights="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))

	var methods := {}
	var by_style_wins := [0, 0, 0, 0, 0]
	var by_style_fights := [0, 0, 0, 0, 0]
	var totals := {"thrown": 0.0, "landed": 0.0, "blocked": 0.0, "knockdowns": 0.0, "end_health": 0.0, "end_energy": 0.0, "clinches": 0.0}
	var rounds_ended := [0, 0, 0, 0]
	# Judging: how often the official result differs from a neutral card.
	var judging := {"decisions": 0, "differs": 0, "robbery": 0, "all_agree": 0, "pundit_right": 0, "split_rounds": 0, "rounds": 0}
	var pundits := {}   # name -> [calls matching a neutral card, fights]

	for n in fights:
		var gen := BoxerGenerator.new(seed_value * 1000 + n)
		var roster := gen.generate_roster(2)
		var sim := FightSim.new(roster[0], roster[1], seed_value * 7919 + n)
		var clinches := [0]
		sim.knocked_down.connect(func(_c: int) -> void: totals["knockdowns"] += 1.0)
		sim.start_fight()
		var guard := 0
		while sim.phase != FightSim.Phase.FINISHED and guard < 60 * 400:
			var before_clinch := sim.red.state == Fighter.State.CLINCH
			sim.step(STEP)
			if not before_clinch and sim.red.state == Fighter.State.CLINCH:
				clinches[0] += 1
			guard += 1
		var r: Dictionary = sim.result
		if r["method"] in ["UD", "MD", "SD", "DRAW"]:
			_judging_stats(sim, judging)
			var pname: String = sim.judges.pundit["name"]
			var tally: Array = pundits.get(pname, [0, 0])
			if _winner(sim.judges.pundit_totals()) == _winner(sim.judges.fair_totals()):
				tally[0] += 1
			tally[1] += 1
			pundits[pname] = tally
		methods[r["method"]] = methods.get(r["method"], 0) + 1
		rounds_ended[r["round"]] += 1
		for f in sim.fighters:
			totals["thrown"] += f.fight_stats["thrown"]
			totals["landed"] += f.fight_stats["landed"]
			totals["blocked"] += f.fight_stats["blocked"]
			totals["end_health"] += f.health
			totals["end_energy"] += f.energy
			by_style_fights[f.data.style] += 1
			if r["winner"] == f.corner:
				by_style_wins[f.data.style] += 1
		totals["clinches"] += clinches[0]

	var boxers := fights * 2.0
	print("")
	print("FIGHTS SIMULATED  %d" % fights)
	print("------------------------------------------")
	for m in ["KO", "TKO", "UD", "MD", "SD", "DRAW"]:
		print("  %-6s %5d   %5.1f%%" % [m, methods.get(m, 0), 100.0 * methods.get(m, 0) / fights])
	print("------------------------------------------")
	print("  Ended in round 1/2/3:  %d / %d / %d" % [rounds_ended[1], rounds_ended[2], rounds_ended[3]])
	print("  Punches thrown / boxer  %6.1f" % (totals["thrown"] / boxers))
	print("  Punches landed / boxer  %6.1f" % (totals["landed"] / boxers))
	print("  Punches blocked / boxer %6.1f" % (totals["blocked"] / boxers))
	print("  Accuracy                %5.1f%%" % (100.0 * totals["landed"] / maxf(totals["thrown"], 1.0)))
	print("  Knockdowns / fight      %6.2f" % (totals["knockdowns"] / fights))
	print("  Clinches / fight        %6.2f" % (totals["clinches"] / fights))
	print("  Health at the end       %6.1f" % (totals["end_health"] / boxers))
	print("  Energy at the end       %6.1f" % (totals["end_energy"] / boxers))
	print("------------------------------------------")
	var d: float = maxf(judging["decisions"], 1)
	print("  Decisions                %5d" % judging["decisions"])
	print("  ...differ from fair card %5.1f%%" % (100.0 * judging["differs"] / d))
	print("  ...wrong winner (robbery)%5.1f%%" % (100.0 * judging["robbery"] / d))
	print("  ...all 3 cards identical %5.1f%%" % (100.0 * judging["all_agree"] / d))
	print("  ...pundit called it      %5.1f%%" % (100.0 * judging["pundit_right"] / d))
	print("  Rounds judges split on   %5.1f%%" % (100.0 * judging["split_rounds"] / maxf(judging["rounds"], 1)))
	print("------------------------------------------")
	print("  Pundit          same result as a neutral card")
	for pname in pundits:
		var p: Array = pundits[pname]
		print("  %-15s %5.1f%%  (%d fights)" % [pname, 100.0 * p[0] / maxf(p[1], 1), p[1]])
	print("------------------------------------------")
	for s in 5:
		var pct: float = 100.0 * by_style_wins[s] / maxf(by_style_fights[s], 1.0)
		print("  %-8s wins %5.1f%% of %d fights" % [BoxerData.STYLE_NAMES[s], pct, by_style_fights[s]])
	print("")
	quit()


static func _winner(t: Array) -> int:
	return 0 if t[0] > t[1] else (1 if t[1] > t[0] else -1)


func _judging_stats(sim: FightSim, out: Dictionary) -> void:
	var j: Judges = sim.judges
	var official: int = sim.result["winner"]
	var fair := _winner(j.fair_totals())
	out["decisions"] += 1
	if official != fair:
		out["differs"] += 1
		if official >= 0 and fair >= 0:
			out["robbery"] += 1
	var first: Array = j.totals(0)
	if j.totals(1) == first and j.totals(2) == first:
		out["all_agree"] += 1
	if _winner(j.pundit_totals()) == official:
		out["pundit_right"] += 1
	for r in j.rounds:
		out["rounds"] += 1
		if not (j.cards[0][r] == j.cards[1][r] and j.cards[1][r] == j.cards[2][r]):
			out["split_rounds"] += 1
