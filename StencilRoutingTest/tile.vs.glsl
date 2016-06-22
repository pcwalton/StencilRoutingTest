// tile.vs.glsl

#version 150

uniform vec2 uFramebufferSize;

in vec3 aPosition;
in vec2 aSourceUV;

out vec2 vSourceUV;

void main() {
    int which = gl_VertexID % 6;
    float x;
    if (which == 1 || which == 2 || which == 5)
        x = floor(aPosition.x * uFramebufferSize.x);
    else
        x = ceil(aPosition.x * uFramebufferSize.x);
    float y;
    if (which == 0 || which == 1 || which == 3)
        y = floor(aPosition.y * uFramebufferSize.y);
    else
        y = ceil(aPosition.y * uFramebufferSize.y);
    vSourceUV = aSourceUV;
    gl_Position = vec4(vec2(x, y) / uFramebufferSize * 2.0 - 1.0, aPosition.z / 0.5, 1.0);
}
