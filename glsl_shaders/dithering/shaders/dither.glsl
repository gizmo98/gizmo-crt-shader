/* 
 * gizmo98 color reduction shader
 * Copyright (C) 2023 gizmo98
 *
 *   This program is free software; you can redistribute it and/or modify it
 *   under the terms of the GNU General Public License as published by the Free
 *   Software Foundation; either version 2 of the License, or (at your option)
 *   any later version.
 *
 * version 0.1, 28.04.2023
 * ---------------------------------------------------------------------------------------
 * - initial commit
 * 
 * https://github.com/gizmo98/gizmo-crt-shader
 *
 * uses parts of texture anti-aliasing shader from Ikaros https://www.shadertoy.com/view/ldsSRX
 */

#pragma parameter BGR_LCD_PATTERN "BGR output pattern"         0.0 0.0 1.0 1.0
#pragma parameter COLOR_DEPTH "Color depth in Bits"            1.0 1.0 8.0 1.0
#pragma parameter DITHER_TUNE "Tune dithering"                 0.0 -64.0 64.0 1.0
#pragma parameter EGA_PALETTE "EGA palette"                    0.0 0.0 1.0 1.0

#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying 
#define COMPAT_ATTRIBUTE attribute 
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;

uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float BGR_LCD_PATTERN;
uniform COMPAT_PRECISION float COLOR_DEPTH;
uniform COMPAT_PRECISION float DITHER_TUNE;
uniform COMPAT_PRECISION float EGA_PALETTE;
#else
#define BGR_LCD_PATTERN 0.0
#define COLOR_DEPTH 7.0
#define DITHER_TUNE 0.0
#define EGA_PALETTE 0.0
#endif

void main()
{
    gl_Position = VertexCoord.x * MVPMatrix[0] + VertexCoord.y * MVPMatrix[1] + VertexCoord.z * MVPMatrix[2] + VertexCoord.w * MVPMatrix[3];
    TEX0.xy = TexCoord.xy;
}

#elif defined(FRAGMENT)

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float BGR_LCD_PATTERN;
uniform COMPAT_PRECISION float COLOR_DEPTH;
uniform COMPAT_PRECISION float DITHER_TUNE;
uniform COMPAT_PRECISION float EGA_PALETTE;
#endif

vec4 DitherPattern(vec4 col, vec2 coord)
{
    mat4 bayerMatrix; 
    bayerMatrix[0] = vec4(0.0, 8.0, 2.0, 10.0);
    bayerMatrix[1] = vec4(12.0, 4.0, 14.0, 6.0);
    bayerMatrix[2] = vec4(3.0, 11.0, 1.0, 9.0);
    bayerMatrix[3] = vec4(15.0, 7.0, 13.0, 5.0);
    
    ivec2 st = ivec2(fract(coord.xy / 4.0) * 4.0);
    float threshold = bayerMatrix[st.x][st.y];
    float multiplier = pow(2.0,8.0 - COLOR_DEPTH) - 1.0;
    
    threshold = (threshold / 15.0) - 0.5;
    threshold *= ((multiplier + DITHER_TUNE) / 255.0);
        
    col.rgb += threshold; 				           
    return col;
}

vec2 saturateA(in vec2 x)
{
    return clamp(x, 0.0, 1.0);
}

vec2 magnify(in vec2 uv, in vec2 res)
{
    uv *= res; 
    return (saturateA(fract(uv) / saturateA(fwidth(uv))) + floor(uv) - 0.5) / res.xy;
}
vec4 textureAA(in vec2 uv){
    uv = magnify(uv,TextureSize.xy);
    vec2 uv1 = uv*TextureSize.xy;

    COMPAT_PRECISION vec2 iuv = floor(uv1);
    //COMPAT_PRECISION vec2 fuv = uv - iuv;  
      
    //uv = (uv - 0.5) / TextureSize.xy;
    vec4 col = COMPAT_TEXTURE( Texture, uv );
    
    col = DitherPattern( col , iuv - 0.5);
    return col;
}

vec4 textureSubSample(in vec2 uvr, in vec2 uvg, in vec2 uvb ){
    return vec4(textureAA(uvr).r,textureAA(uvg).g, textureAA(uvb).b, 255);
}

vec3 XCoords(in float coord, in float factor){
    COMPAT_PRECISION float iGlobalTime = float(FrameCount)*0.025;
    COMPAT_PRECISION float spread = 0.333;
    COMPAT_PRECISION vec3 coords = vec3(coord);
    if(BGR_LCD_PATTERN == 1.0)
        coords.r += spread * 2.0;
    else
        coords.b += spread * 2.0;
    coords.g += spread;
    coords *= factor;
    return coords;
}

float YCoord(in float coord, in float factor){
    return coord * factor;
}

vec4 ColorDepthReduction(vec4 col)
{
    float divider = pow(2.0,COLOR_DEPTH) - 1.0; 
    col.rgb *= divider;
    col.rgb = floor(col.rgb) + step(0.5, fract(col.rgb));
    col.rgb /= divider;
    return col;
}

vec4 EGAPalette(vec4 col)
{    
    vec3 c = col.rgb * 4.0;
    if (c.rgb == vec3(0.0,0.0,0.0) ||
        c.rgb == vec3(1.0,1.0,1.0) || 
        c.rgb == vec3(2.0,2.0,2.0) ||
        c.rgb == vec3(3.0,3.0,3.0) ||
        c.rgb == vec3(2.0,1.0,0.0))
        col.rgb = col.rgb;
    else if (c.rgb == vec3(2.0,2.0,0.0))
        col.rgb = vec3(2.0,1.0,0.0);
    else if (c.r == 0.0 || c.g == 0.0 || c.b == 0.0)
        col.rgb = step(1.0,col.rgb) * 2.0;
    else if (c.r == 3.0 || c.g == 3.0 || c.b == 3.0)
        col.rgb = 1.0 + step(3.0,col.rgb) * 2.0;
    return col;
}

void main()
{
    vec2 texcoord = TEX0.xy;
    
    COMPAT_PRECISION vec2 fragCoord = texcoord.xy * OutputSize.xy;
    COMPAT_PRECISION vec2 factor = TextureSize.xy / OutputSize.xy ;
    COMPAT_PRECISION float yCoord = YCoord(fragCoord.y, factor.y) ;
    COMPAT_PRECISION vec3  xCoords = XCoords(fragCoord.x, factor.x);

    COMPAT_PRECISION vec2 coord_r = vec2(xCoords.r, yCoord) / TextureSize.xy;
    COMPAT_PRECISION vec2 coord_g = vec2(xCoords.g, yCoord) / TextureSize.xy;
    COMPAT_PRECISION vec2 coord_b = vec2(xCoords.b, yCoord) / TextureSize.xy;

    FragColor = textureAA(coord_r);
    FragColor = ColorDepthReduction(FragColor);
    if (EGA_PALETTE == 1.0)
        FragColor = EGAPalette(FragColor);
}
#endif
