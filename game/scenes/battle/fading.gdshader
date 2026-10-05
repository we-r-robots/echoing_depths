shader_type canvas_item;
// The Fading: drains colour from the edges inward toward Fading grey (master palette fade ramp).
uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

void fragment() {
	vec4 c = texture(screen_tex, SCREEN_UV);
	float l = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	vec3 g = l < 0.18 ? vec3(0.16, 0.16, 0.19) : (l < 0.4 ? vec3(0.29, 0.29, 0.31) : (l < 0.62 ? vec3(0.47, 0.47, 0.49) : vec3(0.65, 0.65, 0.68)));
	g = mix(vec3(l), g, 0.6);
	vec2 d = abs(SCREEN_UV - 0.5) * 2.0;
	float e = max(d.x * 0.9, d.y);
	float edge = clamp((e - (1.05 - level * 1.3)) * 4.0, 0.0, 1.0);
	float amt = clamp(level * 0.45 + edge * 0.85, 0.0, 0.92);
	COLOR = vec4(mix(c.rgb, g, amt), 1.0);
}
