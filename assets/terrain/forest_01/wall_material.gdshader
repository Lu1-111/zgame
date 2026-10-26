shader_type canvas_item;
render_mode unshaded;

uniform sampler2D albedo_texture : source_color, filter_linear, repeat_enable;
uniform vec2 texture_world_size;
uniform vec4 albedo_tint : source_color;
uniform sampler2D coverage_texture : filter_nearest, repeat_disable;
uniform vec2 world_bounds;
uniform float cell_size;
uniform float transition_width;
uniform vec4 edge_tint : source_color;
varying vec2 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = mod(world_position,vec2(cell_size));
	vec2 grid_center = (floor(world_position / cell_size) + vec2(0.5)) * cell_size;
	float edge_distance = cell_size;
	if (texture(coverage_texture,(grid_center-vec2(cell_size,0.0))/world_bounds).r < 0.5) edge_distance = min(edge_distance,p.x);
	if (texture(coverage_texture,(grid_center+vec2(cell_size,0.0))/world_bounds).r < 0.5) edge_distance = min(edge_distance,cell_size-p.x);
	if (texture(coverage_texture,(grid_center-vec2(0.0,cell_size))/world_bounds).r < 0.5) edge_distance = min(edge_distance,p.y);
	if (texture(coverage_texture,(grid_center+vec2(0.0,cell_size))/world_bounds).r < 0.5) edge_distance = min(edge_distance,cell_size-p.y);
	vec4 stone = texture(albedo_texture, world_position / texture_world_size) * albedo_tint;
	float grain = sin(world_position.y*0.43+sin(world_position.x*0.21))*0.7 + sin(world_position.x*0.67)*0.4;
	float transition = smoothstep(0.0,transition_width,edge_distance);
	stone.rgb = mix(stone.rgb*0.45+edge_tint.rgb*0.35,stone.rgb,transition);
	stone.a *= smoothstep(0.0,2.5,edge_distance-grain);
	COLOR = stone;
}
