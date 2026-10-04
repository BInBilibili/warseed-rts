class_name LegionBatchPlanner
extends RefCounted

const HERO_SLOT := 60
const MAX_BATCH := 12
const SPACING := 48.0
const ENVELOPE := 64.0
const CLEAR_GAP := 96.0
enum Availability { AVAILABLE, ABSENT, REJOINING, MANUAL, RETURNING }

class Member extends RefCounted:
	var identity := -1
	var entity_id := 0
	var role := -1
	var availability: Availability = Availability.ABSENT
	var batch := -1
	var ordinal := -1
	var offset := Vector2.ZERO
	func duplicate_value() -> Member:
		var copy := Member.new()
		copy.identity = identity; copy.entity_id = entity_id; copy.role = role
		copy.availability = availability; copy.batch = batch; copy.ordinal = ordinal; copy.offset = offset
		return copy

class Batch extends RefCounted:
	var identities := PackedInt32Array()
	var depth_start := 0.0
	var depth := 0.0
	var available := 0
	var escorts := 0
	var artillery := 0
	var has_hero := false
	func duplicate_value() -> Batch:
		var copy := Batch.new()
		copy.identities = identities.duplicate(); copy.depth_start = depth_start; copy.depth = depth
		copy.available = available; copy.escorts = escorts; copy.artillery = artillery; copy.has_hero = has_hero
		return copy

class Plan extends RefCounted:
	var commander_id: StringName
	var profile_id: StringName
	var faction_id := 0
	var epoch := 0
	var unlocked := 0
	var valid := true
	var reason: StringName = &"READY"
	var advance_ready := false
	var total_available := 0
	var pending_identities := PackedInt32Array()
	var members: Array[Member] = []
	var batches: Array[Batch] = []
	func duplicate_value() -> Plan:
		var copy := Plan.new()
		copy.commander_id = commander_id; copy.profile_id = profile_id; copy.faction_id = faction_id; copy.epoch = epoch
		copy.unlocked = unlocked
		copy.valid = valid; copy.reason = reason; copy.advance_ready = advance_ready; copy.total_available = total_available
		copy.pending_identities = pending_identities.duplicate()
		for member in members: copy.members.append(member.duplicate_value())
		for batch in batches: copy.batches.append(batch.duplicate_value())
		return copy

static func _fail(plan: Plan, reason: StringName) -> Plan:
	plan.valid = false; plan.advance_ready = false; plan.reason = reason
	return plan

static func _available(unit: UnitSnapshot, cards: Array[StringName], hero: bool) -> Availability:
	if unit == null or not unit.enabled: return Availability.ABSENT
	if unit.legion_returning: return Availability.RETURNING
	if unit.control_state != UnitState.ControlState.AGENT_ASSIGNED or (not hero and not cards.has(unit.unit_card_id)): return Availability.MANUAL
	if unit.rejoin_pending: return Availability.REJOINING
	return Availability.AVAILABLE

static func plan(template: LegionTemplate, commander: CommanderSnapshot, own: Array[UnitSnapshot], automatic_cards: Array[StringName], previous: Plan = null, safe_rebuild: bool = false) -> Plan:
	var result := previous.duplicate_value() if previous != null else Plan.new()
	if template == null or commander == null or not template.validation_errors().is_empty(): return _fail(result,&"INVALID_TEMPLATE")
	if template.profile_id != commander.profile_id or commander.growth_slot_entities.size() != 60 or commander.growth_unlocked_slots < 12 or commander.growth_unlocked_slots > 60: return _fail(result,&"INVALID_ROSTER")
	if previous != null and (previous.commander_id != commander.definition_id or previous.profile_id != commander.profile_id or previous.faction_id != commander.faction_id or previous.unlocked > commander.growth_unlocked_slots or not previous.valid): return _fail(result,&"STALE_PLAN")
	var views: Dictionary[int,UnitSnapshot] = {}
	for unit in own:
		if unit == null or unit.faction_id != commander.faction_id or views.has(unit.entity_id): return _fail(result,&"INVALID_OWN_VIEW")
		views[unit.entity_id] = unit
	var entities: Array[int] = []
	for index in range(commander.growth_unlocked_slots):
		var entity_id := commander.growth_slot_entities[index]
		if entity_id > 0:
			if entities.has(entity_id) or entity_id == commander.hero_entity_id: return _fail(result,&"DUPLICATE_IDENTITY")
			entities.append(entity_id)
	result.commander_id = commander.definition_id; result.profile_id = commander.profile_id; result.faction_id = commander.faction_id
	result.unlocked = commander.growth_unlocked_slots
	result.members.clear(); result.pending_identities.clear(); result.total_available = 0; result.valid = true
	var roles := template.slot_roles()
	var unit_roles := [UnitState.TacticalRole.SCOUT,UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR,UnitState.TacticalRole.FIREPOWER]
	for identity in range(61):
		var member := Member.new()
		member.identity = identity
		member.role = roles[identity] if identity < HERO_SLOT else 4
		member.entity_id = commander.growth_slot_entities[identity] if identity < commander.growth_unlocked_slots else 0
		if identity == HERO_SLOT: member.entity_id = commander.hero_entity_id
		var unit: UnitSnapshot = views.get(member.entity_id)
		if unit != null and identity < HERO_SLOT and not commander.subordinate_unit_card_ids.has(unit.unit_card_id): return _fail(result,&"FOREIGN_CARD")
		if unit != null and identity < HERO_SLOT and unit.tactical_role != unit_roles[member.role]: return _fail(result,&"ROLE_MISMATCH")
		member.availability = _available(unit,automatic_cards,identity == HERO_SLOT)
		if member.availability == Availability.AVAILABLE: result.total_available += 1
		result.members.append(member)
	if previous == null or safe_rebuild:
		result.batches.clear(); result.epoch += 1
		_build(result)
	# Existing batch identities survive death, control changes and replacement.
	# A new identity waits outside the current transit denominator until regroup.
	for batch_index in range(result.batches.size()):
		var batch := result.batches[batch_index]
		for ordinal in range(batch.identities.size()):
			var member := result.members[batch.identities[ordinal]]
			member.batch = batch_index; member.ordinal = ordinal
			member.offset = Vector2(-batch.depth_start-(ordinal/3)*SPACING,(ordinal%3-1)*SPACING)
	for member in result.members:
		if member.availability == Availability.AVAILABLE and member.batch < 0: result.pending_identities.append(member.identity)
	_evaluate(result)
	if commander.legion_regrouping:
		result.advance_ready = false; result.reason = &"REGROUPING"
	return result

