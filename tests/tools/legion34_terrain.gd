extends RefCounted
# Isolated movement-only projection of the production terrain speed rules.
# Real strategic regions, nearest enclosing region, no invented forest belts.
var regions:Array[BattleRegionDefinition]=[]

func _init() -> void:
	regions=(load("res://data/battles/final_decision.tres") as BattleDefinition).strategic_regions

func multiplier(position: Vector2, role: int) -> float:
	var closest:BattleRegionDefinition
	var distance:=INF
	for region in regions:
		var d:=position.distance_squared_to(region.position)
		if d<=region.radius*region.radius and d<distance:closest=region;distance=d
	if closest==null:return 1.0
	match closest.terrain_key:
		&"TERRAIN_OPEN":return 1.1 if role==2 else 1.0
		&"TERRAIN_RUINS":return 0.7 if role==2 else 1.0
		&"TERRAIN_FOREST":return 1.1 if role==0 else (0.8 if role==3 else 1.0)
		&"TERRAIN_BRIDGE":return 0.82
	return 1.0
