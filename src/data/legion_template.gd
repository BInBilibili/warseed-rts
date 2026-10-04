class_name LegionTemplate
extends Resource

const PROFILE_IDS: Array[StringName] = [&"spear", &"guardian", &"gunner", &"sentinel", &"ranger"]
const ROLE_KEYS: Array[StringName] = [&"UNIT_CARD_ROLE_RECON", &"UNIT_CARD_ROLE_ASSAULT", &"UNIT_CARD_ROLE_ARMOR", &"UNIT_CARD_ROLE_FIREPOWER"]

@export var profile_id: StringName
@export var opening: PackedInt32Array
@export var full: PackedInt32Array
@export var growth_roles: PackedInt32Array
@export var recovery_roles: PackedInt32Array
@export var recovery_minimums: PackedInt32Array
@export var hero_health: float
@export var hero_armor: float
@export var hero_speed: float
@export var hero_damage: float
@export var hero_range: float
@export var hero_cooldown: int
@export var hero_sight: float
@export var armed_recon := false

static func find(id: StringName) -> LegionTemplate:
	if id not in PROFILE_IDS: return null
	return load("res://data/legions/%s.tres" % id) as LegionTemplate

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if profile_id not in PROFILE_IDS: errors.append("legion profile id")
	if opening.size() != 4 or full.size() != 4 or growth_roles.size() != 48:
		errors.append("legion template dimensions")
		return errors
	var counts := opening.duplicate()
	var total := 0
	for role in range(4):
		if opening[role] < 0 or full[role] < opening[role]: errors.append("legion role bounds")
		total += opening[role]
	if total != 12: errors.append("legion opening must be 12")
	for role in growth_roles:
		if role < 0 or role > 3: errors.append("legion growth role")
		else: counts[role] += 1
	if counts != full: errors.append("legion growth totals")
	if recovery_roles.size() != recovery_minimums.size(): errors.append("legion recovery dimensions")
	else:
		var seen: Array[int] = []
		for i in range(recovery_roles.size()):
			var role := recovery_roles[i]
			if role < 0 or role > 3 or seen.has(role): errors.append("legion recovery role")
			elif recovery_minimums[i] < 0 or recovery_minimums[i] > opening[role]: errors.append("legion recovery minimum")
			seen.append(role)
	if hero_health <= 0 or hero_armor < 0 or hero_speed <= 0 or hero_damage <= 0 or hero_range <= 0 or hero_cooldown <= 0 or hero_sight <= 0:
		errors.append("legion hero parameters")
	for value in [hero_health,hero_armor,hero_speed,hero_damage,hero_range,hero_sight]:
		if not is_finite(value): errors.append("legion hero finite parameters")
	return errors

func slot_roles() -> PackedInt32Array:
	var roles := PackedInt32Array()
	for role in range(4):
		for i in range(opening[role]): roles.append(role)
	roles.append_array(growth_roles)
	return roles

# Occupancy includes born/in-transit members and validated pending commands.
# No world or hidden enemy state participates in this deterministic selection.
func next_slot(unlocked: int, occupied: PackedByteArray) -> int:
	var roles := slot_roles()
	var alive := PackedInt32Array([0,0,0,0])
	var capacity := PackedInt32Array([0,0,0,0])
	for slot in range(mini(unlocked, 60)):
		capacity[roles[slot]] += 1
		if occupied[slot]: alive[roles[slot]] += 1
	for i in range(recovery_roles.size()):
		var role := recovery_roles[i]
		if alive[role] >= mini(capacity[role], recovery_minimums[i]): continue
		for slot in range(unlocked):
			if roles[slot] == role and not occupied[slot]: return slot
	for slot in range(unlocked):
		if not occupied[slot]: return slot
	return unlocked if unlocked < 60 else -1
