class_name BattlePresentationView
extends RefCounted

# Published once, then read-only like its source WorldSnapshot.
var source: WorldSnapshot
var definition: BattleDefinition
var situation: BattlefieldSituationSnapshot
var command_situation: CommandSituationSnapshot
