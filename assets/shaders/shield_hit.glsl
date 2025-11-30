extern number hit_intensity;
extern number hit_time;
extern vec3 shield_color;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 tex = Texel(texture, texture_coords) * color;
    if (tex.a <= 0.001) {
        return tex;
    }

    float pulse = 0.5 + 0.5 * sin(hit_time * 40.0);
    float glow = hit_intensity * (0.7 + 0.3 * pulse);

    vec3 tinted = mix(tex.rgb, shield_color, glow);
    float extraAlpha = glow * 0.4;

    return vec4(tinted, min(1.0, tex.a + extraAlpha));
}
