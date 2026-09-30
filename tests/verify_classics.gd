extends SceneTree
## Verifies the Microban pack: parses, validates, and solves each level.

func _initialize() -> void:
	var levels := LevelPack.load_microban()
	print("Loaded %d levels" % levels.size())
	var bad := PackedStringArray()
	var unsolved := PackedStringArray()
	var t0 := Time.get_ticks_msec()
	for l in levels:
		var probs: PackedStringArray = l.validate()
		if not probs.is_empty():
			bad.append("%s: %s" % [l.title, "; ".join(probs)])
			continue
		var res := SokobanSolver.solve(l, 200000)
		if not res.get("ok", false):
			unsolved.append("%s (%s)" % [l.title, res.get("reason", "?")])
		print("done %s: %d moves, %d states, %d ms" % [
			l.title, res["moves"].size(), res["states"],
			Time.get_ticks_msec() - t0])
	print("valid: %d / %d" % [levels.size() - bad.size(), levels.size()])
	for b in bad:
		print("  INVALID " + b)
	print("solver-verified: %d / %d in %d ms" % [levels.size() - bad.size() - unsolved.size(), levels.size() - bad.size(), Time.get_ticks_msec() - t0])
	for u in unsolved:
		print("  UNSOLVED " + u)
	quit()
