// Aurora Vertex Shader
attribute vec4 vertexPosition;
attribute vec2 vertexTexCoord;
attribute vec4 vertexColor;

uniform mat4 transformMatrix;
uniform vec4 tintColor;

varying vec2 texCoord;
varying vec4 color;
varying vec2 screenPos;

void main() {
    texCoord = vertexTexCoord;
    color = vertexColor * tintColor;

    gl_Position = transformMatrix * vertexPosition;
    screenPos = gl_Position.xy;
}
