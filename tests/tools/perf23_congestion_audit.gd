extends RefCounted
# Observational, never writes world state. Sustained net progress, not event count.
var active: Dictionary = {}
var episodes: Array[Dictionary] = []
func sample(world: SimulationWorld) -> void:
	if world.current_tick % 10 != 0: return
	var seen: Dictionary = {}
	for unit: UnitState in world.units.values():
		if not unit.enabled: continue
		var formation := world.formations.get(unit.formation_id) as FormationState
		if formation == null or not unit.following_formation or not formation.is_moving or unit.attack_target_entity_id != 0 or unit.position.distance_to(unit.desired_position) <= 64: continue
		seen[unit.entity_id] = true
		var signature := str(formation.order_kind)+str(formation.order_destination)+str(unit.last_command_id)
		if active.has(unit.entity_id):
			var previous: Dictionary = active[unit.entity_id]
			if previous.signature != signature: _close(unit.entity_id,world.current_tick,"order_changed")
			elif unit.position.distance_to(previous.position)>=32: _close(unit.entity_id,world.current_tick,"progress_resumed")
		if not active.has(unit.entity_id):
			active[unit.entity_id]={"start":world.current_tick,"position":unit.position,"signature":signature,"formation":formation.formation_id,"card":String(unit.unit_card_id),"faction":unit.faction_id,"anchor_start":formation.anchor_position,"slot_distance":unit.position.distance_to(unit.desired_position)}
	for id in active.keys():
		if not seen.has(id):
			var unit := world.units.get(id) as UnitState
			_close(id,world.current_tick,"dead" if unit==null or not unit.enabled else "arrived_combat_or_stopped")
func _close(id: int,tick: int,reason: String) -> void:
	var item: Dictionary=active[id]
	if tick-item.start>=100:
		episodes.append({"unit":id,"faction":item.faction,"card":item.card,"formation":item.formation,"start_tick":item.start,"duration_seconds":(tick-item.start)/10.0,"end_reason":reason,"x":item.position.x,"y":item.position.y,"slot_distance":item.slot_distance})
	active.erase(id)
func finish(tick: int) -> Array[Dictionary]:
	for id in active.keys(): _close(id,tick,"match_ended")
	return episodes
