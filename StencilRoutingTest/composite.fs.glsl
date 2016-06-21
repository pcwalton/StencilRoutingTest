// composite.fs.glsl

#version 150

uniform sampler2DMS uTexture0;
uniform sampler2DMS uTexture1;
uniform sampler2DMS uTexture2;
uniform sampler2DMS uTexture3;
uniform float uTileSize;

out vec4 oFragColor;

void main() {
    ivec2 uv = ivec2(int(floor((gl_FragCoord.x - 0.5) / uTileSize)),
                     int(floor((gl_FragCoord.y - 0.5) / uTileSize)));
    oFragColor = vec4(0.0);
    for (int i = 0; i < 8; i++)
        oFragColor += texelFetch(uTexture0, uv, i);
}