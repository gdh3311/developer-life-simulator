shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 paint : source_color = vec4(0.44, 0.49, 0.58, 1.0);
uniform float daylight : hint_range(0, 1) = 1.0;
uniform float sunset : hint_range(0, 1) = 0.0;
uniform int surface_kind = 0; // 0 building, 1 ground, 2 road, 3 hills, 4 warning light
varying vec3 world_point;
varying vec3 world_normal;
varying float camera_distance;

float noise(vec2 tile) {
	return fract(sin(dot(tile, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = mat3(MODEL_MATRIX) * NORMAL;
	camera_distance = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float sun = max(0.0, dot(n, normalize(vec3(-0.67, 0.77, 0.42))));
	vec3 fill = mix(vec3(0.085, 0.13, 0.23), vec3(0.61, 0.72, 0.83), daylight);
	vec3 sunlight = mix(vec3(0.55, 0.48, 0.38), vec3(0.67, 0.30, 0.16), sunset);
	vec3 wall = paint.rgb * (fill + sun * sunlight * daylight);
	vec3 color = wall;
	if (surface_kind == 0 && abs(n.y) < 0.5) {
		vec2 grid = vec2(abs(n.z) > abs(n.x) ? world_point.x : world_point.z, world_point.y) / vec2(3.5, 3.2);
		vec2 tile = floor(grid);
		vec2 phase = fract(grid);
		vec2 aa = clamp(fwidth(grid), vec2(0.012), vec2(0.19));
		vec2 lower = smoothstep(vec2(0.14, 0.17) - aa, vec2(0.14, 0.17) + aa, phase);
		vec2 upper = 1.0 - smoothstep(vec2(0.85, 0.80) - aa, vec2(0.85, 0.80) + aa, phase);
		float glass_mask = lower.x * lower.y * upper.x * upper.y;
		float seed = noise(tile + (abs(n.z) > abs(n.x) ? world_point.zz : world_point.xx) * 0.17);
		float lit_room = step(mix(0.55, 0.93, daylight), seed);
		vec3 glass = mix(vec3(0.023, 0.045, 0.083), vec3(0.15, 0.28, 0.39) + max(n.z, 0.0) * 0.045, daylight);
		vec3 room_light = mix(vec3(0.27, 0.43, 0.59), vec3(0.91, 0.53, 0.23), noise(tile * 3.0));
		glass += room_light * lit_room * clamp(1.0 - daylight + sunset * 0.42, 0.0, 1.0);
		color = mix(wall * (0.90 + seed * 0.20), glass, glass_mask);
	} else if (surface_kind == 1) {
		float street_detail = noise(floor(world_point.xz * 0.7));
		color = wall * (0.45 + 0.20 * street_detail);
	} else if (surface_kind == 2) {
		float lamps = 1.0 - smoothstep(0.04, 0.16, abs(fract(world_point.x / 13.0) - 0.5));
		color = vec3(0.043, 0.053, 0.067) + vec3(0.52, 0.28, 0.09) * lamps * (1.0 - daylight);
	} else if (surface_kind == 3) {
		color = mix(vec3(0.049, 0.066, 0.13), vec3(0.37, 0.48, 0.60), daylight);
	} else if (surface_kind == 4) {
		color += vec3(0.60, 0.037, 0.022) * (1.0 - daylight);
	} else if (surface_kind == 5) {
		color = wall * (0.89 + noise(floor(world_point.xz * 1.3)) * 0.15);
	}
	vec3 haze = mix(vec3(0.04, 0.063, 0.136), vec3(0.58, 0.71, 0.84), daylight);
	haze = mix(haze, vec3(0.50, 0.32, 0.33), sunset * 0.76);
	float distance_fog = smoothstep(85.0, 780.0, camera_distance) * mix(0.52, 0.76, daylight);
	ALBEDO = mix(color, haze, distance_fog);
}
