shader_type canvas_item;

const float PI = 3.1415926538;
const float PIT = 6.283185307;
const float RAD = PI / 2.0;
const float SCALE = 2.0;

const int MAX_ARR_LEN = 40;

const float blur_offset[3] = {0.0, 2.0, 3.2307692308};


// --- INPUT PARAMS ---
uniform float sun_angle : hint_range(-6.28, 6.28) = 0.0;
uniform float sun_intensity = 0.05;
uniform int shadow_quality : hint_range(1, 999) = 4;
uniform int shadow_steps : hint_range(1, 999) = 16;
uniform float shadow_strength = 1.0;

uniform float blur_radius : hint_range(0.1, 200.0, 1.0) = 10.0;

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
	} else if (col_1.a > 0.0) {
		vec4 rval = mix(col_2, col_1, col_1.a);
		rval.a = max(col_1.a, col_2.a);
		return rval;
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

float sun_ang() {
	float adjust_angle = (PIT - sun_angle) + node_rotation;
	return (PI + adjust_angle) - (PIT / 4.0);
}

// Xor's gausian blur function 
// Link: https://xorshaders.weebly.com/tutorials/blur-shaders-5-part-2
// With minor modifications to account for UV tricks
vec4 texture_xorgaussian(sampler2D tex, vec2 uv, vec2 pixel_size, float blurriness, int iterations, int quality){
	float pi = 6.28;
	
	vec2 radius = blurriness / (1.0 / pixel_size).xy;
	vec4 blurred_tex = texture(tex, uv);
	
	for(float d = 0.0; d < pi; d += pi / float(iterations)){
		for( float i = 1.0 / float(quality); i <= 1.0; i += 1.0 / float(quality) ){
			vec2 directions = uv + vec2(cos(d), sin(d)) * radius * i;
			if (uv_clamp(directions)) { continue; }
			blurred_tex += texture(tex, directions);
		}
	}
	blurred_tex /= float(quality) * float(iterations) + 1.0;
	
	return blurred_tex;
}

void fragment() {
	vec2 P_UV = reverse_uv_scale(UV, true);
	vec2 TRANS = toCartesian(
		vec2(sun_ang(), sun_intensity), vec2(0.0)
	);
	vec2 BLUR_DIR = toCartesian(
		vec2(sun_ang(), 1.0), vec2(0.0)
	);
	vec2 ORTHO_BLUR_DIR = toCartesian(
		vec2(sun_ang() + (PI / 2.0), 1.0), vec2(0.0)
	);
	vec2 S_UV = (translate(TRANS) * vec3(P_UV, 1.0)).xy;
	vec4 S_COL = texture_scaled(TEXTURE, S_UV);
	S_COL.rgb = vec3(0.0);
	if (dropoff) {
		S_COL = texture_xorgaussian(TEXTURE, S_UV, TEXTURE_PIXEL_SIZE, blur_radius, shadow_steps, shadow_quality);
		S_COL.rgb = vec3(0.0);
	}
	
	S_COL.a *= shadow_strength;
	S_COL.a = clamp(S_COL.a, 0.0, 1.0);
	
	COLOR = S_COL;
}