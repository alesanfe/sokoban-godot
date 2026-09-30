extends SceneTree
## Prints solver par (move count) for each campaign level.

func _initialize() -> void:
	for l in Campaign.levels():
		var res := SokobanSolver.solve(l, 80000)
		if res.get("ok", false):
			print("%s => par %d" % [l.title, res["moves"].size()])
		else:
			print("%s => UNSOLVED (%s)" % [l.title, res.get("reason", "")])
	quit()
