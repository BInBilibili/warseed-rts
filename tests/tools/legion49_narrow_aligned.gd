extends "res://tests/tools/legion49_narrow_executor.gd"

# v1 transformed a world-space Y component as if it were the local lateral
# component. Godot RIGHT.orthogonal() points up, so that mirrored each row.
# Keep v1 evidence as a perturbed-start diagnostic; undo that reflection here.
func road_fixture(profile: StringName, count: int, mirror: bool, narrow: bool) -> SimulationWorld:
	var world := super.road_fixture(profile,count,mirror,narrow)
	var center := Vector2(2048,20000)
	if mirror: center=world.battle_definition.map_definition.mirror_point(center)
	var forward := Vector2.DOWN if mirror else Vector2.UP
	for unit: UnitState in world.units.values():
		var delta := unit.position-center
		unit.position=center+forward*delta.dot(forward)-forward.orthogonal()*delta.dot(forward.orthogonal())
		check(world.logic_grid.is_world_position_walkable(unit.position),"aligned fixture initial entity walkable")
	var commander := world.commanders.values()[0] as CommanderState
	var geometry := LegionSpatialExecutor.layout(profile,LegionSpatialState.Action.MOVE)
	for identity in range(count):
		var unit := world.units[commander.growth_slot_entities[identity]] as UnitState
		var expected := center+forward*geometry.offsets[identity].x+forward.orthogonal()*geometry.offsets[identity].y
		check(unit.position.distance_to(expected)<=0.01,"initial road row is rotated, not laterally reflected")
	return world
