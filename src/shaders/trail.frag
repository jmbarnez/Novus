extern vec2 center;
extern float size;
extern float time;

vec4 effect(vec4 color, Image texture, vec2 tex_coords, vec2 screen_coords) {
    // Distance from fragment to particle center in screen space
    float dist = distance(screen_coords, center);

    // Normalize by size and compute a smooth falloff (soft glow)
    float n = dist / max(1.0, size);
    float falloff = pow(max(0.0, 1.0 - n), 1.6);

    // Add a subtle animated noise/flicker
    float flicker = 0.95 + 0.05 * sin(time * 8.0 + screen_coords.x * 0.02);

    // Final color uses the passed-in color multiplied by falloff and flicker
    return vec4(color.rgb * flicker, color.a * falloff);
}


