/* 
 * gizmo98 crt shader
 * Copyright (C) 2023 gizmo98
 *
 *   This program is free software; you can redistribute it and/or modify it
 *   under the terms of the GNU General Public License as published by the Free
 *   Software Foundation; either version 2 of the License, or (at your option)
 *   any later version.
 *
 * version 0.1
 * 24.04.2023
 * https://github.com/gizmo98/gizmo-crt-shader
 *
 * This shader tries to mimic a CRT without extensive use of scanlines and rgb pattern emulation.
 * It uses horizontal subpixel scaling and adds brightness dependent scanline patterns and allows 
 * fractional scaling. 
 *
 * CURVATE distorts the screen by BARREL_DISTORTION value
 * HORIZONTAL_BLUR simulates a bad composite signal which is neede for consoles like megadrive 
 * VERTICAL_BLUR vertical blur simulates N64 vertical blur 
 * INTERLACE enables a interlacing effect whih dims odd and even lines from frame to frame 
 * BGR_LCD_PATTERN most LCDs have a RGB pixel pattern. Enable BGR pattern with this switch
 * NTSC add NTSC effect
 * BRIGHTNESS makes scanlines more or less visible
 *
 * uses parts of RetroPie barrel distortation shader
 * uses parts of texture anti-aliasing shader https://www.shadertoy.com/view/ldsSRX
 * uses gold noise shader https://www.shadertoy.com/view/ltB3zD
 */

//#define CURVATE 
//#define INTERLACE
//#define HORIZONTAL_BLUR
#if defined HORIZONTAL_BLUR
//#define VERTICAL_BLUR
#endif
//define BGR_LCD_PATTERN
//#define NTSC

#define BRIGHTNESS 0.5
#define BARREL_DISTORTION 0.12

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

float PHI = 1.61803398874989484820459;  // Φ = Golden Ratio

float gold_noise(in vec2 xy, in float seed){
    return fract(tan(distance(xy*PHI, xy)*seed)*xy.x);
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
vec4 textureVertical(in vec2 uv){
    uv = magnify(uv,TextureSize.xy);
    uv = uv*TextureSize.xy + 0.5;

    COMPAT_PRECISION vec2 iuv = floor(uv);
    COMPAT_PRECISION vec2 fuv = uv - iuv;    
#ifdef HORIZONTAL_BLUR
    vec2 uv1 = vec2(iuv.x - 0.5 , uv.y - 0.5) / TextureSize.xy;
    vec2 uv2 = vec2(iuv.x + 0.5 , uv.y - 0.5) / TextureSize.xy;
    vec4 col1 = COMPAT_TEXTURE( Texture, uv1 );
    vec4 col2 = COMPAT_TEXTURE( Texture, uv2 );
    vec4 col = (col1 + col2) / vec4(2.0);
#ifdef VERTICAL_BLUR
    vec2 uv3 = vec2(iuv.x - 0.5 , uv.y + 0.5) / TextureSize.xy;
    vec2 uv4 = vec2(iuv.x + 0.5 , uv.y + 0.5) / TextureSize.xy;
    vec4 col3 = COMPAT_TEXTURE( Texture, uv3 );
    vec4 col4 = COMPAT_TEXTURE( Texture, uv4 );
    col = (((col3 + col4) / vec4(2.0)) + col) / vec4(2.0);
#endif
    return col;
#else
    uv = vec2(iuv.x - 0.5 , uv.y - 0.5) / TextureSize.xy;
    return COMPAT_TEXTURE( Texture, uv );
#endif
}

vec4 textureCRT(in vec2 uvr, in vec2 uvg, in vec2 uvb ){
    return vec4(textureVertical(uvr).r,textureVertical(uvg).g, textureVertical(uvb).b, 255);
}

float GetFuv(in vec2 uv){
    uv = uv*TextureSize.xy + 0.5;
    COMPAT_PRECISION vec2 iuv = floor(uv);
    COMPAT_PRECISION vec2 fuv = uv - iuv;
    return abs((fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0)).y - 0.5);
}

vec2 GetIuv(in vec2 uv){
    uv = uv*TextureSize.xy;

    COMPAT_PRECISION vec2 iuv = floor(uv);
    return iuv;
}

vec4 AddNoise(in vec4 col, in vec2 coord){
    /* Add some subpixel noise which simulates small CRT color variations */
    COMPAT_PRECISION float iGlobalTime = float(FrameCount)*0.025;
    return clamp(col + gold_noise(coord,sin(iGlobalTime))/32.0 - 1.0/64.0,0.0,1.0);
}

