class_name TileSpec
extends RefCounted
## Única fuente de verdad sobre los símbolos del tablero.
##
## Antes de esta tabla, el significado de cada carácter vivía duplicado
## en ~10 sitios (parser del motor, validate, conectividad, editor,
## solver, thumbnails…): cada nuevo compuesto exigía tocarlos todos y
## cualquier olvido era un bug. Ahora un carácter se describe UNA vez
## aquí y el resto consulta flags.
##
## Flags por spec:
##   floor      — transitable a efectos de diseño (conectividad en
##                validate). Nota: '?','K','x','W' cuentan como
##                transitables aunque bloqueen en juego.
##   wall       — muro sólido ('#')
##   peekaboo   — muro que se oculta ('?')
##   player     — el jugador empieza aquí ('@','+')
##   box        — hay una caja ('$','*','&','%','q','n','bcd','aeijlm')
##   goal       — hay una meta ('.','BCD','+','*','%','aeijlm')
##   bcolor / gcolor — índice de color 1..3 (0 = neutro)
##   mimic      — caja imitadora ('&','%')
##   roll       — caja que rueda ('q')
##   heavy      — caja pesada ('n')
##   field      — nombre del campo de GameState que poblar (parser)
##   portal     — clase de portal ('o'/'O')
##   conveyor / rail / one_way — Vector2i dirección
##   filter     — índice de color que atraviesa (1..3)

static var SPECS := _build()


static func _build() -> Dictionary:
	var t := {}
	var add := func(ch: String, spec: Dictionary) -> void:
		spec["floor"] = spec.get("floor", true)
		t[ch] = spec
	add.call(" ", {})
	add.call("-", {})
	add.call("_", {})
	# estructuras
	add.call("#", {"wall": true, "floor": false})
	add.call("?", {"peekaboo": true})
	add.call("W", {"weak": true})
	add.call("w", {"swap": true})
	# jugador / gemelos
	add.call("@", {"player": true})
	add.call("+", {"player": true, "goal": true})
	add.call("p", {"twin": true})
	# metas
	add.call(".", {"goal": true})
	add.call("B", {"goal": true, "gcolor": 1})
	add.call("C", {"goal": true, "gcolor": 2})
	add.call("D", {"goal": true, "gcolor": 3})
	# cajas
	add.call("$", {"box": true})
	add.call("*", {"box": true, "goal": true})
	add.call("&", {"box": true, "mimic": true})
	add.call("%", {"box": true, "goal": true, "mimic": true})
	add.call("q", {"box": true, "roll": true})
	add.call("n", {"box": true, "heavy": true})
	add.call("b", {"box": true, "bcolor": 1})
	add.call("c", {"box": true, "bcolor": 2})
	add.call("d", {"box": true, "bcolor": 3})
	# compuestos: caja de color sobre meta (a/e/i = su meta; j/l/m = neutra)
	add.call("a", {"box": true, "goal": true, "bcolor": 1, "gcolor": 1})
	add.call("e", {"box": true, "goal": true, "bcolor": 2, "gcolor": 2})
	add.call("i", {"box": true, "goal": true, "bcolor": 3, "gcolor": 3})
	add.call("j", {"box": true, "goal": true, "bcolor": 1})
	add.call("l", {"box": true, "goal": true, "bcolor": 2})
	add.call("m", {"box": true, "goal": true, "bcolor": 3})
	# terreno interactivo
	add.call("!", {"switch": true})
	add.call("o", {"portal": "o"})
	add.call("O", {"portal": "O"})
	add.call("k", {"key": true})
	add.call("K", {"door": true})
	add.call("x", {"bomb": true})
	add.call("h", {"hole": true})
	add.call("f", {"fragile": true})
	add.call("u", {"pit": true})
	add.call("z", {"pull": true})
	add.call("=", {"rail": Vector2i(1, 0)})
	add.call(":", {"rail": Vector2i(0, 1)})
	add.call(">", {"conveyor": Vector2i(1, 0)})
	add.call("<", {"conveyor": Vector2i(-1, 0)})
	add.call("^", {"conveyor": Vector2i(0, -1)})
	add.call("v", {"conveyor": Vector2i(0, 1)})
	add.call("1", {"one_way": Vector2i(1, 0)})
	add.call("2", {"one_way": Vector2i(0, 1)})
	add.call("3", {"one_way": Vector2i(-1, 0)})
	add.call("4", {"one_way": Vector2i(0, -1)})
	# filtros de color: bloquean al jugador; solo pasan sus cajas
	add.call("E", {"filter": 1, "floor": false})
	add.call("G", {"filter": 2, "floor": false})
	add.call("H", {"filter": 3, "floor": false})
	return t


