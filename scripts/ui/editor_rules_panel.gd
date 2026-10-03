class_name EditorRulesPanel
extends RefCounted
## Panel de reglas del editor de niveles: lista con parámetros,
## refresco y borrado. Posee `entries` (fuente de verdad de las
## reglas declaradas) y pinta dentro del VBoxContainer del editor.
##
## `on_changed` se dispara al añadir/quitar/limpiar reglas — el
## editor lo usa para invalidar la solución verificada (cambiar las
## reglas deja el botón «Ver solución» reproduciendo otro nivel).

var box: VBoxContainer
var entries: Array                 # [{id, controls:{key->{spec,value}}}]
var on_changed := Callable()


func _init(p_box: VBoxContainer, p_entries: Array,
		p_on_changed := Callable()) -> void:
	box = p_box
	entries = p_entries
	on_changed = p_on_changed


func add_rule(rule_id: String, params: Dictionary = {}) -> void:
	var entry := {"id": rule_id, "controls": {}}
	for spec in RuleRegistry.param_schema(rule_id):
		entry["controls"][spec["key"]] = {"spec": spec,
			"value": params.get(spec["key"], spec.get("default"))}
	entries.append(entry)
	refresh()
	_changed()


func remove_rule(idx: int) -> void:
	entries.remove_at(idx)
	refresh()
	_changed()


func clear() -> void:
	entries.clear()
	refresh()
	_changed()


func _changed() -> void:
	if on_changed.is_valid():
		on_changed.call()


## [{id, params}] tal como lo consume LevelData.create.
func to_rules() -> Array:
	var rules := []
	for e in entries:
		var params := {}
		for key in e["controls"].keys():
			params[key] = e["controls"][key]["value"]
		rules.append({"id": e["id"], "params": params})
	return rules


func refresh() -> void:
	if box == null:
		return
	for c in box.get_children():
		c.queue_free()
	for i in entries.size():
		var e: Dictionary = entries[i]
		var d := RuleRegistry.describe(e["id"])
		var card := PanelContainer.new()
		var v := VBoxContainer.new()
		card.add_child(v)
		var head := HBoxContainer.new()
		head.add_child(Widgets.label(str(d["title"]), 15))
		var del := Button.new()
		del.text = "x"
		del.pressed.connect(func(): remove_rule(i))
		head.add_child(del)
		v.add_child(head)
		v.add_child(Widgets.label(str(d["description"]), 11, UiTheme.dim()))
		for key in e["controls"].keys():
			var c: Dictionary = e["controls"][key]
			var spec: Dictionary = c["spec"]
			var row := HBoxContainer.new()
			row.add_child(Widgets.label(str(spec["label"]), 12))
			if spec["type"] == "bool":
				var cb := CheckBox.new()
				cb.button_pressed = bool(c["value"])
				cb.toggled.connect(func(on): c["value"] = on)
				row.add_child(cb)
			elif spec["type"] == "select":
				var ob := OptionButton.new()
				var vals: Array = spec.get("values", [])
				var cur := 0
				for oi in spec["options"].size():
					ob.add_item(str(spec["options"][oi]))
					var v2: Variant = vals[oi] if oi < vals.size() else oi
					if v2 == c["value"]:
						cur = oi
				ob.selected = cur
				ob.item_selected.connect(func(oi: int):
					c["value"] = vals[oi] if oi < vals.size() else oi)
				row.add_child(ob)
			else:
				var sb := SpinBox.new()
				sb.min_value = float(spec.get("min", 0))
				sb.max_value = float(spec.get("max", 100))
				sb.step = 0.5 if spec["type"] == "float" else 1.0
				sb.value = float(c["value"])
				sb.value_changed.connect(func(val):
					c["value"] = int(val) if spec["type"] == "int" else val)
				row.add_child(sb)
			v.add_child(row)
		box.add_child(card)
