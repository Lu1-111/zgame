shader_type canvas_item;
uniform sampler2D rock_field : source_color, repeat_enable, filter_nearest;
uniform vec2 field_size = vec2(256.0);
varying vec2 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 mask = texture(TEXTURE, UV);
	COLOR = texture(rock_field, world_position / field_size) * vec4(1.0, 1.0, 1.0, mask.a);
}
