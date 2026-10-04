extends SceneTree
func _initialize() -> void:
	var script: Script = load("res://src/presentation/art/ArtBufferKernel.cs")
	print("NATIVE_CAPABILITY ",OS.has_feature("C#")," ",OS.has_feature("mono")," ",script," ",script.can_instantiate())
	var kernel = script.new()
	print("NATIVE_INSTANCE ",kernel)
	if kernel != null: print("NATIVE_BUFFER ",kernel.Fill(PackedFloat64Array([1,2,1,0,1,0,1,2,0]),1,1))
	quit()
