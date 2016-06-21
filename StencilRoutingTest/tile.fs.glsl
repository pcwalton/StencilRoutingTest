// tile.fs.glsl

#version 150

in vec2 vSourceUV;

out vec4 oFragColor;

void main() {
    oFragColor = vec4(vSourceUV / vec2(255.0, 255.0), 0.0, 0.0);
}
