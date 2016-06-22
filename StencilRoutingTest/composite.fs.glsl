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

#define BLEND(fragColor, sourceTexture, tileTexture, tileUV, sampleStart, sampleCount) \
    for (int i = sampleStart; i < sampleCount; i++) { \
        vec2 sourceUV = texelFetch(tileTexture, tileUV, i - sampleStart).st; \
        if (sourceUV == vec2(0.0)) \
            return; \
        vec4 source = texture(sourceTexture, sourceUV); \
        fragColor = fragColor * (1.0 - source.a) + source * source.a; \
    }

void main() {
    ivec2 uv = ivec2(int(floor((gl_FragCoord.x - 0.5) / uTileSize)),
                     int(floor((gl_FragCoord.y - 0.5) / uTileSize)));
    oFragColor = vec4(0.0);
    BLEND(oFragColor, uSourceTexture, uTexture0, uv, 0 * 8, min(uDepth, 1 * 8));
    BLEND(oFragColor, uSourceTexture, uTexture1, uv, 1 * 8, min(uDepth, 2 * 8));
    BLEND(oFragColor, uSourceTexture, uTexture2, uv, 2 * 8, min(uDepth, 3 * 8));
    BLEND(oFragColor, uSourceTexture, uTexture3, uv, 3 * 8, min(uDepth, 4 * 8));
    BLEND(oFragColor, uSourceTexture, uTexture4, uv, 4 * 8, min(uDepth, 5 * 8));
    BLEND(oFragColor, uSourceTexture, uTexture5, uv, 5 * 8, min(uDepth, 6 * 8));
    BLEND(oFragColor, uSourceTexture, uTexture6, uv, 6 * 8, min(uDepth, 7 * 8));
    BLEND(oFragColor, uSourceTexture, uTexture7, uv, 7 * 8, min(uDepth, 8 * 8));
}