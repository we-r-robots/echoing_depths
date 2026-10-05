shader_type canvas_item;
// Battle unit sprite: hit flash, tint, 1px outline (ability ready / echo rim), KO fade, palette swap.

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(0.0);
uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform vec4 gray_dark : source_color = vec4(0.12, 0.11, 0.23, 1.0);
uniform vec4 gray_light : source_color = vec4(0.65, 0.65, 0.68, 1.0);
uniform int swap_n = 0;
uniform vec4 swap_from[5] : source_color;
uniform vec4 swap_to[5] : source_color;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.01) {
		for (int i = 0; i < 5; i++) {
			if (i >= swap_n) break;
			if (distance(c.rgb, swap_from[i].rgb) < 0.03) { c.rgb = swap_to[i].rgb; }
		}
		if (gray > 0.0) {
			float l = dot(c.rgb, vec3(0.3, 0.55, 0.15));
			vec3 g = l < 0.22 ? gray_dark.rgb : (l < 0.5 ? mix(gray_dark.rgb, gray_light.rgb, 0.5) : gray_light.rgb);
			c.rgb = mix(c.rgb, g, gray);
		}
		c.rgb = mix(c.rgb, flash_color.rgb, flash);
	} else if (outline_color.a > 0.0) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
			+ texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
		if (a > 0.01) { c = vec4(outline_color.rgb, outline_color.a); }
	}
	COLOR = c * COLOR;
}
