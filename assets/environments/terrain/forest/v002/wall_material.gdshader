shader_type canvas_item;
render_mode unshaded;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec2 texture_world_size=vec2(256.0);
uniform vec4 albedo_tint : source_color=vec4(1.0);
uniform sampler2D coverage_texture : filter_nearest;
uniform vec2 world_bounds;
uniform float cell_size;
uniform float transition_width;
uniform vec4 edge_tint : source_color;
uniform bool use_contour_distance=false;
uniform sampler2D contour_distance : filter_nearest;
uniform float distance_max=32.0;
varying vec2 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 vec2 w=floor(world_position)+vec2(0.5);
 vec2 p=mod(w,vec2(cell_size));
 vec2 center=(floor(w/cell_size)+vec2(0.5))*cell_size;
 float d=cell_size;
 if(texture(coverage_texture,(center-vec2(cell_size,0))/world_bounds).r<0.5)d=min(d,p.x);
 if(texture(coverage_texture,(center+vec2(cell_size,0))/world_bounds).r<0.5)d=min(d,cell_size-p.x);
 if(texture(coverage_texture,(center-vec2(0,cell_size))/world_bounds).r<0.5)d=min(d,p.y);
 if(texture(coverage_texture,(center+vec2(0,cell_size))/world_bounds).r<0.5)d=min(d,cell_size-p.y);
 if(use_contour_distance)d=(texture(contour_distance,w/world_bounds).r-0.5)*2.0*distance_max;
 vec4 stone=texture(albedo_texture,w/texture_world_size);
 float grain=mod(w.x*7.0+w.y*3.0,11.0);
 if(d<3.0)stone.rgb=grain<4.0?vec3(0.322,0.427,0.247):vec3(0.231,0.345,0.220);
 stone.a*=step(0.0,d);
 COLOR=stone*albedo_tint;
}
