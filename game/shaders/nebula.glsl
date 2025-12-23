extern number time;
extern number seed;
extern vec2 resolution;
extern vec2 offset;

float hash21(vec2 p)
{
  p = fract(p * vec2(123.34, 345.45) + seed * 0.123);
  p += dot(p, p + 34.345 + seed * 0.97);
  return fract(p.x * p.y);
}

vec2 hash22(vec2 p)
{
  vec2 q = vec2(
    dot(p, vec2(127.1, 311.7)),
    dot(p, vec2(269.5, 183.3))
  );
  return fract(sin(q + seed * 10.0) * 43758.5453);
}

float valueNoise(vec2 p)
{
  vec2 i = floor(p);
  vec2 f = fract(p);

  vec2 u = f * f * (3.0 - 2.0 * f);

  vec2 ga = normalize(hash22(i) - 0.5);
  vec2 gb = normalize(hash22(i + vec2(1.0, 0.0)) - 0.5);
  vec2 gc = normalize(hash22(i + vec2(0.0, 1.0)) - 0.5);
  vec2 gd = normalize(hash22(i + vec2(1.0, 1.0)) - 0.5);

  float va = dot(ga, f - vec2(0.0, 0.0));
  float vb = dot(gb, f - vec2(1.0, 0.0));
  float vc = dot(gc, f - vec2(0.0, 1.0));
  float vd = dot(gd, f - vec2(1.0, 1.0));

  float v = mix(mix(va, vb, u.x), mix(vc, vd, u.x), u.y);
  return 0.5 + 0.5 * v;
}

float fbm(vec2 p)
{
  float v = 0.0;
  float a = 0.58;
  mat2 m = mat2(1.6, 1.2, -1.2, 1.6);

  for (int i = 0; i < 6; i++)
  {
    v += a * valueNoise(p);
    p = m * p;
    a *= 0.5;
  }

  return v;
}

vec2 warp(vec2 p, float t)
{
  float w1 = fbm(p * 0.55 + vec2(0.0, t));
  float w2 = fbm(p * 0.55 + vec2(5.2, -t * 0.9));
  return vec2(w1, w2);
}

vec3 hsv2rgb(vec3 c)
{
  vec3 rgb = clamp(abs(mod(c.x * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
  rgb = rgb * rgb * (3.0 - 2.0 * rgb);
  return c.z * mix(vec3(1.0), rgb, c.y);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
  vec2 res = max(resolution, vec2(1.0));
  vec2 uv = (screen_coords + offset) / res;

  // Aspect-corrected centered coordinates for a large, distant nebula.
  vec2 p = (uv - 0.5) * vec2(res.x / res.y, 1.0);
  p += vec2(sin(seed * 2.1), cos(seed * 1.7)) * 0.22;

  float t = time * 0.02;

  // Large-scale domain warp to break up repetition while keeping motion slow.
  vec2 w = warp(p, t);
  vec2 pw = p + (w - 0.5) * 1.25;

  float base = fbm(pw * 1.05 + seed * 0.17);
  float detail = fbm(pw * 2.85 + 6.0 + seed * 0.41);

  // Distant look: softer contrast and fewer hard edges.
  float density = smoothstep(0.22, 0.78, base);
  density *= 0.78 + 0.30 * detail;
  density = pow(density, 1.10);

  // Concentrate into one large "nebula" with a natural, irregular edge.
  vec2 center = vec2(sin(seed * 0.9 + 1.4), cos(seed * 1.1 + 2.2)) * 0.10;
  float edgeNoise = fbm(p * 1.10 + vec2(seed * 0.37, seed * 0.53));
  float r = length(p - center) + (edgeNoise - 0.5) * 0.28;

  // Single smooth fade with a wide falloff to avoid visible banding.
  float mask = 1.0 - smoothstep(0.40, 1.30, r);
  mask = pow(clamp(mask, 0.0, 1.0), 1.05);

  float fade = smoothstep(0.0, 1.0, mask);
  float edgeFactor = smoothstep(0.60, 1.05, r);
  density *= mask;
  density = mix(density, fade, edgeFactor);  // near the edge, bias strongly to a single ramp
  density = mix(density, fade, 0.50);        // global smoothing toward a flat fade

  // Introduce large-scale variation so some sectors stay faint.
  float intensityMod = 0.55 + 0.45 * fbm(pw * 0.65 + 80.0 + seed * 0.9);
  density *= intensityMod;
  density = smoothstep(0.0, 1.0, density);   // kill residual stepping

  float hue = fbm(pw * 1.8 + 12.3 + seed * 1.7);

  // Palette varies per-seed in HSV space for smoother, distinct nebula colors.
  float baseHue = fract(sin(seed * 12.345) * 43758.5453);
  float accentHue = fract(baseHue + 0.32 + sin(seed * 4.1) * 0.08);
  float contrastHue = fract(accentHue + 0.42 + cos(seed * 2.7) * 0.05);

  vec3 deep = hsv2rgb(vec3(baseHue, 0.55, 0.18));
  vec3 midA = hsv2rgb(vec3(fract(baseHue + 0.06), 0.48, 0.36));
  vec3 midB = hsv2rgb(vec3(accentHue, 0.62, 0.45));
  vec3 glow = hsv2rgb(vec3(contrastHue, 0.70, 0.85));

  vec3 col = mix(midA, midB, smoothstep(0.25, 0.85, hue));
  float finalAlpha = pow(density, 1.35);
  col = mix(deep, col, finalAlpha);          // keep far edges close to background

  // Gentle internal highlights (kept subtle to feel far away).
  float highlight = pow(fbm(pw * 4.4 + 40.0 + seed * 2.3), 2.6);
  float ridge = pow(smoothstep(0.55, 0.95, detail), 2.1);
  float highlightScale = 0.28 + 0.35 * intensityMod; // highlights tied to local intensity
  col += glow * highlight * 0.30 * highlightScale * density;
  col += glow * ridge * 0.12 * highlightScale * density;

  // Vignette helps sell scale and keeps the center readable.
  float v = 1.0 - smoothstep(0.15, 1.05, length(p * 0.9));
  v = 0.25 + 0.75 * v;
  col *= 0.7 + 0.3 * v;

  // Subtle dithering to reduce banding in dark gradients.
  float dither = (hash21(screen_coords) - 0.5) / 255.0;
  col += dither;

  col *= 1.35;
  col = clamp(col, 0.0, 1.0);

  float alpha = clamp(finalAlpha * 1.15 * v, 0.0, 1.0);
  return vec4(col, alpha) * color;
}
