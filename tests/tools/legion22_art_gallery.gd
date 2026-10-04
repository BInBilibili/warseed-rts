extends SceneTree
class Gallery extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,480),Color("111c22"))
		for side in range(2):
			for stage in range(3):
				var unit := Node2D.new()
				unit.position = Vector2(180+stage*300,140+side*200)
				unit.scale = Vector2(2,2)
				unit.draw.connect(func(): WsArtLibrary.draw_unit(unit,&"missile_vehicle",side==0,0,0,stage*0.5))
				add_child(unit)
				draw_string(ThemeDB.fallback_font,Vector2(100+stage*300,65+side*200),["移动 / Travel","展开 / Deploy","就绪 / Ready"][stage],HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(960,480)
	root.content_scale_size = root.size
	root.add_child(Gallery.new())
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/legion22-art-gallery.png")
	print("LEGION22_ART_GALLERY rendered")
	quit()
