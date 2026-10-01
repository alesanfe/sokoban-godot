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
	var main: Control = load("res://scripts/main.gd").new()
	# main.tscn le da FULL_RECT; instanciado por script nace con size 0
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child.call_deferred(main)
	_shots = [
		[func(): main.show_menu(), "menu"],
		[func(): main.show_game(_demo_level()), "gameplay"],
		[func(): main.show_game(Campaign.levels()[30]), "mutant"],
		[func(): main.show_level_select(), "select"],
		[func(): main.show_editor(), "editor"],
		[func(): main.show_community(), "community"],
		[func(): main.show_map(), "map"],
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
		_pending = ""
		return _i >= _shots.size()          # último → salir
	if _i < _shots.size():
		_shots[_i][0].call()
		_pending = _shots[_i][1]
		_i += 1
	return false
