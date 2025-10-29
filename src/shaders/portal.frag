// Portal fragment shader for warp gate effect
extern float time;
extern vec2 center;   // screen-space center in pixels
extern float radius;  // radius in pixels
extern float intensity; // overall intensity multiplier
extern float isActive; // 1.0 = active (blue), 0.0 = inactive (reddish)

vec2 rotate(vec2 p, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

float rand(vec2 co){
    return fract(sin(dot(co.xy, vec2(12.9898,78.233))) * 43758.5453);
}

float fbm(vec2 p){
    float v = 0.0;
    float a = 0.5;
    for(int i=0;i<4;i++){
        v += a * rand(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

vec4 effect(vec4 color, Image tex, vec2 tex_coords, vec2 screen_coords){
    // Compute normalized coords relative to portal center
    vec2 toCenter = screen_coords - center;
    float dist = length(toCenter);

    // Soft outer cutoff
    float outer = radius * 1.05;
    if(dist > outer) discard;

    float nd = dist / radius; // 0..1 (1 at portal edge)

    // Swirl based on distance and time
    float angle = atan(toCenter.y, toCenter.x);
    float swirl = 0.6 * (1.0 - nd) * sin(time * 1.3 + nd * 6.0);
    vec2 sw = rotate(toCenter, swirl);

    // Noise / detail
    float noise = fbm((sw / radius) * 3.0 + vec2(time * 0.2, time * -0.17));
    float rings = smoothstep(0.0, 1.0, 1.0 - nd) * (0.6 + 0.4 * sin(10.0 * nd + time * 2.0));

    // Base color mixes active/inactive palettes
    vec3 activeCol = vec3(0.22, 0.6, 1.0);
    vec3 inactiveCol = vec3(1.0, 0.35, 0.12);
    vec3 base = mix(inactiveCol, activeCol, isActive);

    // Color variation across radius
    float glow = pow(1.0 - nd, 2.0);
    float detail = clamp(noise * 0.6 + rings * 0.4, 0.0, 1.0);

    // Solid portal: whole circle takes base color (active blue / inactive red)
    vec3 col = base;
    // Optional subtle variation: keep a faint palette shimmer
    col += palette(noise + time * 0.05, vec3(0.0), vec3(0.15), vec3(1.0), vec3(0.0)) * 0.08;
    // Subtle rim brightening for definition
    float rim = smoothstep(0.98, 0.9, nd);
    col = mix(col, vec3(1.0, 1.0, 1.0), rim * 0.25);

    // Solid alpha across the circle with mild edge roll-off
    float alpha = clamp(0.9 * intensity + 0.1 * isActive, 0.0, 1.0);
    alpha *= smoothstep(outer, radius * 0.88, dist) + (1.0 - smoothstep(radius * 0.35, radius * 0.9, dist));
    alpha = clamp(alpha, 0.0, 1.0);

    return vec4(col * color.rgb, alpha * color.a);
}


