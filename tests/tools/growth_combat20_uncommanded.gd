extends "res://tests/tools/growth_combat20.gd"

func _initialize() -> void:
	for role in [&"UNIT_CARD_ROLE_RECON", &"UNIT_CARD_ROLE_ASSAULT", &"UNIT_CARD_ROLE_FIREPOWER"]:
		var world := fixture(role)
		var card := find_card(world, role)
		# No commander has a card to coordinate; this isolates basic reactions.
		for commander: CommanderState in world.commanders.values():
			commander.subordinate_unit_card_ids.clear()
		var target := enemy(world, ORIGIN + Vector2(170, 0))
		var cursor := world.events.size()
		for tick in range(35): world.advance_tick()
		var shots := 0
		var accepted := 0
		for event in world.events.slice(cursor):
			if event.kind == SimulationEvent.Kind.PROJECTILE_FIRED and card.member_entity_ids.has(event.entity_id): shots += 1
			if event.kind == SimulationEvent.Kind.COMMAND_ACCEPTED: accepted += 1
		check(shots > 0, "%s fires without commander orders" % role)
		check(accepted == 0, "%s fixture contains no accepted command" % role)
		if role != &"UNIT_CARD_ROLE_FIREPOWER": check(target.health < 10000, "%s deals autonomous damage" % role)
		print("COMBAT20_UNCOMMANDED role=", role, " shots=", shots, " accepted_commands=", accepted)
	for failure in failures: push_error(failure)
	print("COMBAT20_UNCOMMANDED failures=", failures)
	quit(0 if failures.is_empty() else 1)
