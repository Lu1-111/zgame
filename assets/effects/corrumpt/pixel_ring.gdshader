shader_type canvas_item;
render_mode unshaded;

// 在世界像素网格上采样环带，扩散只改变半径；环带厚度和纹素尺寸保持原生大小。
uniform float extent_world = 1.0;
uniform float radius_world = 0.0;
uniform float pixel_pitch = 1.0;
uniform float repeat_pixels = 96.0;
uniform float strip_height = 12.0;
varying vec4 ring_tint;

void vertex() {
	ring_tint = COLOR;
}

void fragment() {
	vec2 local_pixel = (floor(((UV * 2.0 - 1.0) * extent_world) / pixel_pitch) + 0.5) * pixel_pitch;
	float radial = (length(local_pixel) - radius_world) / strip_height + 0.5;
	float arc_pixels = atan(local_pixel.y, local_pixel.x) * max(radius_world, pixel_pitch);
	vec4 sample_color = texture(TEXTURE, vec2(fract(arc_pixels / repeat_pixels), clamp(radial, 0.0, 1.0)));
	if (radial < 0.0 || radial >= 1.0) {
		sample_color = vec4(0.0);
	}
	COLOR = sample_color * ring_tint;
}
