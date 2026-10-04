extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	var world := SimulationWorld.new(true, false, SimulationWorld.ScenarioKind.FINAL_DECISION)
	var faction := world.factions[1] as FactionState
	faction.supply = 300
	var target := world.units[1001] as UnitState
	check(world.create_snapshot().get_unit(target.entity_id) == null, "enemy starts in darkness")
	var recon := AreaSupportCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, SupportOrderCommand.SupportKind.AIR_RECON, target.position)
	check(world.submit_command(recon).is_accepted(), "dark-area recon accepted")
	check(not world.submit_command(recon.duplicate_value()).is_accepted(), "duplicate queued power rejected")
	recon.position = Vector2.ZERO
	world.advance_tick()
	var visible := world.create_snapshot().get_unit(target.entity_id)
	check(visible != null and visible.is_visible_to_local_player, "recon reveals actual enemy unit")
	var old := world.create_snapshot()
	target.position += Vector2(-300, 300)
	world._update_faction_knowledge()
	visible = world.create_snapshot().get_unit(target.entity_id)
	check(visible != null and visible.position == target.position, "recon updates moving enemy positions")
	check(world.create_snapshot(2).area_support_effects.is_empty(), "enemy cannot inspect private aerial recon")
	check(not world.submit_command(AreaSupportCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, SupportOrderCommand.SupportKind.MISSILE_BARRAGE, Vector2(INF, 0))).is_accepted(), "nonfinite target rejected")
	check(not world.submit_command(AreaSupportCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, SupportOrderCommand.SupportKind.MISSILE_BARRAGE, Vector2(-1, 0))).is_accepted(), "off-map target rejected")
	# Authority-only timing fixture: expiration must stop live tracking exactly.
	world.current_tick = 250
	world.area_support_system.advance(world)
	world._update_faction_knowledge()
	visible = world.create_snapshot().get_unit(target.entity_id)
	check(visible == null or not visible.is_visible_to_local_player, "expired recon stops live visibility")
	check(old.area_support_effects.size() == 1 and old.area_support_effects[0].expires_tick == 250, "effect snapshots are value copies")
	world.command_queue.drain()
	var blue := world.units[1] as UnitState
	var strike_position := Vector2(16384, 12288)
	blue.position = strike_position
	target.position = strike_position + Vector2(50, 0)
	blue.health = blue.max_health
	target.health = target.max_health
	var blue_before := blue.health
	var red_before := target.health
	var strike := AreaSupportCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, SupportOrderCommand.SupportKind.MISSILE_BARRAGE, strike_position)
	world.area_support_system.apply(world, strike)
	check(world.create_snapshot(2).area_support_effects.size() == 1, "both sides see missile warning")
	world.current_tick = 289
	world.area_support_system.advance(world)
	check(blue.health == blue_before and target.health == red_before, "no damage before warning completes")
	world.current_tick = 290
	world.area_support_system.advance(world)
	check(blue.health < blue_before and target.health < red_before, "missile damages BOTH factions")
	var after_hit := target.health
	world.current_tick = 291
	world.area_support_system.advance(world)
	check(target.health == after_hit, "single strike cannot damage repeatedly")
	# Hospital uses safe supply placement, applies only to allies, never revives.
	var wounded := world.units[2] as UnitState
	var supply_point := world.battle_definition.player_headquarters_position + Vector2(256, 0)
	wounded.position = supply_point
	wounded.health = 10
	target.enabled = true
	target.position = supply_point
	target.health = 10
	var hospital := AreaSupportCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, SupportOrderCommand.SupportKind.FIELD_HOSPITAL, supply_point)
	check(world.validate_command(hospital).is_accepted(), "hospital deploys near friendly supply")
	world.area_support_system.apply(world, hospital)
	world.area_support_system.advance(world)
	check(wounded.health == 18 and target.health == 10, "hospital pulse heals allies only")
	var hospital_snapshot := world.create_snapshot()
	var hospital_effect: AreaSupportEffect
	for effect in hospital_snapshot.area_support_effects:
		if effect.support_kind == SupportOrderCommand.SupportKind.FIELD_HOSPITAL:
			hospital_effect = effect
	check(hospital_effect != null and hospital_effect.expires_tick - hospital_effect.active_tick == 600, "hospital lifespan is exactly 60 seconds")
	world.current_tick = hospital_effect.expires_tick - 1
	wounded.health = 10
	world.area_support_system.advance(world)
	check(wounded.health == 18, "hospital still works before expiration")
	world.current_tick += 1
	wounded.health = 10
	world.area_support_system.advance(world)
	check(wounded.health == 10 and world.area_support_system.effects.is_empty(), "hospital stops at expiration and is removed")
	# Shared budget cannot be spent twice across different command classes.
	world.command_queue.drain()
	faction.support_cooldown_until_by_kind.clear()
	faction.supply = 60
	check(world.submit_command(AreaSupportCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, SupportOrderCommand.SupportKind.MISSILE_BARRAGE, strike_position)).is_accepted(), "reserve missile budget")
	check(not world.submit_command(AreaSupportCommand.new(world.allocate_command_id(), 1, 0, world.current_tick, SupportOrderCommand.SupportKind.AIR_RECON, strike_position)).is_accepted(), "area powers share pending budget")
	for failure in failures:
		push_error(failure)
	print("GROWTH_SUPPORT recon_tracking=true friendly_fire=true hospital_seconds=60 failures=%d" % failures.size())
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
