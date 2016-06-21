// composite.fs.glsl

#version 150

uniform sampler2DMS uTexture0;
uniform sampler2DMS uTexture1;
uniform sampler2DMS uTexture2;
uniform sampler2DMS uTexture3;
uniform sampler2DMS uTexture4;
uniform sampler2DMS uTexture5;
uniform sampler2DMS uTexture6;
uniform sampler2DMS uTexture7;
uniform sampler2D uSourceTexture;
uniform float uTileSize;
uniform int uDepth;

out vec4 oFragColor;

void main() {
    ivec2 uv = ivec2(int(floor((gl_FragCoord.x - 0.5) / uTileSize)),
                     int(floor((gl_FragCoord.y - 0.5) / uTileSize)));
    oFragColor = vec4(0.0);
    for (int i = 0 * 8; i < min(uDepth, 1 * 8); i++)
        oFragColor += texture(uSourceTexture, texelFetch(uTexture0, uv, i - 0 * 8).st);
    for (int i = 1 * 8; i < min(uDepth, 2 * 8); i++)
        oFragColor += texture(uSourceTexture, texelFetch(uTexture1, uv, i - 1 * 8).st);
    for (int i = 2 * 8; i < min(uDepth, 3 * 8); i++)
        oFragColor += texture(uSourceTexture, texelFetch(uTexture2, uv, i - 2 * 8).st);
    for (int i = 3 * 8; i < min(uDepth, 4 * 8); i++)
        oFragColor += texture(uSourceTexture, texelFetch(uTexture3, uv, i - 3 * 8).st);
    for (int i = 4 * 8; i < min(uDepth, 5 * 8); i++)
        oFragColor += texture(uSourceTexture, texelFetch(uTexture4, uv, i - 4 * 8).st);
    for (int i = 5 * 8; i < min(uDepth, 6 * 8); i++)
        oFragColor += texture(uSourceTexture, texelFetch(uTexture5, uv, i - 5 * 8).st);
    for (int i = 6 * 8; i < min(uDepth, 7 * 8); i++)
        oFragColor += texture(uSourceTexture, texelFetch(uTexture6, uv, i - 6 * 8).st);
    for (int i = 7 * 8; i < min(uDepth, 8 * 8); i++)
        oFragColor += texture(uSourceTexture, texelFetch(uTexture7, uv, i - 7 * 8).st);
}