shader_type canvas_item;
// Overlay drawn on top of the monitor screen: vignette, faint scanlines, glass glare.

uniform float vignette = 0.38;
uniform float scanlines = 0.03;
uniform float line_count = 360.0;
uniform float glare = 0.06;

void fragment() {
	vec2 uv = UV;
	float dark = smoothstep(0.35, 0.8, distance(uv, vec2(0.5))) * vignette;
	dark += (0.5 + 0.5 * sin(uv.y * line_count * 6.2831853)) * scanlines;
	float light = (1.0 - smoothstep(0.0, 0.55, distance(uv * vec2(1.6, 1.0), vec2(0.35, 0.12)))) * glare;
	float a = clamp(dark + light, 0.0, 1.0);
	COLOR = vec4(vec3(light / max(a, 0.0001)), a);
}
