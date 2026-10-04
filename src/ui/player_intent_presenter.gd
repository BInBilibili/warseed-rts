class_name PlayerIntentPresenter
extends RefCounted


static func authority(commander: CommanderSnapshot) -> String:
	if commander.legion_regrouping: return GameText.t(&"AUTHORITY_HARD_LOCK")
	return GameText.t(StringName("AUTHORITY_MODE_" + CommanderState.IntentMode.keys()[commander.intent_mode]))


static func detail(commander: CommanderSnapshot, snapshot: WorldSnapshot) -> String:
	var region := snapshot.get_strategic_region(commander.player_target_region_id)
	var target := GameText.t(region.display_name_key) if region != null else "(%.0f, %.0f)" % [commander.player_target_position.x, commander.player_target_position.y]
	var text := "%s → %s\n%s" % [authority(commander), target,
		GameText.t(StringName("AUTHORITY_RECEIPT_" + CommanderState.IntentReceipt.keys()[commander.intent_receipt]))]
	var cards := PackedStringArray()
	for id in commander.subordinate_unit_card_ids:
		var card := snapshot.get_unit_card(id)
		if card != null and card.persistent_manual: cards.append(GameText.t(card.display_name_key) + " · " + GameText.t(StringName("AUTHORITY_RECEIPT_" + CommanderState.IntentReceipt.keys()[card.player_order_receipt])))
	if not cards.is_empty(): text += "\n" + GameText.t(&"AUTHORITY_MANUAL_CARDS") % ", ".join(cards)
	if commander.intent_mode == CommanderState.IntentMode.FORCE_ATTACK:
		text += "\n" + GameText.t(&"AUTHORITY_FORCE_RISK")
	return text
