class_name RuleRegistry
extends RefCounted
## Registry of available absurd rules. Peekaboo walls ("paredes que
## aparecen cuando las miras") are a tile type ("?") handled natively
## by GameState, so they don't need a rule entry.

static var RULE_SCRIPTS := {
	"ice": SlideRule,
	"rotate": RotateRule,
	"mimic": MimicRule,
	"push_limit": PushLimitRule,
	"ghost": GhostRule,
	"swap": SwapRule,
	"two_players": TwoPlayersRule,
	"pull": PullRule,
	"gravity": GravityRule,
	"torus": TorusRule,
	"magnet": MagnetRule,
	"chain": ChainRule,
	"wind": WindRule,
	"spin": SpinRule,
	"portal": PortalRule,
	"conveyor": ConveyorRule,
	"invert": InvertRule,
	"move_limit": MoveLimitRule,
	"bond": BondRule,
	"blob": BlobRule,
	"quota": QuotaRule,
	"iron": IronRule,
	"quake": QuakeRule,
	"mitosis": MitosisRule,
	"drunk": DrunkRule,
	"spring": SpringRule,
	"musical": MusicalRule,
	"life": LifeRule,
	"repel": RepelRule,
	"link": LinkRule,
	"mirror": MirrorRule,
}


static func create(rule_id: String, params: Dictionary = {}) -> SokobanRule:
	if not RULE_SCRIPTS.has(rule_id):
		push_warning("Regla desconocida: " + rule_id)
		return null
	return RULE_SCRIPTS[rule_id].new(params)


static func all_ids() -> PackedStringArray:
	return PackedStringArray(RULE_SCRIPTS.keys())


static func describe(rule_id: String) -> Dictionary:
	if RULE_SCRIPTS.has(rule_id):
		return RULE_SCRIPTS[rule_id].describe()
	return {"title": rule_id, "description": ""}


static func param_schema(rule_id: String) -> Array:
	if RULE_SCRIPTS.has(rule_id):
		return RULE_SCRIPTS[rule_id].param_schema()
	return []