vec4 AddScanlines(in vec4 col, in vec2 coord){
    /* Add scanlines which are wider for dark colors.
       You cannot see scanlines if color is bright. */
    COMPAT_PRECISION float brightness = 1.0 / BRIGHTNESS * 0.05; 
    COMPAT_PRECISION float scale = (OutputSize.y / TextureSize.y) * 0.5;
    COMPAT_PRECISION float dim = brightness * scale;
    col.rgb -= dim * (abs(1.5* (1.0 - col.rgb) * abs(abs(GetFuv(coord) - 0.5))));
    return col;
}

vec4 Interlace(in vec4 col, in vec2 coord){
    COMPAT_PRECISION float interlacing_intensity = 0.015;
    COMPAT_PRECISION float scale = OutputSize.y / TextureSize.y;
    COMPAT_PRECISION float dim = interlacing_intensity * scale;
    COMPAT_PRECISION float pixel_brightness = abs(1.0 - (col.r + col.g + col.b) / 3.0 );
    COMPAT_PRECISION float framecount = floor(float(FrameCount));
    COMPAT_PRECISION float even = mod(framecount, 2.0); 
    if (even == 0.0)
        col.rgb -= dim * pixel_brightness * mod(GetIuv(coord),2.0).y;
    else
        col.rgb -= dim * pixel_brightness * (1.0 - mod(GetIuv(coord),2.0).y);
    return col;
}

vec3 XCoords(in float coord, in float y, in float factor){
#ifdef NTSC
    COMPAT_PRECISION float iGlobalTime = float(FrameCount)*0.025;
    COMPAT_PRECISION float ntsc_factor = 0.15 * sin(iGlobalTime * 100.0);
#else
    COMPAT_PRECISION float ntsc_factor = 0.0;
#endif 
    COMPAT_PRECISION float spread = 0.333;
    COMPAT_PRECISION vec3 coords = vec3(coord + y * ntsc_factor);
#ifdef BGR_LCD_PATTERN
    coords.b += spread * 2.0;
#else
    coords.r += spread * 2.0;
#endif
    coords.g += spread;
    coords *= factor;
    return coords;
}

float YCoord(in float coord, in float factor){
    return coord * factor;
}

void main()
{
#ifdef CURVATE    
    COMPAT_PRECISION float rescale = 1.0 - (0.25 * BARREL_DISTORTION);

    COMPAT_PRECISION vec2 scale = TextureSize / InputSize;
    COMPAT_PRECISION vec2 tex0 = TEX0.xy * scale;
    COMPAT_PRECISION vec2 texcoord = tex0 - vec2(0.5);
    COMPAT_PRECISION float rsq = texcoord.x * texcoord.x + texcoord.y * texcoord.y;
    texcoord = texcoord + (texcoord * (BARREL_DISTORTION * rsq));
    texcoord *= rescale;
    if (abs(texcoord.x) > 0.5 || abs(texcoord.y) > 0.5)
        FragColor = vec4(0.0);
    else
    {  
        texcoord += vec2(0.5);
        texcoord /= scale;
#else
    COMPAT_PRECISION vec2 texcoord = TEX0.xy;
#endif    
        COMPAT_PRECISION float aspect = 4.0 / 3.0;
        COMPAT_PRECISION vec2 fragCoord = texcoord.xy * OutputSize.xy;

        COMPAT_PRECISION vec2 uv = fragCoord.xy / TextureSize.xy * 1.5;
        COMPAT_PRECISION vec2 factor = TextureSize.xy / OutputSize.xy ;
        COMPAT_PRECISION float yCoord = YCoord(fragCoord.y, factor.y) ;
        COMPAT_PRECISION vec3  xCoords = XCoords(fragCoord.x, fract(yCoord), factor.y) * 1.0 / aspect;

        COMPAT_PRECISION vec2 coord_r = vec2(xCoords.r, yCoord) / TextureSize.xy;
        COMPAT_PRECISION vec2 coord_g = vec2(xCoords.g, yCoord) / TextureSize.xy;
        COMPAT_PRECISION vec2 coord_b = vec2(xCoords.b, yCoord) / TextureSize.xy;

        FragColor = textureCRT(coord_r,coord_g,coord_b);
        FragColor = AddNoise(FragColor, fragCoord);
#ifdef INTERLACE
        FragColor = Interlace(FragColor, coord_r);
#endif
        FragColor = AddScanlines(FragColor, coord_r);
#ifdef CURVATE
   }
#endif
}
#endif
