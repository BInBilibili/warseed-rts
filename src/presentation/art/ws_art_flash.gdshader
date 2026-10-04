shader_type canvas_item;
render_mode unshaded;
varying vec4 feedback;
varying vec4 vertex_tint;
void vertex() {
	feedback = INSTANCE_CUSTOM;
	vertex_tint = COLOR;
}
void fragment() {
	// QuadMesh UV Y is inverted relative to draw_texture_rect in CanvasItem.
	vec4 tex = texture(TEXTURE, vec2(UV.x, 1.0 - UV.y)) * vertex_tint;
	float grey = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	tex.rgb = mix(tex.rgb, vec3(grey * 0.55), feedback.g);
	tex.rgb = mix(tex.rgb, vec3(1.0, 0.93, 0.72), feedback.r * 0.8);
	COLOR = tex;
}