static func _append(plan: Plan, batch_index: int, identity: int, pool: Array[int]) -> void:
	plan.batches[batch_index].identities.append(identity)
	pool.erase(identity)

static func _build(plan: Plan) -> void:
	var pool: Array[int] = []
	var core: Array[int] = []
	var artillery: Array[int] = []
	for member in plan.members:
		if member.availability != Availability.AVAILABLE: continue
		pool.append(member.identity)
		if member.role in [1,2]: core.append(member.identity)
		if member.role == 3: artillery.append(member.identity)
	var count := pool.size()
	if count == 0: return
	var parts := ceili(count/float(MAX_BATCH))
	var capacities: Array[int] = []
	for index in range(parts):
		plan.batches.append(Batch.new())
		capacities.append(count/parts+int(index<count%parts))
	var protected_batch := parts/2
	if pool.has(HERO_SLOT): _append(plan,protected_batch,HERO_SLOT,pool)
	# Give the protected batch its real core before distributing other escorts.
	var batch_order: Array[int] = [protected_batch]
	for index in range(parts):
		if index != protected_batch: batch_order.append(index)
	for index in batch_order:
		for _escort in range(2):
			if core.is_empty() or plan.batches[index].identities.size() >= capacities[index]: break
			_append(plan,index,core.pop_front(),pool)
	if plan.profile_id == &"sentinel":
		var scouts := 0
		for identity in pool.duplicate():
			if scouts == 2 or plan.batches[0].identities.size() >= capacities[0]: break
			if plan.members[identity].role == 0:
				_append(plan,0,identity,pool); scouts += 1
	var cursor := 0
	# Stable identities, independent of current entity numbers and input order.
	# Distribute guns first to mix their batches with the seeded escorts.
	var order := artillery.duplicate()
	for identity in pool:
		if not order.has(identity): order.append(identity)
	for identity in order:
		if not pool.has(identity): continue
		while plan.batches[cursor].identities.size() >= capacities[cursor]: cursor = (cursor+1)%parts
		_append(plan,cursor,identity,pool)
		cursor = (cursor+1)%parts
	var depth := 0.0
	for batch in plan.batches:
		batch.depth_start = depth
		batch.depth = (ceili(batch.identities.size()/3.0)-1)*SPACING+ENVELOPE
		depth += batch.depth+CLEAR_GAP

static func _evaluate(plan: Plan) -> void:
	var has_core := false
	var bad_escort := false
	for batch in plan.batches:
		batch.available = 0; batch.escorts = 0; batch.artillery = 0; batch.has_hero = false
		for identity in batch.identities:
			var member := plan.members[identity]
			if member.availability != Availability.AVAILABLE: continue
			batch.available += 1
			if member.role in [1,2]: batch.escorts += 1; has_core = true
			if member.role == 3: batch.artillery += 1
			if member.role == 4: batch.has_hero = true
		bad_escort = bad_escort or (batch.has_hero and batch.escorts < 1) or (batch.artillery > 0 and batch.escorts < 2)
	plan.advance_ready = false
	if plan.members[HERO_SLOT].availability != Availability.AVAILABLE: plan.reason = &"HERO_UNAVAILABLE"
	elif plan.members[HERO_SLOT].batch < 0: plan.reason = &"HERO_REJOIN_WAIT"
	elif not has_core: plan.reason = &"NO_CORE"
	elif bad_escort: plan.reason = &"ESCORT_SHORTAGE"
	else:
		plan.advance_ready = true
		plan.reason = &"REJOIN_WAIT" if not plan.pending_identities.is_empty() else &"READY"
