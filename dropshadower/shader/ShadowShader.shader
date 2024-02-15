shader_type canvas_item;

const float PI = 3.1415926538;
const float PIT = 6.283185307;
const float RAD = PI / 2.0;
const float SCALE = 2.0;

const int MAX_ARR_LEN = 40;

const float blur_offset[3] = {0.0, 2.0, 3.2307692308};


// --- INPUT PARAMS ---
uniform float sun_angle : hint_range(0.0, 1.0) = 0.0;
uniform float sun_intensity = 0.05;
uniform float shadow_dropoff = 1.0;
uniform float shadow_strength = 1.0;

uniform float blur_radius = 10.0;

uniform float node_rotation = 0.0;


uniform bool dropoff = true;

uniform sampler2D prop_texture;

// --- VARYINGS ---
varying vec2 BASE_VERTEX;
varying mat2 SCALE_TRANSFORM;


vec2 reverse_uv_scale(vec2 uv, bool center) {
	uv = SCALE_TRANSFORM * uv;
	if (center) {
		uv.x -= (SCALE - 1.0) / 2.0;
		uv.y -= (SCALE - 1.0) / 2.0;
	}
	
	return uv;
}

vec2 map_uv(vec2 vertex, sampler2D tex) {
	ivec2 tex_size = textureSize(tex, 0);
	vertex.x /= float(tex_size.x);
	vertex.y /= float(tex_size.y);
	return vertex;
}

void vertex() {
	SCALE_TRANSFORM = mat2(
		vec2(SCALE, 0.0),
		vec2(0.0, SCALE)
	);
	VERTEX *= SCALE_TRANSFORM;
	
	float BLUR_WEIGHTS_L[40];
	
	
	
}

/*	texture_scaled 
 *	Samples texture and prevents artifacting when vertex and UV space aren't matched
 */
vec4 texture_scaled(sampler2D tex, vec2 uv) {
	vec4 color = vec4(0.0, 0.0, 0.0, 0.0);
	if (
		(uv.x < 0.0 || uv.x > 1.0) ||
		(uv.y < 0.0 || uv.y > 1.0)
	) {	} else {
		color = texture(tex, uv);
	}
	
	return color;
}

vec4 blend(vec4 col_1, vec4 col_2) {
	if (col_1.a == 0.0) {
	 	return col_2;
	} else if (col_1.a == 1.0) {
		return mix(col_2, col_1, col_1.a);
	} else {
		return col_2;
	}
}

vec2 toPolar(vec2 uv, vec2 center) {
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y, dir.x);
	return vec2(angle, radius);
}

vec2 toCartesian(vec2 polar, vec2 center) {
	vec2 cartesian;
	cartesian.y = cos(polar.x);
	cartesian.x = sin(polar.x);
	cartesian *= polar.y;
	cartesian += center;
	return cartesian;
}

mat3 translate(vec2 t) {
	return mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, 1.0, 0.0),
		vec3(t.x, t.y, 0.0)
	);
}

bool uv_clamp(vec2 uv) {
	return (uv.x < 0.0 || uv.x > 1.0) || (uv.y < 0.0 || uv.y > 1.0);
}

vec2 excess_xy(vec2 uv) {
	vec2 output = vec2(0.0);
	if (uv.x < 0.0) { 
		output.x = abs(uv.x);
	} else if (uv.x > 1.0) {
		output.x = uv.x - 1.0;
	} else {
		output.x = 0.0;
	}
	
	if (uv.y < 0.0) {
		output.y = abs(uv.y);
	} else if (uv.y > 1.0) {
		output.y = uv.y - 1.0;
	} else {
		output.y = 0.0;
	}
	
	return output;
}

float shadow_gradient(vec2 uv, vec2 base_uv) {
	if (uv_clamp(uv)) { return 0.0; }
	
	vec2 dir = uv - base_uv;
	float angle = atan(dir.y, dir.x);
	vec2 shadow_vec = vec2(-1.0, angle);
	
	vec2 TRANS = toCartesian(
		vec2(sun_angle, 2.0 * sun_intensity), vec2(0.0)
	) * 4.0;
	
	vec2 origin = (translate(TRANS) * vec3(0.5)).xy;
	if (dropoff) {
		return 1.0 - distance(origin, uv);
	} else {
		return 1.0;
	}
}

float _mat3_row(vec3 row, int column) {
	switch (column) {
		case 0: return row[0];
		case 1: return row[1];
		case 2: return row[2];
	}
}

