class_name GameScreen
extends Control
## Plays a LevelData: board + HUD + input + solver + replays.

const AUTOPLAY_STEP := 0.16

var host: Control
var level: LevelData
var context: Dictionary = {}
var state: GameState
var board: BoardView
var board_holder: Control

var hud_rules: Label
var hud_status: Label
var hud_keys: Label
var win_panel: WinPanel

var autoplay: PackedStringArray = []
var autoplay_i := 0        # cursor into autoplay (avoids per-step slice)
var autoplay_t := 0.0
var replay_mode := false
var _solver_used := false  # solver/hint consumed: no records or medals

var keys: Dictionary = {}  # action -> keycode (rebindable; arrows fixed)
var _assist := 2           # deadlock assist: 0 off,1 aviso,2 marcas,3 bloquear
var undos_used := 0
var restarts_used := 0
var hints_used := 0

var held_dir := Vector2i.ZERO
var repeat_t := 0.0
var _played_recorded := false   # plays de comunidad cuentan tras moverse
var z_hold := -1.0  # held-Z rewind timer
var _ap_speed := 1.0         # autoplay multiplier (settings)
var _repeat_rate := 0.11     # held-key repeat cadence (settings)
var _hud_moves := true
var _hud_timer := true
var _hud_par := true
var _best_moves := 0        # cached at level start / on win (no per-frame
var _best_time := 0.0       # progress.json parses)
var _status_sig := ""       # last-rendered status signature
const REPEAT_DELAY := 0.28


func _init(p_host: Control) -> void:
	host = p_host
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hbox)

	board_holder = Control.new()
	board_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(board_holder)
	board = BoardView.new()
	board_holder.add_child(board)
	board_holder.resized.connect(_center_board)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 300
	side.add_theme_constant_override("separation", 10)
	hbox.add_child(side)

	hud_rules = Widgets.label("", 15, Color(0.8, 0.8, 0.85))
	hud_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(hud_rules)
	side.add_child(Widgets.hsep())
	hud_status = Widgets.label("", 15)
	side.add_child(hud_status)
	side.add_child(Widgets.hsep())

	hud_keys = Widgets.label("", 12, UiTheme.dim())
	# la lista de atajos es larga — sin wrap el min-width del label
	# comía el espacio del tablero (side acababa a ~800px)
	hud_keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(hud_keys)

	var b_undo := Widgets.button("Deshacer")
	b_undo.pressed.connect(func(): _undo())
	side.add_child(b_undo)
	var b_redo := Widgets.button("Rehacer")
	b_redo.pressed.connect(func(): _redo())
	side.add_child(b_redo)
	var b_restart := Widgets.button("Reiniciar")
	b_restart.pressed.connect(func(): _restart())
	side.add_child(b_restart)
	var b_solve := Widgets.button("Resolver")
	b_solve.pressed.connect(func(): _solve())
	side.add_child(b_solve)
	var b_hint := Widgets.button("Pista")
	b_hint.pressed.connect(func(): _hint())
	side.add_child(b_hint)
	var b_replay := Widgets.button("Ver repetición")
	b_replay.pressed.connect(func(): _replay_saved())
	side.add_child(b_replay)
	var b_menu := Widgets.button("Menú (Esc)")
	b_menu.pressed.connect(func(): _exit())
	side.add_child(b_menu)

	# el panel es su propio componente: layout, scroll-clamp y
	# botones; aquí solo se conectan las señales a las acciones
	win_panel = WinPanel.new()
	win_panel.next_pressed.connect(_next_level)
	win_panel.replay_pressed.connect(_replay_saved)
	win_panel.share_pressed.connect(_share_solution)
	win_panel.menu_pressed.connect(_exit)
	add_child(win_panel)


