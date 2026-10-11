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
	for s in 5:
		var pct: float = 100.0 * by_style_wins[s] / maxf(by_style_fights[s], 1.0)
		print("  %-8s wins %5.1f%% of %d fights" % [BoxerData.STYLE_NAMES[s], pct, by_style_fights[s]])
	print("")
	quit()
