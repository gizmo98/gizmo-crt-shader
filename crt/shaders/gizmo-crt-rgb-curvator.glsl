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

vec4 textureVertical(in vec2 uv){
    uv = uv*TextureSize.xy + 0.5;

    COMPAT_PRECISION vec2 iuv = floor(uv);
    COMPAT_PRECISION vec2 fuv = uv - iuv;
    fuv = fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0);
    uv = iuv + fuv;

    uv = vec2(iuv.x - 0.5, uv.y - 0.5) / TextureSize.xy;
    return COMPAT_TEXTURE( Texture, uv );
}

vec4 textureCRT(in vec2 uvr, in vec2 uvg, in vec2 uvb ){
    return vec4(textureVertical(uvr).r,textureVertical(uvg).g, textureVertical(uvb).b, 255);
}

vec4 FixColor(in vec4 col){
    return smoothstep(0.0,1.0,col);
}

vec4 AddNoise(in vec4 col, in vec2 coord){
    float iGlobalTime = float(FrameCount)*0.025;
    return clamp(col + gold_noise(coord,sin(iGlobalTime))/32.0 - 1.0/64.0,0.0,1.0);
}

float GetFuv(in vec2 uv){
    uv = uv*TextureSize.xy + 0.5;

    COMPAT_PRECISION vec2 iuv = floor(uv);
    COMPAT_PRECISION vec2 fuv = uv - iuv;
    return abs((fuv*fuv*fuv*(fuv*(fuv*6.0-15.0)+10.0)).y - 0.5);
}

vec4 AddLines(in vec4 col, in vec2 coord){
    COMPAT_PRECISION float scale = OutputSize.y / TextureSize.y;
    COMPAT_PRECISION float dim = 0.05 * scale;
    col.rgb -= dim * abs(1.0 - (col.r + col.g + col.b) / 3.0 ) * abs(abs(0.5 - GetFuv(coord) ));
    return col;
}

vec3 XCoords(in float coord, in float factor){
    COMPAT_PRECISION float spread = 0.33;
    COMPAT_PRECISION vec3 coords = vec3(coord);
    coords.b += spread * 2.0;
    coords.g += spread;
    coords *= factor;
    return coords;
}

float YCoord(in float coord, in float factor){
    return coord * factor;
}

void main()
{
    COMPAT_PRECISION float BARREL_DISTORTION = 0.12;
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
    
        COMPAT_PRECISION float aspect = 3.0 / 4.0;
        COMPAT_PRECISION vec2 fragCoord = texcoord.xy * OutputSize.xy;

        COMPAT_PRECISION vec2 uv = fragCoord.xy / TextureSize.xy * 1.5;
        COMPAT_PRECISION vec2 factor = TextureSize.xy / OutputSize.xy ;
        COMPAT_PRECISION float yCoord = YCoord(fragCoord.y, factor.y) ;
        COMPAT_PRECISION vec3  xCoords = XCoords(fragCoord.x, factor.y) * aspect;

        COMPAT_PRECISION vec2 coord_r = vec2(xCoords.r, yCoord) / TextureSize.xy;
        COMPAT_PRECISION vec2 coord_g = vec2(xCoords.g, yCoord) / TextureSize.xy;
        COMPAT_PRECISION vec2 coord_b = vec2(xCoords.b, yCoord) / TextureSize.xy;

        FragColor = textureCRT(coord_r,coord_g,coord_b);
        //FragColor = FixColor(FragColor);
        FragColor = AddNoise(FragColor, fragCoord);
        FragColor = AddLines(FragColor, coord_r);
   }
}
#endif
