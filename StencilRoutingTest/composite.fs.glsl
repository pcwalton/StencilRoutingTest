// composite.fs.glsl

#version 150

uniform sampler2DMS uTexture;
uniform float uTileSize;

out vec4 oFragColor;

void main() {
    ivec2 uv = ivec2(int(floor((gl_FragCoord.x - 0.5) / uTileSize)),
                     int(floor((gl_FragCoord.y - 0.5) / uTileSize)));
    oFragColor =
        texelFetch(uTexture, uv, 0) +
        texelFetch(uTexture, uv, 1) +
        texelFetch(uTexture, uv, 2) +
        texelFetch(uTexture, uv, 3);
}