func start(p_level: LevelData, p_context: Dictionary = {}) -> void:
	level = p_level
	context = p_context
	keys.clear()
	for a in ControlsScreen.DEFAULTS.keys():
		keys[a] = int(Storage.get_setting("key_" + a, ControlsScreen.DEFAULTS[a]))
	_assist = int(Storage.get_setting("deadlock_assist"))
	_ap_speed = float(Storage.get_setting("autoplay_speed"))
	_repeat_rate = float(Storage.get_setting("repeat_rate"))
	_hud_moves = bool(Storage.get_setting("show_moves"))
	_hud_timer = bool(Storage.get_setting("show_timer"))
	_hud_par = bool(Storage.get_setting("show_par"))
	var kn := func(a): return OS.get_keycode_string(
		keys.get(a, ControlsScreen.DEFAULTS[a]))
	hud_keys.text = ("Flechas mover (mantén) · %s deshacer"
		+ " (mantén = rebobinar) · %s rehacer · %s reiniciar"
		+ " · %s solución · %s pista · %s repetición"
		+ " · %s mejor ruta · Esc menú") % [
		kn.call("undo"), kn.call("redo"), kn.call("restart"),
		kn.call("solve"), kn.call("hint"), kn.call("replay"),
		kn.call("trail")]
	BoardView.reload_skin()
	board.modulate = Color(0.95, 0.8, 0.6) \
		if int(Storage.get_setting("board_skin")) == 2 else Color.WHITE
	undos_used = 0
	restarts_used = 0
	hints_used = 0
	state = null  # sin esto, un resume fallido dejaría el estado de
				# la partida anterior aplicado al nivel nuevo
	if context.get("resume", false):
		var saved = context.get("saved_state")
		if saved != null:
			state = GameState.deserialize_state(level, saved)
	if state == null:
		state = GameState.from_level_data(level)
	board.set_state(state)
	if state.fx_push.is_connected(_on_push_landed):
		state.fx_push.disconnect(_on_push_landed)
	state.fx_push.connect(_on_push_landed)
	_played_recorded = false  # record_play va en el primer movimiento
	board.hint_dir = Vector2i.ZERO
	_refresh_rules_hud()
	_center_board()
	win_panel.visible = false
	autoplay = []
	autoplay_i = 0
	_solver_used = false
	var auto: Variant = context.get("autoplay")
	if auto is PackedStringArray and not auto.is_empty():
		autoplay = auto
		_solver_used = true  # baked solution replay (editor "Ver solución")
	replay_mode = false
	_best_moves = Storage.best_moves(level)
	_best_time = Storage.best_time(level)
	_status_sig = ""


func _refresh_rules_hud() -> void:
	var lines := PackedStringArray()
	lines.append(level.title + Widgets.stars(level.difficulty))
	lines.append("")
	if level.hidden_rules and not state.solved:
		lines.append("• ??? — Regla desconocida. Descúbrela jugando.")
	else:
		var any := false
		var ids := {}
		for r in level.rules:
			var d := RuleRegistry.describe(r.get("id", ""))
			lines.append("• " + str(d.get("title", "")) + ": " + str(d.get("description", "")))
			ids[r.get("id", "")] = true
			any = true
		# portales/cintas existen como regla Y como tile — sin dedup el
		# HUD los explicaba dos veces
		if level.has_peekaboo():
			lines.append("• Paredes tímidas: las paredes ? solo son sólidas mientras las miras.")
			any = true
		if level.has_switches():
			lines.append("• Interruptores: pisar o cubrir una casilla ! activa/desactiva las reglas.")
			any = true
		if level.has_portals() and not ids.has("portal"):
			lines.append("• Portales: entra por una casilla o/O y sales por su pareja.")
			any = true
		if level.has_conveyors() and not ids.has("conveyor"):
			lines.append("• Cintas: > < ^ v arrastran lo que tengan encima cada turno.")
			any = true
		if level.has_doors():
			lines.append("• Llaves y puertas: coge k y abre K (solo el jugador puede pasar).")
			any = true
		if level.has_bombs():
			lines.append("• Bombas: una caja empujada contra x explota y desaparece con ella.")
			any = true
		if level.has_oneway():
			lines.append("• Sentido único: de una casilla 1-4 solo se sale en la dirección marcada.")
			any = true
		if level.has_rails():
			lines.append("• Raíles: una caja sobre = o : solo se mueve a lo largo del raíl.")
			any = true
		if level.has_colors():
			lines.append("• Colores: cada caja b/c/d solo sirve en su objetivo B/C/D.")
			any = true
		if not any:
			lines.append("Sokoban clásico.")
	hud_rules.text = "\n".join(lines)


func _center_board() -> void:
	if state == null:
		return
	var avail := board_holder.size - Vector2(40, 40)
	board.tile = minf(avail.x / state.width, avail.y / state.height)
	board.anchor = (board_holder.size - board.board_pixel_size()) / 2
	board.position = board.anchor
	board.queue_redraw()


func _ap_active() -> bool:
	return autoplay_i < autoplay.size()


