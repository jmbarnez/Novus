extern number time;
extern number progress;
extern vec3 base_color;

// Simple hash and value noise for breakup
float hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p.x + p.y) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec4 effect(vec4 color, Image texture, vec2 texcoord, vec2 screen_coords) {
    float t = clamp(progress, 0.0, 1.0);

    // Centered UV in [-0.5, 0.5]
    vec2 p = texcoord - vec2(0.5);
    float r = length(p) * 2.0; // 0 at center, ~1 near mesh edge

    // Expanding ring from center
    float inner = t * 0.1;
    float outer = inner + 0.8;

    float edge_in  = smoothstep(inner, inner + 0.12, r);
    float edge_out = 1.0 - smoothstep(outer, outer + 0.15, r);
    float ring = edge_in * edge_out;

    // Add noisy breakup so the ring is not perfectly smooth
    float n = noise(p * 10.0 + vec2(time * 1.5, -time * 1.2));
    ring *= mix(0.6, 1.4, n);

    // Fade out over time
    float alpha = ring * (1.0 - t);

    // Color grading: bright core, slightly hotter edge
    vec3 core  = base_color;
    vec3 edge  = base_color * vec3(1.6, 1.25, 0.9);
    float mixFactor = clamp(1.0 - r, 0.0, 1.0);
    vec3 col = mix(edge, core, mixFactor);

    return vec4(col, alpha) * color;
}