float mat3_index(mat3 mat, int row, int column) {
	switch (row) {
		case 0: return _mat3_row(mat[0], column);
		case 1: return _mat3_row(mat[1], column);
		case 2: return _mat3_row(mat[2], column);
	}
}



float blur(vec2 uv, sampler2D tex, vec2 pixel_size) {
	float alpha = 0.0;
	mat3 kernel = mat3(
		vec3(0.05, 0.05, 0.05),
		vec3(0.05, 0.60, 0.05),
		vec3(0.05, 0.05, 0.05)
	);
	ivec2 uv_texel = ivec2(uv * pixel_size);
	for (int x = 0; x < 2; x++) {
		for (int y = 0; y < 2; y++) {
			vec2 offset = vec2(float(x - 1), float(y - 1));
			ivec2 sample_texel = uv_texel + ivec2(x - 1, y - 1);
			vec2 sample_uv = uv - (offset * (pixel_size));
			if (uv_clamp(sample_uv)) { continue; }
			alpha += texture_scaled(tex, sample_uv).a * mat3_index(kernel, x, y);
		}
	}
	
	return alpha;
}

float gauss_blur(float radius, vec2 step, sampler2D tex, vec2 uv) {
	float weights[41] = { 0.012303555535451273, 0.024616263724833186, 0.024627959209285916, 0.024639044267560715, 0.024649518070534567, 0.02465937983457507, 0.02466862882163816, 0.024677264339360162, 0.024685285741144175, 0.024692692426240774, 0.024699483839822955, 0.02470565947305546, 0.024711218863158267, 0.024716161593464424, 0.02472048729347208, 0.02472419563889075, 0.024727286351681893, 0.02472975920009359, 0.024731613998689547, 0.024732850608372263, 0.0247334689364004, 0.0247334689364004, 0.024732850608372263, 0.024731613998689547, 0.02472975920009359, 0.024727286351681893, 0.02472419563889075, 0.02472048729347208, 0.024716161593464424, 0.024711218863158267, 0.02470565947305546, 0.024699483839822955, 0.024692692426240774, 0.024685285741144175, 0.024677264339360162, 0.02466862882163816, 0.02465937983457507, 0.024649518070534567, 0.024639044267560715, 0.024627959209285916, 0.024616263724833186 };
	float offsets[41] = { -40.5, -38.9999390625003, -36.99994218750026, -34.999945312500216, -32.99994843750018, -30.99995156250015, -28.99995468750012, -26.999957812500096, -24.999960937500084, -22.999964062500062, -20.999967187500047, -18.999970312500032, -16.999973437500024, -14.99997656250002, -12.99997968750001, -10.999982812500008, -8.999985937500004, -6.999989062500001, -4.999992187500001, -2.9999953124999994, -0.9999984375, 0.9999984375, 2.9999953124999994, 4.999992187500001, 6.999989062500001, 8.999985937500004, 10.999982812500008, 12.99997968750001, 14.99997656250002, 16.999973437500024, 18.999970312500032, 20.999967187500047, 22.999964062500062, 24.999960937500084, 26.999957812500096, 28.99995468750012, 30.99995156250015, 32.99994843750018, 34.999945312500216, 36.99994218750026, 38.9999390625003 };
	int size = 41;

	
	vec2 s = radius / (float(size) - 1.0) * step / vec2(textureSize(tex, 0));
	float alpha = 0.0;
	for (int i = 0; i < size; i++) {
		if (!uv_clamp(uv + offsets[i] * s)) {
			alpha += (weights[i] * texture(tex, uv + offsets[i] * s).a);
		} else {
			
		}
	}	
	
	return alpha;
}

float sun_ang() {
	float adjust_angle = (PIT - (sun_angle * PIT)) + node_rotation;
	return (PI + adjust_angle) - (PIT / 4.0);
}

void fragment() {
	vec2 P_UV = reverse_uv_scale(UV, true);
	vec2 TRANS = toCartesian(
		vec2(sun_ang(), sun_intensity), vec2(0.0)
	);
	vec2 BLUR_DIR = toCartesian(
		vec2(sun_ang(), 1.0), vec2(0.0)
	);
	vec2 S_UV = (translate(TRANS) * vec3(P_UV, 1.0)).xy;
	vec4 S_COL = texture_scaled(TEXTURE, S_UV);
	S_COL.rgb = vec3(0.0);
	if (dropoff) {
		S_COL.a = gauss_blur(blur_radius, BLUR_DIR, TEXTURE, S_UV) / shadow_dropoff;
	}
	
	S_COL.a *= shadow_strength;
	
	COLOR = blend(
		texture_scaled(TEXTURE, P_UV),
		S_COL
	);
}

