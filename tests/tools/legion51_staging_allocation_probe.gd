extends "res://tests/tools/legion49_narrow_aligned.gd"

func _staging_free(point: Vector2, occupied: PackedVector2Array, world: SimulationWorld) -> bool:
	if not LegionTransitGeometry.segment_fits(world.logic_grid,point,point): return false
	for other in occupied:
		if point.distance_squared_to(other)<48.0*48.0-0.01: return false
	return true

func _initialize() -> void:
	var rows: Array = []
	for profile: StringName in LegionTemplate.PROFILE_IDS:
		for mirror in [false,true]:
			var world := road_fixture(profile,60,mirror,true)
			var commander := world.commanders.values()[0] as CommanderState
			var transit: LegionTransitState
			for tick in range(200):
				step(world)
				transit=world.legion_formation_system.records[commander.definition.definition_id].spatial.transit
				if transit.phase==LegionTransitState.Phase.GATHER: break
			check(transit!=null and transit.phase==LegionTransitState.Phase.GATHER,"allocation fixture physically reaches gather")
			var occupied := PackedVector2Array()
			var targets: Array[Vector2] = []; targets.resize(61); targets.fill(Vector2(INF,INF))
			var shifted := 0
			for batch in transit.batches:
				for ordinal in range(batch.identities.size()):
					var identity := batch.identities[ordinal]
					if identity==60: continue
					var base := batch.progress-floori(ordinal/float(transit.columns))*48.0
					for extra in range(61):
						var point := LegionTransitGeometry.point_at(transit.path,base-extra*48.0,batch.gather_laterals[ordinal])
						if _staging_free(point,occupied,world):
							targets[identity]=point; occupied.append(point)
							if extra>0: shifted+=1
							break
					check(targets[identity].is_finite(),"unique full-envelope soldier staging exists")
			var batch := transit.batches[transit.hero_batch]
			var escort := -1
			for identity in batch.identities:
				var unit := LegionTransitExecutor._entity(world,commander,identity)
				if unit.tactical_role in [UnitState.TacticalRole.ASSAULT,UnitState.TacticalRole.ARMOR]: escort=identity; break
			var base := batch.progress-floori(transit.hero_ordinal/float(transit.columns))*48.0
			for delta in range(49):
				var shift := (ceili(delta/2.0)*(1 if delta%2 else -1))*48.0
				var point := LegionTransitGeometry.point_at(transit.path,base+shift,batch.gather_laterals[transit.hero_ordinal])
				if _staging_free(point,occupied,world) and point.distance_to(targets[escort])<=240.0:
					targets[60]=point; occupied.append(point); break
			check(targets[60].is_finite(),"unique staging keeps hero within real same-batch escort range")
			rows.append({"profile":profile,"mirror":mirror,"capacity":occupied.size(),"shifted_soldiers":shifted,"hero":str(targets[60]),"escort":str(targets[escort])})
	FileAccess.open("res://artifacts/legion51/staging-allocation02.json",FileAccess.WRITE).store_string(JSON.stringify({"evidence":"SIMULATED_COMPONENT_ONLY","checks":checks,"failures":failures,"rows":rows,"physical_gather_certified":false}))
	print("LEGION51_STAGING_ALLOCATION checks=",checks," failures=",failures.size())
	for failure in failures: print("FAIL ",failure)
	quit(0 if failures.is_empty() else 1)