func _is_move_key(kc: int) -> bool:
	return kc in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
		int(keys.get("left", KEY_A)), int(keys.get("right", KEY_D)),
		int(keys.get("up", KEY_W)), int(keys.get("down", KEY_S))]


## Editor playtest ("Probar"): solver and hints are off so authors can't
## clear the publish gate without beating their own level.
func _is_playtest() -> bool:
	return context.get("from_editor", false) \
		or str(context.get("playtest", "")) != ""


func _process(dt: float) -> void:
	if state == null:
		return
	state.tick(dt)
	_poll_held_dir(dt)
	# held-Z rewind: undoes continuously while Z is held down — but NOT
	# during autoplay/replay (it would corrupt the playback mid-flight)
	if not _ap_active() and Input.is_key_pressed(keys.get("undo", KEY_Z)):
		if z_hold >= 0.0:
			z_hold -= dt
			if z_hold <= 0.0:
				_undo()
				z_hold = 0.05
	elif z_hold >= 0.0:
		z_hold = -1.0
	if _ap_active():
		autoplay_t += dt
		if autoplay_t >= AUTOPLAY_STEP / maxf(0.25, _ap_speed):
			autoplay_t = 0.0
			var ch := autoplay[autoplay_i].to_lower()
			autoplay_i += 1
			if ch == "s":
				state.try_switch()
			else:
				state.try_move(GameState.DIRS[ch])
	_update_status()
	if _restart_armed_t > 0.0:
		_restart_armed_t -= dt
		if _restart_armed_t <= 0.0:
			_restart_armed = false
	if state.solved and not win_panel.visible and not _ap_active():
		_on_win()


func _poll_held_dir(dt: float) -> void:
	var d := Vector2i.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(keys.get("left", KEY_A)):
		d = Vector2i(-1, 0)
	elif Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(keys.get("right", KEY_D)):
		d = Vector2i(1, 0)
	elif Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(keys.get("up", KEY_W)):
		d = Vector2i(0, -1)
	elif Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(keys.get("down", KEY_S)):
		d = Vector2i(0, 1)
	if d == Vector2i.ZERO:
		held_dir = d
		return
	if d != held_dir:
		held_dir = d
		repeat_t = REPEAT_DELAY
		_move(d)
		return
	repeat_t -= dt
	if repeat_t <= 0.0:
		repeat_t = _repeat_rate
		_move(d)


func _update_status() -> void:
	# Only rebuild when a visible number actually changes; the Storage
	# reads (best marks) are cached at level start and refreshed on win.
	var sig := [state.move_log.size(), int(state.elapsed), state.turn,
		state.keys_held, state.rules_enabled, state.twins.size(),
		state.lost, replay_mode, _ap_active()]
	if str(sig) == _status_sig:
		return
	_status_sig = str(sig)
	var lines := PackedStringArray()
	var pushes := 0
	for ch in state.move_log:
		if ch != ch.to_lower():
			pushes += 1
	var st := ""
	if _hud_moves:
		st += "Movimientos: %d  ·  Empujes: %d" % [state.move_log.size(), pushes]
	if _hud_timer:
		st += "  ·  %02d:%02d" % [int(state.elapsed) / 60, int(state.elapsed) % 60]
	if _hud_par and level.par > 0:
		st += "  ·  Par: %d" % level.par
	if _hud_par:
		if _best_moves > 0:
			st += "  ·  Tu mejor: %d" % _best_moves
			if _best_time > 0.0:
				st += " (%02d:%02d)" % [int(_best_time) / 60, int(_best_time) % 60]
	if st != "":
		lines.append(st.strip_edges())
	if not state.switches.is_empty():
		lines.append("Reglas: %s" % ("ACTIVAS" if state.rules_enabled else "INACTIVAS"))
	if state.keys_held > 0 or not state.door_cells.is_empty():
		lines.append("Llaves: %d" % state.keys_held)
	if not state.twins.is_empty():
		lines.append("Gemelos: %d — %s para cambiar" % [state.twins.size(),
			OS.get_keycode_string(keys.get("switch", KEY_SPACE))])
	if state.rules_enabled:
		for rule in state.rules:
			for line in rule.hud_lines(state):
				lines.append(line)
	if replay_mode:
		lines.append("[repetición]")
	elif _ap_active():
		lines.append("[reproduciendo solución]")
	if state.lost:
		lines.append("☠ %s — deshaz (Z) o reinicia (R)" % state.lost_reason)
	Widgets.status(hud_status, "\n".join(lines))


