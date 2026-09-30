extends SceneTree
## Audit de calidad de campaña:
## godot --headless --path . -s res://tools/audit_levels.gd
##
## Por nivel: solubilidad, longitud de la solución óptima y si las
## reglas declaradas importan de verdad (¿la misma solución también
## resuelve el nivel CON las reglas desactivadas?).
##
## Criterio:
##   SIN SOLUCIÓN  → el solver no lo resuelve (error grave)
##   TRIVIAL       → solución ≤ 3 movimientos (ok para intros 1–6)
##   REGLA-ORNITO  → declara reglas, pero la solución también gana
##                   con rules_enabled=false (la regla es decorativa)


## Reglas de restricción/dificultad: resolver sin ellas es legítimo —
## no cuentan como decorativas. Las de mecánica sí deberían importar.
const CONSTRAINT_RULES := ["push_limit", "move_limit", "iron", "quota",
	"blob", "ghost", "two_players"]

## Reglas de INPUT (transform_input): solo afectan al humano — el
## solver siempre las ignora, así que el replay-off no las evalúa.
const INPUT_RULES := ["spin", "invert"]


func _initialize() -> void:
	var fails := 0
	var warns := 0
	var levels := Campaign.levels()
	for i in levels.size():
		var l: LevelData = levels[i]
		var res := SokobanSolver.solve(l)
		if not res.ok:
			fails += 1
			print("FAIL %s — sin solución (%s, %d estados)" % [
				l.title, res.reason, res.states])
			continue
		var n: int = res.moves.size()
		var flags := PackedStringArray()
		if n <= 3 and i > 5:
			flags.append("TRIVIAL")
			warns += 1
		# ¿la regla importa? replay de la solución con reglas OFF —
		# solo cuenta si el nivel tiene reglas de MECÁNICA
		var mech_rules := PackedStringArray()
		for r in l.rules:
			var rid: String = str(r.get("id", ""))
			if not CONSTRAINT_RULES.has(rid) and not INPUT_RULES.has(rid):
				mech_rules.append(rid)
		if not mech_rules.is_empty():
			var off := GameState.from_level_data(l)
			off.rules_enabled = false
			var still := true
			for ch in res.moves:
				var c: String = str(ch).to_lower()
				if c == "s":
					if not off.try_switch():
						still = false
						break
				elif not off.try_move(GameState.DIRS[c]):
					still = false
					break
			if still and off.is_solved():
				flags.append("REGLA-ORNITO:" + ",".join(mech_rules))
				warns += 1
		print("%-34s %4d movs  %6d estados  %s★ %s" % [
			l.title, n, res.states, l.difficulty,
			" ".join(flags)])
	print("== %d niveles · %d graves · %d avisos ==" % [
		levels.size(), fails, warns])
	quit(1 if fails > 0 else 0)
