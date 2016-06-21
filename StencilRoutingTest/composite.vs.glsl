// composite.vs.glsl

#version 150

uniform int uDepth;

in vec2 aPosition;

void main() {
    gl_Position = vec4(aPosition, float(uDepth) / 128.0 - 1.0, 1.0);
}