func _unhandled_input(event: InputEvent) -> void:
	if state == null or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var e := event as InputEventKey
	# Any key during a replay/autoplay (except Esc) stops it so you can
	# continue playing from that point — "play from here".
	if replay_mode and e.keycode != KEY_ESCAPE:
		replay_mode = false
		autoplay = PackedStringArray()
		autoplay_i = 0
		Widgets.status(hud_status, "Repetición pausada — sigue jugando desde aquí.")
		return
	var kc: int = e.keycode
	# During solver autoplay only Esc exits and a move key pauses it —
	# everything else (undo, switch, hints…) would corrupt the playback.
	if _ap_active():
		if kc == KEY_ESCAPE:
			_exit()
		elif _is_move_key(kc):
			autoplay_i = autoplay.size()
			autoplay_t = 0.0
			Widgets.status(hud_status, "Solución pausada — sigue jugando desde aquí.")
		elif kc == keys.get("restart", KEY_R):
			_restart()  # reiniciar también detiene el autoplay
		return
	if kc == KEY_ESCAPE:
		_exit()
	elif kc == keys.get("undo", KEY_Z):
		_undo()
		z_hold = 0.4
	elif kc == keys.get("redo", KEY_Y):
		_redo()
	elif kc == keys.get("restart", KEY_R):
		_restart()
	elif kc == keys.get("trail", KEY_T):
		_toggle_trail()
	elif kc == keys.get("solve", KEY_F1):
		_solve()
	elif kc == keys.get("hint", KEY_H):
		_hint()
	elif kc == keys.get("replay", KEY_V):
		_replay_saved()
	elif kc == keys.get("switch", KEY_SPACE) and not state.twins.is_empty():
		var had_sw := state.rules_enabled
		if state.try_switch():
			_sfx("move")
			_input_gen += 1
			if state.rules_enabled != had_sw:
				_sfx("switch")  # el relevo también puede pisar un interruptor


## Deadlock alarm (YASC-style): fires after every landed push; warns
## only when the box ends on a known-dead cell (classic boards only).
func _on_push_landed(idx: int, _d: Vector2i) -> void:
	# idx can be -1 when a rule consumed the pushed box (bomb, pit…).
	# _dead exists from assist ≥1; show_dead only controls the overlay.
	if idx >= 0 and idx < state.boxes.size() \
			and board.is_dead_cell(state.boxes[idx]) \
			and not state.goals.has(state.boxes[idx]):
		_sfx("deny")


func _undo() -> void:
	if _ap_active():
		return  # deshacer a mitad de reproducción corrompería el playback
	if state and state.undo():
		_sfx("undo")
		undos_used += 1
		Storage.bump_total("undos")
		_input_gen += 1  # invalida callbacks async del solver en vuelo
		board.hint_dir = Vector2i.ZERO
		win_panel.visible = false  # keep playing after undoing past the win


func _redo() -> void:
	if _ap_active():
		return
	if state and state.redo():
		_sfx("undo")
		_input_gen += 1
		board.hint_dir = Vector2i.ZERO
		win_panel.visible = false


## T: overlay of your saved best replay as faint breadcrumbs.
func _toggle_trail() -> void:
	if not board.trail_cells.is_empty():
		board.trail_cells.clear()
		board.queue_redraw()
		return
	var rep := Storage.get_replay_moves(level)
	if rep.is_empty():
		Widgets.status(hud_status, "Sin repetición guardada para este nivel.")
		return
	var c := GameState.from_level_data(level)
	for ch in rep:
		var ok2 := c.try_switch() if ch.to_lower() == "s" \
			else c.try_move(GameState.DIRS[ch.to_lower()])
		if ok2:
			c.tick(0.3)
			board.trail_cells[c.player] = true
	if board.trail_cells.is_empty():
		Widgets.status(hud_status, "La repetición guardada ya no aplica.")
	else:
		board.queue_redraw()


func _sfx(name: String) -> void:
	if host.has_method("play_sfx"):
		host.play_sfx(name)


