extends SceneTree
## Re-checks only the Microban levels that hit the state cap.

const HARD := [93, 105, 111, 112, 123, 139, 144, 145, 146, 153]

func _initialize() -> void:
	var levels := LevelPack.load_microban()
	var t0 := Time.get_ticks_msec()
	for n in HARD:
		var l: LevelData = levels[n - 1]
		var res := SokobanSolver.solve(l, 400000)
		print("%s: %s (%d moves, %d states, %d ms)" % [
			l.title, "OK" if res.get("ok", false) else "FAIL " + res.get("reason", ""),
			res["moves"].size(), res["states"], Time.get_ticks_msec() - t0])
	quit()
