class_name CommanderProfile
extends Resource

@export var profile_id: StringName
@export var name_key: StringName
@export var personality_key: StringName
@export var health_multiplier := 1.0
@export var speed_multiplier := 1.0
@export var attack_multiplier := 1.0
@export var sight_multiplier := 1.0

static func roster() -> Array[CommanderProfile]:
	var result: Array[CommanderProfile] = []
	for row in [[&"sentinel", &"GENERAL_SENTINEL", &"PERSONALITY_CAUTIOUS", 1.0, 1.05, 1.0, 1.1], [&"guardian", &"GENERAL_GUARDIAN", &"PERSONALITY_STEADY", 1.1, 1.0, 1.0, 1.0], [&"gunner", &"GENERAL_GUNNER", &"PERSONALITY_METHODICAL", 1.0, 1.0, 1.1, 1.0], [&"spear", &"GENERAL_SPEAR", &"PERSONALITY_RESOLUTE", 1.05, 1.0, 1.05, 1.0], [&"ranger", &"GENERAL_RANGER", &"PERSONALITY_OPPORTUNISTIC", 1.0, 1.1, 1.0, 1.0]]:
		var profile := CommanderProfile.new()
		profile.profile_id = row[0]
		profile.name_key = row[1]
		profile.personality_key = row[2]
		profile.health_multiplier = row[3]
		profile.speed_multiplier = row[4]
		profile.attack_multiplier = row[5]
		profile.sight_multiplier = row[6]
		result.append(profile)
	return result

static func find(id: StringName) -> CommanderProfile:
	for profile in roster():
		if profile.profile_id == id: return profile
	return null

func description() -> String:
	return "%s · %s\n%s" % [TranslationServer.translate(name_key), TranslationServer.translate(StringName("GROWTH_%s" % personality_key)), TranslationServer.translate(&"GENERAL_BUFFS") % [roundi((health_multiplier - 1) * 100), roundi((speed_multiplier - 1) * 100), roundi((attack_multiplier - 1) * 100), roundi((sight_multiplier - 1) * 100)]]
