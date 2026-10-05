extends SceneTree
## Regresión visual: compara docs/assets/screenshots/*.png contra el baseline
## bendecido en docs/assets/_baseline/. Reporta el % de píxeles
## cambiados por archivo y genera diffs resaltados en _diffs/.
##
## Uso:
##   godot --path . -s res://tools/shots_diff.gd            → compara
##   godot --path . -s res://tools/shots_diff.gd --update   → bendice
##
## Exit 0 = sin diferencias > umbral. Exit 2 = regresión.
## Subdirectorios (sizes/, _baseline, _diffs) se ignoran.

const BASE := "res://docs/assets/_baseline/"
const CUR := "res://docs/assets/screenshots/"
const DIFF_OUT := "res://docs/assets/_diffs/"

const TOLERANCE := 14        # por canal (0-255): ignora ruido AA
const CHANGED_MIN := 0.5     # % de píxeles para considerar regresión


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--update"):
		_update_baseline()
		return
	_run_diff()


## Copia los PNG actuales al baseline (salvo subdirs).
func _update_baseline() -> void:
	var src := DirAccess.open(CUR)
	if src == null:
		push_error("No existe " + CUR)
		return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(BASE))
	var n := 0
	for f in src.get_files():
		if f.ends_with(".png"):
			DirAccess.copy_absolute(
				ProjectSettings.globalize_path(CUR + f),
				ProjectSettings.globalize_path(BASE + f))
			n += 1
	print("baseline: %d pngs bendecidos en %s" % [n, BASE])
	quit(0)


func _run_diff() -> void:
	var base := DirAccess.open(BASE)
	if base == null:
		push_error("Sin baseline — corre con --update primero")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(DIFF_OUT))
	var regressions := 0
	var checked := 0
	for f in base.get_files():
		if not f.ends_with(".png"):
			continue
		checked += 1
		var a := Image.load_from_file(
			ProjectSettings.globalize_path(BASE + f))
		var b := Image.load_from_file(
			ProjectSettings.globalize_path(CUR + f))
		if a == null or b == null or a.is_empty() or b.is_empty():
			print("?? %-40s falta en current o no carga" % f)
			regressions += 1
			continue
		if a.get_size() != b.get_size():
			print("!! %-40s tamaño %s → %s" % [
				f, a.get_size(), b.get_size()])
			regressions += 1
			continue
		var pct := _diff_pct(a, b, f)
		if pct > CHANGED_MIN:
			regressions += 1
			print("!! %-40s %.1f%% píxeles cambiados" % [f, pct])
		elif pct > 0.0:
			print("~~ %-40s %.2f%% (bajo umbral)" % [f, pct])
	# ficheros nuevos sin baseline: no es regresión, pero avisar
	var cur := DirAccess.open(CUR)
	for f in cur.get_files():
		if f.ends_with(".png") and \
				not FileAccess.file_exists(
					ProjectSettings.globalize_path(BASE + f)):
			print("++ %-40s nuevo (sin baseline)" % f)
	print("== diff: %d ficheros, %d regresiones ==" % [
		checked, regressions])
	quit(2 if regressions > 0 else 0)


## % de píxeles que difieren más que TOLERANCE; si difieren, escribe
## docs/assets/_diffs/<f> con los píxeles cambiados en magenta.
func _diff_pct(a: Image, b: Image, name: String) -> float:
	var w := a.get_width()
	var h := a.get_height()
	var changed := 0
	var mark := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var any := false
	for y in h:
		for x in w:
			var pa := a.get_pixel(x, y)
			var pb := b.get_pixel(x, y)
			var d := maxf(absf(pa.r - pb.r),
				maxf(absf(pa.g - pb.g), absf(pa.b - pb.b)))
			if d * 255.0 > TOLERANCE:
				changed += 1
				any = true
				mark.set_pixel(x, y, Color(1, 0, 1))
			else:
				mark.set_pixel(x, y, Color(pb, 0.25))
	if any:
		mark.save_png(ProjectSettings.globalize_path(DIFF_OUT + name))
	return 100.0 * changed / float(w * h)
