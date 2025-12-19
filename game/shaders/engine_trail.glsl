extern number time;
extern number seed;

float hash12(vec2 p)
{
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p)
{
  vec2 i = floor(p);
  vec2 f = fract(p);

  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));

  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p)
{
  float v = 0.0;
  float a = 0.6;
  for (int i = 0; i < 4; i++)
  {
    v += a * noise(p);
    p *= 2.02;
    a *= 0.5;
  }
  return v;
}

vec3 palette(float t)
{
  vec3 bright = vec3(0.00, 1.00, 1.00);
  vec3 mid = vec3(0.15, 0.85, 1.00);
  vec3 deep = vec3(0.00, 0.45, 0.85);

  vec3 col = mix(bright, mid, smoothstep(0.10, 0.65, t));
  col = mix(col, deep, smoothstep(0.55, 1.0, t));
  return col;
}

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen_coords)
{
  float along = clamp(uv.x, 0.0, 1.0);
  float across = clamp(uv.y, 0.0, 1.0);

  float center = 1.0 - abs(across - 0.5) * 2.0;
  center = clamp(center, 0.0, 1.0);

  float core = pow(center, 2.2);
  float edge = pow(center, 0.9);

  float head = pow(along, 1.35);

  float t = time;
  float n = fbm(vec2(along * 6.0 + seed * 0.02, t * 1.6 + seed));
  float wisps = smoothstep(0.2, 1.0, n);

  float flicker = 0.82 + 0.18 * sin(t * 24.0 + seed + along * 10.0);

  float alpha = head * (0.55 * edge + 0.85 * core) * (0.70 + 0.30 * wisps) * flicker;

  vec3 col = palette(1.0 - along);
  col += 0.25 * core * vec3(0.00, 1.00, 1.00);

  vec4 tex = Texel(texture, uv);
  vec3 outCol = col * alpha;

  return vec4(outCol, alpha) * color * tex;
}
