class_name IronRule
extends SokobanRule
## Regla férrea (estilo Void Stranger): no hay deshacer. Cada empujón
## es definitivo — solo queda reiniciar.


func _init(p_params: Dictionary = {}) -> void:
	super("iron", p_params)
	title = "Regla férrea"
	description = "No puedes deshacer jugadas. Piensa antes de empujar."


func hud_lines(_state) -> PackedStringArray:
	return PackedStringArray(["Regla férrea: sin deshacer"])


static func describe() -> Dictionary:
	return {
		"title": "Regla férrea",
		"description": "No puedes deshacer jugadas. Piensa antes de empujar.",
	}
