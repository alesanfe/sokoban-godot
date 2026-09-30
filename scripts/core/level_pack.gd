class_name LevelPack
extends RefCounted
## Loads classic Sokoban level packs in .sok/.xsb format:
## levels separated by "; <n>" comment lines, board lines in XSB.

const MICROBAN_PATH := "res://levels/microban.sok"


static func load_microban() -> Array:
	return load_file(MICROBAN_PATH, "Microban", "David W. Skinner")


static func load_file(path: String, pack_name: String, author: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("No se pudo abrir " + path)
		return out
	var board := PackedStringArray()
	var idx := 0
	var started := false
	while not f.eof_reached():
		var line := f.get_line().trim_suffix("\r")
		if line.begins_with(";"):
			_add_level(out, pack_name, author, board, idx)
			board = PackedStringArray()
			idx += 1
			started = true
			continue
		# keep space-only rows: a blank-looking line is a legal board row
		if started and line != "":
			board.append(line)
	_add_level(out, pack_name, author, board, idx)
	return out


static func _add_level(out: Array, pack_name: String, author: String, board: PackedStringArray, idx: int) -> void:
	if board.size() < 2:
		return
	var l := LevelData.create("%s %d" % [pack_name, idx], board, [], author)
	out.append(l)
