extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(value: bool, reason: String) -> void:
	checks+=1
	if not value and not failures.has(reason): failures.append(reason)

func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	var policy := LegionReformationPolicy.new()
	check(policy.validation_errors().is_empty(),"valid typed policy")
	check(policy.tolerance(32)==4.0,"compact slots cannot reuse six-unit tolerance")
	var world := SimulationWorld.new(false)
	world.logic_grid=LogicGrid.new(); world.logic_grid.grid_size=Vector2i(100,100)
	world.pathfinder=GridPathfinder.new(world.logic_grid)
	var a := UnitState.new(1,Vector2(512,512),135,1)
	var b := UnitState.new(2,Vector2(560,512),135,1)
	world.units={1:a,2:b}
	var members: Array[UnitState] = [a,b]
	check(LegionReformationSystem.request(world,members,PackedVector2Array([b.position,a.position]),"swap"),"local swap gets legal nonoverlapping targets")
	check(a.reformation.charge(0,policy),"first tick charged")
	check(a.reformation.charge(0,policy) and a.reformation.active_ticks.size()==1,"multiple passes charge only once")
	var collision := LegionMotionConstraint.new(); collision.ground_radius=32.0
	check(collision._clear(a.position,b.position,a.entity_id,world.units,world.logic_grid),"active member crosses friendly body")
	b.faction_id=2
	check(not collision._clear(a.position,b.position,a.entity_id,world.units,world.logic_grid),"enemy body remains blocking")
	b.faction_id=1
	var copy := a.reformation.duplicate_value()
	a.reformation.active_ticks.append(1)
	check(copy.active_ticks.size()==1,"state copy does not alias budget")
	var snapshot := UnitSnapshot.new(a)
	a.reformation.phase=LegionReformationState.Phase.SOLID
	check(snapshot.reformation_phase==LegionReformationState.Phase.REFORMING and snapshot.reformation_damage_multiplier==1.5,"snapshot preserves visible state by value")
	a.reformation.phase=LegionReformationState.Phase.REFORMING
	a.armor=14.0; a.health=200.0; a.max_health=200.0; a.can_attack=false; b.can_attack=false
	var events: Array[SimulationEvent] = []
	var projectiles := {1:ProjectileState.new(1,2,1,2,a.position,600,50,-3)}
	CombatSystem.new().advance(world.units,{},projectiles,2,events,2)
	check(is_equal_approx(a.health,146.0),"in-flight hit uses current vulnerable state after armor")
	a.reformation.phase=LegionReformationState.Phase.SOLID
	projectiles={2:ProjectileState.new(2,2,1,2,a.position,600,50,-3)}
	CombatSystem.new().advance(world.units,{},projectiles,3,events,3)
	check(is_equal_approx(a.health,110.0),"hit after restoration has normal damage")
	a.reformation.phase=LegionReformationState.Phase.SEPARATING
	projectiles={3:ProjectileState.new(3,2,1,2,a.position,600,10,0)}
	CombatSystem.new().advance(world.units,{},projectiles,4,events,4)
	check(is_equal_approx(a.health,108.5),"minimum damage remains fractional and separating stays vulnerable")
	var suppressed := ProjectileState.new(4,2,1,2,a.position,600,50,0)
	suppressed.damage_tag=TacticalWeaponDefinition.DamageTag.SUPPRESSION
	projectiles={4:suppressed}
	CombatSystem.new().advance(world.units,{},projectiles,5,events,5)
	check(is_equal_approx(a.health,108.5),"pure suppression does not acquire life damage")
	a.position=b.position
	a.reformation.end(6,true,policy,&"REFORMATION_CANCELLED")
	check(a.reformation.phase==LegionReformationState.Phase.SEPARATING,"cancel while overlapping preserves separation debt")
	b.reformation.phase=LegionReformationState.Phase.SOLID
	check(not LegionReformationSystem.ignores_pair(a,b),"cancel removes free passage")
	check(collision._clear(a.position,a.position+Vector2(10,0),a.entity_id,world.units,world.logic_grid),"inherited overlap may separate within movement budget")
	a.position+=Vector2(48,0)
	LegionReformationSystem.finish_movement(world)
	check(a.reformation.phase==LegionReformationState.Phase.SOLID,"real separation clears vulnerability")
	var budget := LegionReformationState.new()
	check(budget.begin(0,Vector2(100,0),PackedVector2Array([Vector2.ZERO,Vector2(100,0)]),"one",6,policy),"budget starts")
	for tick in range(60): check(budget.charge(tick,policy),"sixty permitted ticks")
	check(not budget.charge(60,policy),"hard duration cannot be extended")
	budget.end(60,false,policy,&"REFORMATION_TIMEOUT")
	check(not budget.can_start(89,policy),"cooldown retained")
	check(not budget.can_start(90,policy),"rolling budget survives intent change")
	check(budget.can_start(100,policy),"oldest charged tick expires exactly at window boundary")
	var layouts: Array = []
	for profile: StringName in [&"spear",&"guardian",&"gunner",&"sentinel",&"ranger"]:
		for action in range(4):
			for spacing in [48.0,40.0,32.0]:
				var values := LegionDeploymentPlanner.offsets(profile,action,spacing)
				layouts.append([profile,action,spacing,values.size()])
				check(values.size()==61,"all standard and compressed layouts include commander: "+str([profile,action,spacing]))
	var gun := UnitState.new(101,Vector2(512,512),90,1)
	var neighbor := UnitState.new(102,Vector2(544,512),90,1)
	var target := UnitState.new(103,Vector2(512,612),90,2)
	gun.tactical_role=UnitState.TacticalRole.FIREPOWER
	gun.reformation=LegionReformationState.new(); gun.attack_target_entity_id=103
	gun.weapon_preparation_ticks=2; gun.attack_cooldown_ticks=1
	neighbor.can_attack=false; target.can_attack=false
	var guns := {101:gun,102:neighbor,103:target}
	var gun_events: Array[SimulationEvent] = []
	var gun_projectiles := {}; var gun_combat := CombatSystem.new(); var next_gun_projectile := 1
	for tick in range(3):
		next_gun_projectile=gun_combat.advance(guns,{},gun_projectiles,next_gun_projectile,gun_events,tick)
	check(gun.weapon_shots_fired==0 and gun.weapon_prepared_ticks==0,"32-spaced gun cannot prepare or fire")
	neighbor.position=Vector2(560,512)
	for tick in range(3,5):
		next_gun_projectile=gun_combat.advance(guns,{},gun_projectiles,next_gun_projectile,gun_events,tick)
	check(gun.weapon_prepared_ticks==2 and gun.weapon_shots_fired==1,"48-spaced gun fires after full preparation")
	var victim := UnitState.new(111,Vector2(800,800),90,1)
	var killer := UnitState.new(112,Vector2(900,800),90,1)
	victim.reformation=LegionReformationState.new(); victim.reformation.phase=LegionReformationState.Phase.REFORMING
	victim.health=10; victim.can_attack=false; killer.can_attack=false
	var lethal_units := {111:victim,112:killer}
	var lethal := {1:ProjectileState.new(1,112,111,2,victim.position,600,30,-3)}
	var lethal_events: Array[SimulationEvent] = []
	CombatSystem.new().advance(lethal_units,{},lethal,2,lethal_events,7)
	check(not victim.enabled and victim.reformation.phase==LegionReformationState.Phase.SOLID,"lethal hit revokes reformation on impact tick")
	check(not LegionReformationSystem.ignores_pair(victim,killer) and victim.reformation.reason==&"REFORMATION_DEAD","dead unit has no collision exemption")
	var hold_world := SimulationWorld.new(false)
	hold_world.battle_definition=BattleDefinition.new(); hold_world.battle_definition.growth_mode=true
	var hero := UnitState.new(121,Vector2(1000,1000),90,1)
	var escort := UnitState.new(122,Vector2(1016,1000),90,1)
	hero.control_state=UnitState.ControlState.AGENT_ASSIGNED
	hero.reformation=LegionReformationState.new(); hero.reformation.phase=LegionReformationState.Phase.REFORMING
	hold_world.units={121:hero,122:escort}
	var commander_def := CommanderDefinition.new(); commander_def.definition_id=&"hold_probe"
	var hold_commander := CommanderState.new(commander_def,1)
	hold_commander.hero_entity_id=121; hold_commander.posture=CommanderState.Posture.HOLD
	hold_world.commanders[&"hold_probe"]=hold_commander
	hold_world.legion_formation_system.records[&"hold_probe"]=LegionFormationState.new()
	hold_world.legion_formation_system.advance_heroes(hold_world)
	check(hero.reformation.phase==LegionReformationState.Phase.SEPARATING and not LegionReformationSystem.ignores_pair(hero,escort),"HOLD overlap immediately removes free passage")
	check(LegionReformationSystem.damage_factor(hero)==1.5,"HOLD overlapping hero still pays risk")
	hero.reformation.phase=LegionReformationState.Phase.REFORMING; escort.position=Vector2(1064,1000)
	hold_world.legion_formation_system.advance_heroes(hold_world)
	check(hero.reformation.phase==LegionReformationState.Phase.SOLID and LegionReformationSystem.damage_factor(hero)==1.0,"HOLD without overlap becomes solid")
	var report := {"evidence":"SIMULATED_CANDIDATE","checks":checks,"failures":failures,"layouts":layouts}
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file==null: quit(2); return
	file.store_string(JSON.stringify(report)); file.close()
	print("LEGION57_CONTRACT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
