shader_type canvas_item;
// The CRT pass. It goes on the TextureRect in Main that shows the game's SubViewport, so it sees the picture
// after bloom. That texture is linear and holds values over 1 (lit colours are pushed there to bloom), so this
// pass always runs: it brings over-bright colours back into range without changing their hue, then converts
// to sRGB. With `enabled` off it does nothing else.

uniform bool enabled = true;
uniform float curve = 0.08;           // barrel distortion, 0 is flat. main.gd's _warp() reads this value
uniform float scanline = 0.26;        // how much one row in every three is darkened
uniform float vignette = 0.6;         // how much the corners are darkened
uniform float vignette_start = 0.58;  // share of the centre-to-corner radius that stays clear

const float FRAME_HEIGHT = 720.0;     // scanlines are counted in reference-frame pixels, not window pixels

// Where on the game picture the screen point uv looks. main.gd uses the same formula to move the mouse.
vec2 warp(vec2 uv) {
	vec2 d = uv - 0.5;
	return 0.5 + d * (1.0 + curve * dot(d, d)) / (1.0 + curve * 0.25);
}

// An over-bright colour scaled back so its largest channel is 1.
vec3 clip(vec3 c) {
	return c / max(1.0, max(c.r, max(c.g, c.b)));
}

vec3 to_srgb(vec3 c) {
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, lessThan(c, vec3(0.0031308)));
}

// Height of dark rows in [0, y): rows repeat every 3 px and the third one is dark.
float dark_rows(float y) {
	return floor(y / 3.0) + max(fract(y / 3.0) * 3.0 - 2.0, 0.0);
}

void fragment() {
	vec2 uv = enabled ? warp(UV) : UV;
	// Bilinear filter done by hand, because the clip has to happen before the blend: blending an over-bright
	// texel with a dark one first would spread it over its neighbours. It is written out here, not in a
	// function, because TEXTURE cannot be handed to a function without an error from the headless renderer.
	ivec2 last = textureSize(TEXTURE, 0) - 1;
	vec2 p = uv * vec2(last + 1) - 0.5;
	ivec2 i = ivec2(floor(p));
	vec2 f = fract(p);
	vec3 c = to_srgb(mix(
			mix(clip(texelFetch(TEXTURE, clamp(i, ivec2(0), last), 0).rgb),
				clip(texelFetch(TEXTURE, clamp(i + ivec2(1, 0), ivec2(0), last), 0).rgb), f.x),
			mix(clip(texelFetch(TEXTURE, clamp(i + ivec2(0, 1), ivec2(0), last), 0).rgb),
				clip(texelFetch(TEXTURE, clamp(i + ivec2(1, 1), ivec2(0), last), 0).rgb), f.x), f.y));
	if (enabled) {
		// black outside the curved picture, with a one-pixel soft edge
		vec2 px = fwidth(uv);
		vec2 inside = smoothstep(vec2(0.0), px, uv) * smoothstep(vec2(0.0), px, 1.0 - uv);
		c *= inside.x * inside.y;
		// scanlines, box-filtered so they stay even when the window is not a whole multiple of 720
		float y = UV.y * FRAME_HEIGHT;
		float h = fwidth(y);
		c *= 1.0 - scanline * (dark_rows(y + h * 0.5) - dark_rows(y - h * 0.5)) / h;
		// vignette: clear in the middle, then a straight ramp out to the corners
		float r = length(UV - 0.5) / 0.70710678;
		c *= 1.0 - vignette * clamp((r - vignette_start) / (1.0 - vignette_start), 0.0, 1.0);
	}
	COLOR = vec4(c, 1.0);
}
