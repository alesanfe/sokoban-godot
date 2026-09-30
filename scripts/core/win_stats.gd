class_name WinStats
extends RefCounted
## Lógica pura de la línea de victoria: medalla, estrellas y badges.
## Extraída de game_screen para poder testearla headless sin UI.


## {medal, stars} según par — una victoria asistida no medalla.
static func medal(par: int, moves: int, assisted: bool) -> Dictionary:
	var stars := 1
	var m := "COMPLETADO"
	if par > 0 and not assisted:
		if moves <= par:
			stars = 3
			m = "PERFECTO"
		elif moves <= int(par * 1.25):
			stars = 2
			m = "ORO"
		elif moves <= int(par * 1.5):
			stars = 1
			m = "PLATA"
		else:
			m = "BRONCE"
	return {"medal": m, "stars": stars}


## Texto multi-línea del panel de victoria.
static func summary(par: int, moves: int, pushes: int, elapsed: float,
		undos_used: int, restarts_used: int,
		assisted: bool) -> String:
	var r := medal(par, moves, assisted)
	var badges := PackedStringArray()
	if assisted:
		badges.append("con solucionador")
	if undos_used == 0 and not assisted:
		badges.append("sin deshacer")
	if restarts_used == 0 and not assisted:
		badges.append("sin reiniciar")
	var info := PackedStringArray()
	info.append("Medalla: %s  %s" % [r["medal"], "★".repeat(r["stars"])])
	info.append("%d movimientos · %d empujes · %02d:%02d" % [
		moves, pushes, int(elapsed) / 60, int(elapsed) % 60])
	if par > 0:
		info.append("Par: %d" % par)
	if not badges.is_empty():
		info.append("· " + " · ".join(badges))
	return "¡Nivel completado!\n" + "\n".join(info)
