extends SceneTree
## Genera las capturas de docs/assets/ con las pantallas reales.
## Hay que correrlo CON ventana (sin --headless): el render dummy no
## produce píxeles. godot --path . -s res://tools/screenshots.gd
## (la ventana aparece unos segundos y se cierra sola)

const OUT := "res://docs/assets/"

var _frame := 0
var _shots: Array = []        # [Callable monta la vista, nombre]
var _i := 0
var _pending := ""            # vista montada, pendiente de capturar
var _recentered := false


func _initialize() -> void:
	# user:// aislado: no tocar el progreso real del jugador
	Storage.BASE_DIR = "user://shots/"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(OUT))
	_seed_progress()
	var main: Control = load("res://scripts/main.gd").new()
	# main.tscn le da FULL_RECT; instanciado por script nace con size 0
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child.call_deferred(main)
	_shots = [
		[func(): main.show_menu(), "menu"],
		[func(): main.show_game(_demo_level()), "gameplay"],
		[func(): main.show_game(Campaign.levels()[30]), "mutant"],
		[func(): main.show_level_select(), "select"],
		[func(): _editor_shot(main), "editor"],
		[func(): _import_shot(main), "import"],
		[func(): main.show_community(), "community"],
		[func(): main.show_map(), "map"],
		[func(): main.show_stats(), "stats"],
		[func(): main.show_options(), "options"],
		[func(): main.show_controls(), "controls"],
		[func(): main.show_generator(), "generator"],
	]


## Nivel de muestra: varios tiles especiales que saltan a la vista
## (cintas + portales + cajas/metas de color).
func _demo_level() -> LevelData:
	return LevelData.create("La guarida mutante", PackedStringArray([
		"###########",
		"#@  b  c  #",
		"#  ##  ## #",
		"# > >>^v  #",
		"#  B  C   #",
		"###o#####O#",
		"###########",
	]), [{"id": "conveyor", "params": {}},
		{"id": "portal", "params": {}}])


func _process(_dt: float) -> bool:
	_frame += 1
	# 8 frames por paso: _ready, layout, resized y tweens pintan todo
	if _frame < 8:
		return false
	_frame = 0
	if _pending != "":
		# fuerza un re-centrado por si resized disparó con state==null
		if not _recentered and _pending in ["gameplay", "mutant"] \
				and root.get_child_count() > 0:
			var scr: Variant = root.get_child(0).get("current")
			if scr != null and scr.has_method("_center_board"):
				scr._center_board()
				print("dbg tile=%s pos=%s holder=%s px=%s" % [
					scr.board.tile, scr.board.position,
					scr.board_holder.size, scr.board.board_pixel_size()])
			_recentered = true
			return false            # un frame más y se captura
		_recentered = false
		var img := root.get_texture().get_image()
		img.save_png(OUT + _pending + ".png")
		print("shot: ", _pending)
		if _pending == "editor":
			root.size.y = 720              # restaurar para el resto
		_pending = ""
		return _i >= _shots.size()          # último → salir
	if _i < _shots.size():
		_shots[_i][0].call()
		_pending = _shots[_i][1]
		_i += 1
	return false


## El editor es la pantalla más alta (grid + paleta + toolbar);
## se captura con la ventana algo más alta para que nada quede
## cortado abajo, y se restaura al salir. Se le da un nivel con
## contenido — la cuadrícula vacía no enseña nada.
func _editor_shot(main: Control) -> void:
	root.size.y = 860
	main.show_editor(_demo_level())


## El importador se captura con un código pegado — la TextEdit
## vacía era solo un rectángulo negro.
func _import_shot(main: Control) -> void:
	main.show_import()
	for n in root.find_children("*", "TextEdit", true, false):
		(n as TextEdit).text = "#######\n#@ $ .#\n#######"


## Progreso de muestra: los shots de select/mapa/stats con todo a
## cero parecen un juego vacío. El user:// aislado hace que esto
## no toque el progreso real del jugador.
func _seed_progress() -> void:
	var camp := Campaign.levels()
	for i in range(0, 26, 2):
		var moves := PackedStringArray()
		for _j in 6 + i % 9:
			moves.append("r")
		Storage.record_win(camp[i], moves, 20.0 + i)
	# un nivel custom para que el feed/mapa lo tengan
	Storage.save_custom_level(_demo_level())
