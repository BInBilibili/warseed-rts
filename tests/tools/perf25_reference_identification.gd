extends RefCounted
const IDENTIFICATION_TICKS := 10
const IDENTIFICATION_LIFETIME := 15
var observation_started: Dictionary = {}
var passive_observation_started: Dictionary = {}
func observation_range(card: UnitCardState, tick: int) -> float:
	var ability := card.definition.tactical_ability
	if ability != null and ability.kind == TacticalAbilityDefinition.Kind.OBSERVE and card.tactical_command != null and tick >= card.tactical_complete_tick and tick < card.tactical_until_tick:
		return ability.range
	return 0.0


func update_identification(world: SimulationWorld, knowledge: FactionKnowledge) -> void:
	var visible_ids: Array[int] = []
	visible_ids.assign(knowledge.visible_hostile_unit_ids)
	for building_id in knowledge.visible_hostile_building_ids:
		visible_ids.append(building_id)
	for entity_id in knowledge.identification_until_by_entity.keys():
		if int(knowledge.identification_until_by_entity[entity_id]) <= world.current_tick or not visible_ids.has(int(entity_id)):
			knowledge.identification_until_by_entity.erase(entity_id)
	if world.battle_definition != null and world.battle_definition.growth_mode:
		var passive: Dictionary = passive_observation_started.get(knowledge.faction_id, {})
		for target in passive.keys():
			if not visible_ids.has(int(target)): passive.erase(target)
		for target in visible_ids:
			if not passive.has(target): passive[target] = world.current_tick
			if world.current_tick - int(passive[target]) >= IDENTIFICATION_TICKS:
				knowledge.identification_until_by_entity[target] = world.current_tick + IDENTIFICATION_LIFETIME
		passive_observation_started[knowledge.faction_id] = passive
	var ids := world.unit_cards.keys()
	ids.sort()
	for id in ids:
		var card := world.unit_cards[id] as UnitCardState
		var sight := observation_range(card, world.current_tick)
		if card.faction_id != knowledge.faction_id or sight <= 0.0:
			continue
		var started: Dictionary = observation_started.get(id, {})
		var center := UnitCardSnapshot.new(card, world.units).center_position
		var tracked: Array[int] = []
		for entity_id in visible_ids:
			var contact := knowledge.hostile_contacts.get(entity_id) as KnowledgeContact
			if contact == null or not contact.enabled or center.distance_to(contact.position) > sight:
				continue
			tracked.append(entity_id)
			if not started.has(entity_id):
				started[entity_id] = world.current_tick
			if world.current_tick - int(started[entity_id]) >= IDENTIFICATION_TICKS:
				if not knowledge.identification_until_by_entity.has(entity_id):
					world.events.append(SimulationEvent.new(world.current_tick, SimulationEvent.Kind.TACTICAL_IDENTIFIED, entity_id, "faction=%d;card=%s;source=optical;reason=TACTICAL_IDENTIFIED" % [card.faction_id, id]))
				knowledge.identification_until_by_entity[entity_id] = world.current_tick + IDENTIFICATION_LIFETIME
		for entity_id in started.keys():
			if not tracked.has(int(entity_id)):
				started.erase(entity_id)
		observation_started[id] = started
