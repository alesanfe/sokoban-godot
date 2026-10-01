extends SceneTree
## Graba frames de una partida autojugada para montar un GIF del README.
## Ventana real (no --headless). Después:
##   python tools/make_gif.py
## → docs/assets/demo.gif

const OUT := "res://docs/assets/"
const FRAMES_DIR := "res://docs/assets/_frames/"
const CAPTURE_EVERY := 5      # ~12 fps de captura
const MAX_FRAMES := 80        # autoplay + panel de victoria

var _frame := 0
var _n := 0
var _main: Control
var _started := false


func _initialize() -> void:
	Storage.BASE_DIR = "user://shots/"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(FRAMES_DIR))
	var main: Control = load("res://scripts/main.gd").new()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child.call_deferred(main)
	_main = main            # show_game se lanza tras unos frames



## Dos cajas, dos metas: 8 empujes claros y panel de victoria al final.
func _demo_level() -> LevelData:
	return LevelData.create("Demo", PackedStringArray([
		"#########",
		"#       #",
		"#@  $ . #",
		"#   $  .#",
		"#       #",
		"#########",
	]), [])


func _moves() -> PackedStringArray:
	var m := PackedStringArray()
	for ch: String in "rrrrdrrr":
		m.append(ch)
	return m


func _process(_dt: float) -> bool:
	_frame += 1
	# add_child es deferred: montar el juego solo cuando main está en árbol
	if not _started:
		if _frame < 10 or not _main.is_inside_tree():
			return false
		_main.show_game(_demo_level(), {"autoplay": _moves()})
		_started = true
		_frame = 0
		return false
	if _frame < CAPTURE_EVERY:
		return false
	_frame = 0
	_n += 1
	var img := root.get_texture().get_image()
	img.save_png(FRAMES_DIR + "f%03d.png" % _n)
	return _n >= MAX_FRAMES
