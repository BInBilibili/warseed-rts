extends "res://tests/tools/perf23_blue_policy.gd"

# A simulated player: public map plus blue faction snapshots only. Preserve
# normal economy, recruitment, commanders and all ordinary command validation.
func _init() -> void:
	super("elastic")

func advance(world: SimulationWorld) -> void:
	if world.current_tick % 20 != 0: return
	var view := world.create_faction_snapshot(1)
	var reserve := view.get_commander(&"mobile_legion")
	var support := GrowthSupportAgent.new().propose(view,world.battle_definition,0)
	if support != null:
		support.command_id = world.allocate_command_id()
		support.issuer_kind = GameCommand.IssuerKind.PLAYER
		_submit(world,support,"legal adaptive support")
	if reserve == null or reserve.legion_regrouping or reserve.growth_recovering: return
	var center := view.get_unit(reserve.hero_entity_id)
	if center == null or not center.enabled: return
	var defensive := GrowthCommanderAgent.new()._reserve_target(view,center.position)
	var emergency := false
	if defensive != null:
		for enemy in view.units:
			if enemy.faction_id != 1 and enemy.enabled and not enemy.legion_returning and enemy.is_visible_to_local_player and enemy.position.distance_to(defensive.position) <= 2600.0:
				emergency = true
	if emergency:
		if reserve.target_region_id != defensive.region_id: _order(world,&"mobile_legion",defensive)
		return
	# Reinforce a known front whose capture creates a connected supply route.
	var target: StrategicRegionSnapshot
	var score := -INF
	for id in [&"bai_jiuyang",&"di_tian",&"lin_mo"]:
		var commander := view.get_commander(id)
		if commander == null or commander.growth_recovering or commander.legion_regrouping: continue
		var region := view.get_strategic_region(commander.target_region_id)
		if region == null or region.controller_faction_id == 1: continue
		var strength := 0
		var location := Vector2.ZERO
		for card in view.unit_cards:
			if card.commander_definition_id == id and card.current_strength > 0:
				strength += card.current_strength
				location += card.center_position * card.current_strength
		if strength < 24: continue
		location /= strength
		if location.distance_to(region.position) > 2200.0: continue
		var value := strength * 100.0 - center.position.distance_to(region.position)
		if value > score: score=value; target=region
	if target != null and reserve.target_region_id != target.region_id:
		_order(world,&"mobile_legion",target)