func _move(d: Vector2i) -> void:
	if state.solved or _ap_active():
		return
	if state.rules_enabled:
		for rule in state.rules:
			d = rule.transform_input(state, d)
	var had_switch := state.rules_enabled
	var turns_before := state.turn
	# Assist level 3: refuse pushes that would land a box on a known
	# dead square (classic boards only).
	if _assist >= 3 and not board.dead_cells().is_empty():
		var bi := state.box_at(state.player + d)
		if bi != -1:
			var bdest := state.box_step_dest(state.boxes[bi], d)
			if board.is_dead_cell(bdest) and not state.goals.has(bdest):
				_sfx("deny")
				Widgets.status(hud_status, "Empuje bloqueado: esa casilla es un callejón sin salida.")
				return
	if state.try_move(d):
		board.hint_dir = Vector2i.ZERO
		_input_gen += 1
		# "partida" = haber jugado, no solo abierto la ficha
		if not _played_recorded and context.get("community", "") != "":
			_played_recorded = true
			CommunityService.record_play(str(context["community"]))
		var last := state.move_log[state.move_log.size() - 1]
		_sfx("push" if last == last.to_upper() else "move")
		if state.rules_enabled != had_switch:
			_sfx("switch")
	else:
		if state.turn == turns_before:
			_sfx("deny")
			board.deny_fx()


func _exit() -> void:
	# Save mid-game so the menu can offer "Continuar" later — but NOT an
	# assisted run: resuming it would launder a solver win as legit.
	var mid_game: bool = state != null and not state.solved \
		and not state.move_log.is_empty() \
		and not context.get("from_editor", false)
	if mid_game and (_solver_used or replay_mode or _ap_active()):
		if host.has_method("toast"):
			host.toast("Partida asistida por el solucionador — no se guarda")
	elif mid_game:
		Storage.save_in_progress(level, state)
		if host.has_method("toast"):
			host.toast("Progreso guardado — continúa desde el menú")
	if context.get("from_editor", false):
		host.show_editor(level)
	elif context.get("from_map", false):
		host.show_map()
	else:
		host.show_menu()


var _restart_armed := false
var _restart_armed_t := 0.0


func _restart() -> void:
	# optional two-step restart (accessibility setting): first press
	# arms it, second within 1.5s confirms
	if bool(Storage.get_setting("confirm_restart")) \
			and not _restart_armed \
			and not state.move_log.is_empty() and not state.solved:
		_restart_armed = true
		_restart_armed_t = 1.5
		Widgets.status(hud_status, "Reiniciar de nuevo para confirmar.")
		return
	_restart_armed = false
	state.restart()
	restarts_used += 1
	Storage.bump_total("restarts")
	autoplay = []
	autoplay_i = 0
	replay_mode = false
	win_panel.visible = false
	# un reinicio manual limpia la marca de asistencia y la pista —
	# si no, toda victoria posterior quedaría etiquetada "asistida"
	_solver_used = false
	board.hint_dir = Vector2i.ZERO
	z_hold = -1.0  # -1 = rebobinado desarmado
	held_dir = Vector2i.ZERO
	repeat_t = 0.0
	_input_gen += 1  # descarta resultados async del solver en vuelo


var _solving := false
var _input_gen := 0  # sube con cada acción que cambia el estado


func _solve() -> void:
	if _is_playtest():
		Widgets.status(hud_status, "Solucionador desactivado en modo prueba.")
		return
	if state.solved or _solving or _ap_active() or replay_mode:
		return
	_solving = true
	Widgets.status(hud_status, "Buscando solución…")
	var gen := _input_gen  # si el jugador mueve/deshace/reinicia, el
	# escalate: un "límite de estados" reintenta con más presupuesto
	# antes de rendirse — los niveles mutantes densos lo necesitan
	SokobanSolver.solve_state_async(state, func(res: Dictionary):  # resultado es obsoleto
		_solving = false
		if state == null or gen != _input_gen:
			return
		if res.get("ok", false):
			autoplay = res["moves"]
			autoplay_i = 0
			replay_mode = false
			_solver_used = true
		else:
			Widgets.status(hud_status, "El solucionador no encuentra solución (%s)." % res.get("reason", ""))
		, SokobanSolver.MAX_STATES, true)


