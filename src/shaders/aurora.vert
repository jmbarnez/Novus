// Aurora Vertex Shader (LÖVE-compatible)
// Provides a `position` function and computes `screenPos` in pixel coordinates

// Declare extern uniforms used by the fragment shader so they exist on the combined shader
extern float time;
extern vec2 resolution;
extern vec3 color1;
extern vec3 color2;
extern vec3 color3;
extern vec4 textBounds;
extern vec4 tintColor;
extern mat4 transformMatrix;

varying vec2 screenPos;
varying vec2 texCoord;

vec4 position(mat4 transform_projection, vec4 vertex_position) {
    // Compute clip-space position
    vec4 pos = transform_projection * vertex_position;

    // Convert clip-space to normalized device coords, then to pixel coordinates
    vec2 ndc = pos.xy / pos.w;
    vec2 uv = ndc * 0.5 + 0.5;
    screenPos = uv * resolution;

    // Set texture coordinates for the fragment shader
    texCoord = uv;

    return pos;
}