static func spec(ch: String) -> Dictionary:
	return SPECS.get(ch, {})


static func is_known(ch: String) -> bool:
	return SPECS.has(ch)


static func is_box(ch: String) -> bool:
	return SPECS.get(ch, {}).get("box", false)


static func is_goal(ch: String) -> bool:
	return SPECS.get(ch, {}).get("goal", false)


static func is_player(ch: String) -> bool:
	return SPECS.get(ch, {}).get("player", false)


## Caja "satisfecha" = caja ya sobre una meta compatible (no debe nada).
static func is_satisfied_box(ch: String) -> bool:
	var sp := spec(ch)
	return sp.get("box", false) and sp.get("goal", false) \
		and (sp.get("bcolor", 0) == 0 or sp.get("bcolor", 0) == sp.get("gcolor", 0))


static func blocks_player(ch: String) -> bool:
	return not SPECS.get(ch, {}).get("floor", true)


static func box_color(ch: String) -> int:
	return int(SPECS.get(ch, {}).get("bcolor", 0))


static func goal_color(ch: String) -> int:
	return int(SPECS.get(ch, {}).get("gcolor", 0))


## Todos los símbolos válidos en un tablero.
static func valid_chars() -> String:
	return "".join(SPECS.keys())


# ------------------------------------------------------- transformadas

const _ROT := {">": "v", "v": "<", "<": "^", "^": ">",
	"=": ":", ":": "=", "1": "2", "2": "3", "3": "4", "4": "1"}
const _FLIP_H := {"<": ">", ">": "<", "1": "3", "3": "1"}
const _FLIP_V := {"^": "v", "v": "^", "2": "4", "4": "2"}

static func rot90(ch: String) -> String:
	return _ROT.get(ch, ch)


static func flip_h(ch: String) -> String:
	return _FLIP_H.get(ch, ch)


static func flip_v(ch: String) -> String:
	return _FLIP_V.get(ch, ch)


# ------------------------------------------------ compuestos (editor)

## Meta que hay DEBAJO de un compuesto (o el propio char si no lo es).
const _UNDER := {"*": ".", "+": ".", "%": ".",
	"a": "B", "e": "C", "i": "D", "j": ".", "l": ".", "m": "."}

## Sellar un ocupante sobre una meta compone en vez de sobrescribir:
## $→* &→% @→+ ; b/c/d sobre su meta → a/e/i, sobre neutra → j/l/m.
## Un color cruzado (b sobre C) o caja sobre terreno pisable no
## expresable (cinta, portal, interruptor…) devuelve "" → el editor
## lo guarda como overlay de ocupante (LevelData.over).
static func compose(tool: String, cur: String) -> String:
	var under: String = _UNDER.get(cur, cur)
	match tool:
		"$": if under == ".": return "*"
		"&": if under == ".": return "%"
		"@": if under == ".": return "+"
		"b": if under == ".": return "j"
		"c": if under == ".": return "l"
		"d": if under == ".": return "m"
	if tool == "b" and under == "B": return "a"
	if tool == "c" and under == "C": return "e"
	if tool == "d" and under == "D": return "i"
	if _is_box_tool(tool):
		var sp := spec(under)
		# suelo sin ocupante y sin componible → overlay
		if sp.get("floor", true) and not sp.get("box", false) \
				and not sp.get("player", false):
			return ""
	return tool


static func _is_box_tool(t: String) -> bool:
	return t in ["$", "&", "q", "n", "b", "c", "d"]


## Spec de caja para un overlay, según la herramienta de la paleta.
static func box_spec(t: String) -> Dictionary:
	return {
		"c": {"b": 1, "c": 2, "d": 3}.get(t, 0),
		"m": t == "&",
		"r": t == "q",
		"h": t == "n",
	}


## Borrar un compuesto retira solo el ocupante y conserva la meta
## ("" = la celda queda vacía de verdad).
static func strip_top(cur: String) -> String:
	return _UNDER.get(cur, "")