func _hint() -> void:
	if _is_playtest():
		Widgets.status(hud_status, "Solucionador desactivado en modo prueba.")
		return
	if state.solved or _solving or _ap_active() or replay_mode:
		return
	_solving = true
	hints_used += 1
	Storage.bump_total("hints")
	Widgets.status(hud_status, "Buscando pista…")
	var gen := _input_gen
	SokobanSolver.solve_state_async(state, func(res: Dictionary):
		_solving = false
		if state == null or gen != _input_gen:
			return
		if res.get("ok", false) and not res["moves"].is_empty():
			_solver_used = true
			if res["moves"][0].to_lower() == "s":
				Widgets.status(hud_status, "Pista: cambia de empujador (Espacio).")
			else:
				board.hint_dir = GameState.DIRS[res["moves"][0].to_lower()]
				board.queue_redraw()
				Widgets.status(hud_status, "Pista: prueba esa dirección.")
		else:
			Widgets.status(hud_status, "Sin pista (%s)." % res.get("reason", ""))
		, SokobanSolver.MAX_STATES, true)


func _replay_saved() -> void:
	if _ap_active() or _solving:
		return  # una replay en vuelo o un solve pendiente se pisarían
	var moves := Storage.get_replay_moves(level)
	if moves.is_empty():
		Widgets.status(hud_status, "Sin repetición guardada para este nivel.")
		return
	state.restart()
	autoplay = moves
	autoplay_i = 0
	replay_mode = true
	win_panel.visible = false
	_input_gen += 1


func _on_win() -> void:
	_sfx("win")
	board.win_fx()
	if not bool(Storage.get_setting("reduce_motion")):
		_confetti()
	# Solver-assisted wins (autoplay, hints, baked solutions) and replayed
	# ones don't earn records, medals or playtest clearance.
	var assisted := _solver_used or replay_mode
	# una victoria asistida tampoco completa el reto diario ni cuenta
	# como clear en el feed de comunidad
	if context.get("daily", false) and not assisted:
		Storage.mark_daily()
	if context.get("playtest", "") != "" and not assisted:
		Storage.mark_playtested(str(context["playtest"]))
	if context.get("community", "") != "" and not assisted:
		CommunityService.record_clear(str(context["community"]))
	var moves := state.move_log.size()
	var pushes := 0
	for ch in state.move_log:
		if ch != ch.to_lower():
			pushes += 1
	if not assisted:
		var rw := Storage.record_win(level, state.move_log, state.elapsed)
		if rw.get("new_best") and int(rw.get("prev_moves", 0)) > 0 \
				and host.has_method("toast"):
			host.toast("¡Nuevo récord! (antes %d mov.)" % int(rw["prev_moves"]))
		Storage.bump_total("wins")
		Storage.bump_total("moves", moves)
		Storage.bump_total("pushes", pushes)
		_best_moves = Storage.best_moves(level)
		_best_time = Storage.best_time(level)
	# only drop the in-progress save if it's THIS level's
	var ip = Storage.get_in_progress()
	if ip != null and ip["level"].to_code() == level.to_code():
		Storage.clear_in_progress()
	_status_sig = ""
	_refresh_rules_hud()
	_win_refresh(moves, pushes, assisted)
	win_panel.show_panel(get_viewport_rect().size.y)
	# Levels without a baked par (generated/editor/community): compute it
	# off-thread — solving on the main thread would freeze the win moment.
	if level.par <= 0:
		var lvl := level
		SokobanSolver.solve_async(lvl, func(res: Dictionary):
			if level != lvl or state == null or not state.solved:
				return
			if res.get("ok", false):
				lvl.par = res["moves"].size()
				_win_refresh(moves, pushes, assisted))


func _win_refresh(moves: int, pushes: int, assisted: bool = false) -> void:
	win_panel.set_summary(WinStats.summary(level.par, moves, pushes,
		state.elapsed, undos_used, restarts_used, assisted))


func _share_solution() -> void:
	var code := level.to_code()
	DisplayServer.clipboard_set(code + " · " + "".join(state.move_log))


func _confetti() -> void:
	var p := CPUParticles2D.new()
	p.position = board.position + board.board_pixel_size() * Vector2(0.5, 0.25)
	p.amount = 90
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 55
	p.initial_velocity_min = 200
	p.initial_velocity_max = 400
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var grad := Gradient.new()
	grad.add_point(0.0, UiTheme.accent())
	grad.add_point(0.5, Color(0.4, 0.9, 0.5))
	grad.add_point(1.0, UiTheme.info())
	p.color_ramp = grad
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _next_level() -> void:
	# match by content, not title — a custom level named like a
	# campaign one must not hijack the campaign flow
	var camp := Campaign.levels()
	var code := level.content_code()
	for i in camp.size():
		if camp[i].content_code() == code and i + 1 < camp.size():
			start(camp[i + 1])
			return
	host.show_level_select()
