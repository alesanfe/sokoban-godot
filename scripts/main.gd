extends Control
## Root: simple screen manager. Screens are Controls built in code.


var current: Control = null
var sfx: Sfx
var music: AmbientMusic
var _bg: ColorRect


func _ready() -> void:
	UiTheme.apply(self)
	_bg = ColorRect.new()
	_bg.color = UiTheme.bg_color()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.z_index = -10
	add_child(_bg)
	sfx = Sfx.new()
	sfx.enabled = bool(Storage.get_setting("sfx"))
	add_child(sfx)
	music = AmbientMusic.new()
	music.enabled = bool(Storage.get_setting("music"))
	add_child(music)
	# after _ready: it resets volume_db to its default
	music.volume_db = -16.0 + (int(Storage.get_setting("music_vol")) - 70) * 0.24
	show_menu()


func apply_theme() -> void:
	UiTheme.apply(self)
	_bg.color = UiTheme.bg_color()


func toast(text: String) -> void:
	Widgets.toast(self, text)


func play_sfx(name: String) -> void:
	if sfx:
		sfx.play(name)


func _swap(node: Control) -> void:
	if current:
		current.queue_free()
	current = node
	add_child(node)
	# Godotwind-lite: brief fade-in between screens (skipped in
	# reduce-motion mode)
	if not bool(Storage.get_setting("reduce_motion")):
		node.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(node, "modulate:a", 1.0, 0.15)


func show_menu() -> void:
	_swap(MenuScreen.new(self))


func show_level_select() -> void:
	_swap(LevelSelectScreen.new(self))


func show_game(level: LevelData, context: Dictionary = {}) -> void:
	var s := GameScreen.new(self)
	_swap(s)
	s.start(level, context)


func show_editor(level: LevelData = null) -> void:
	_swap(EditorScreen.new(self, level))


func show_map() -> void:
	_swap(MapScreen.new(self))


func show_stats() -> void:
	_swap(StatsScreen.new(self))


func show_community() -> void:
	_swap(CommunityScreen.new(self))


func show_controls() -> void:
	_swap(ControlsScreen.new(self))


func show_options() -> void:
	_swap(OptionsScreen.new(self))


func show_generator() -> void:
	_swap(GeneratorScreen.new(self))


func show_import() -> void:
	_swap(ImportScreen.new(self))
