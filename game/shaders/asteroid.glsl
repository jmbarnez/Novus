extern number seed;
extern number localRadius;
extern number noiseScale;
extern vec2 localMin;
extern vec2 localSize;

float hash12(vec2 p)
{
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p)
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
  float a = 0.58;
  mat2 m = mat2(1.7, 1.2, -1.2, 1.7);

  for (int i = 0; i < 5; i++)
  {
    v += a * valueNoise(p);
    p = m * p;
    a *= 0.5;
  }

  return v;
}

float heightField(vec2 p, vec2 seedOff, float s)
{
  vec2 q = vec2(
    fbm(p * (s * 0.75) + seedOff + vec2(2.2, 5.1)),
    fbm(p * (s * 0.75) + seedOff + vec2(7.4, 1.6))
  );

  vec2 pw = p + (q - 0.5) * (localRadius * 0.10);

  float base = fbm(pw * s + seedOff);
  float mid = fbm(pw * (s * 2.0) + seedOff + 11.1);
  float detail = fbm(pw * (s * 4.2) + seedOff + 29.7);

  float n1 = valueNoise(pw * (s * 1.55) + seedOff + 3.7);
  float ridged = 1.0 - abs(n1 * 2.0 - 1.0);
  ridged = ridged * ridged;

  float craterField = fbm(pw * (s * 1.1) + seedOff + 17.3);
  float craterMask = smoothstep(0.55, 0.88, craterField);

  float h = 0.55 * base + 0.28 * mid + 0.17 * detail;
  h -= craterMask * (0.18 + 0.22 * ridged);
  h += (ridged - 0.5) * 0.06;

  return h;
}

vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen_coords)
{
  float r = max(localRadius, 1.0);
  vec2 ls = max(localSize, vec2(1.0));
  vec2 p = localMin + uv * ls;

  float s = max(noiseScale, 0.0001);
  vec2 seedOff = vec2(seed * 0.017, seed * 0.031);

  float h = heightField(p, seedOff, s);

  float eps = max(0.8, r * 0.018);
  float hx = heightField(p + vec2(eps, 0.0), seedOff, s) - heightField(p - vec2(eps, 0.0), seedOff, s);
  float hy = heightField(p + vec2(0.0, eps), seedOff, s) - heightField(p - vec2(0.0, eps), seedOff, s);
  vec3 n = normalize(vec3(-hx, -hy, 1.0));

  vec3 lightDir = normalize(vec3(0.55, -0.35, 0.75));
  float diff = clamp(dot(n, lightDir), 0.0, 1.0);
  float ambient = 0.36;
  float shade = ambient + (1.0 - ambient) * diff;

  float radial = clamp(length(p) / r, 0.0, 1.0);
  float rim = smoothstep(0.60, 1.08, radial);
  shade *= 1.0 - 0.33 * rim;

  float albedoVar = (h - 0.5);
  vec3 albedo = color.rgb * (0.88 + 0.22 * albedoVar);

  float spec = pow(clamp(n.z, 0.0, 1.0), 10.0) * 0.06 * diff;
  vec3 outCol = albedo * shade + spec;

  vec4 tex = Texel(texture, uv);
  return vec4(outCol, color.a) * tex;
}
