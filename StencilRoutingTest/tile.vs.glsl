// tile.vs.glsl

#version 150

uniform vec2 uFramebufferSize;

in vec2 aPosition;

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
    gl_Position = vec4(vec2(x, y) / uFramebufferSize * 2.0 - 1.0, 0.0, 1.0);
}
