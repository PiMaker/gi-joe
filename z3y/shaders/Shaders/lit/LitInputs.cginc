#if (PROP_MODE!=0) || !defined(OPTIMIZER_ENABLED)
    #define ENABLE_TRANSPARENCY
#endif

#if !defined(OPTIMIZER_ENABLED) // defined if texture gets used
    #define PROP_BUMPMAP
    #define PROP_METALLICMAP
    #define PROP_SMOOTHNESSMAP
    #define PROP_OCCLUSIONMAP
    #define PROP_EMISSIONMAP
    #define PROP_METALLICGLOSSMAP
    #define PROP_DETAILMAP
    #define PROP_ALEMISSIONMAP
    #define PROP_ENABLEVERTEXCOLOR
    #define PROP_ANISOTROPYMAP
    #define PROP_DISPLACEMENTMASK
    #define PROP_DISPLACEMENTNOISE
    #define PROP_SPECGLOSSMAP
    #define NEEDS_UV2
    #define PROP_THICKNESSMAP
#endif

#define NEEDS_UV1
#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META) || (PROP_MAINTEXUV==2) || (PROP_METALLICGLOSSMAPUV==2) || (PROP_SMOOTHNESSMAPUV==2) || (PROP_METALLICMAPUV==2) || (PROP_OCCLUSIONMAPUV==2) || (PROP_BUMPMAPUV==2) || (PROP_EMISSIONMAPUV==2) || (PROP_DETAILMAPUV==2) || (PROP_DISPLACEMENTMASKUV==2)
    #define NEEDS_UV2
#endif

#if defined(PROP_DETAILMAP) || (PROP_ENABLEANISOTROPY==1)
    #define PROP_BUMPMAP
#endif

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #define USE_FOG
#endif


#if !defined(UNITY_PASS_FORWARDBASE) && !defined(UNITY_PASS_META)
    #if defined(ENABLE_AUDIOLINK)
        #undef ENABLE_AUDIOLINK
    #endif
#endif

#if defined(ENABLE_AUDIOLINK)
//#if_EnableAudioLink
    #include "AudioLink.cginc"  
#endif


#define DECLARE_TEX2D_CUSTOM_SAMPLER(tex) SamplerState sampler##tex; Texture2D tex; uint tex##UV; float4 tex##_ST
#define DECLARE_TEX2D_CUSTOM(tex)                                    Texture2D tex; uint tex##UV; float4 tex##_ST

static float2 uvs[3];
uniform half _Cutoff;
uniform half _Mode;
uniform half _AlphaToMask;

uniform float _SpecularOcclusionSensitivity;
uniform float4 _SpecularDirection;



DECLARE_TEX2D_CUSTOM_SAMPLER(_MainTex);
 uniform float4 _MainTex_TexelSize;
uniform float _SuperSamplingBias;
uniform float4 _Color;
uniform half _Saturation;
uniform half _EnableVertexColor;


uniform float _NormalMapOrientation;
DECLARE_TEX2D_CUSTOM_SAMPLER(_BumpMap);
uniform half _BumpScale;
uniform int _HemiOctahedron;

#ifndef ENABLE_PACKED_MODE
DECLARE_TEX2D_CUSTOM(_MetallicMap);
#endif
uniform half _Metallic;

#ifndef ENABLE_PACKED_MODE

DECLARE_TEX2D_CUSTOM(_SmoothnessMap);

#endif
uniform float _GlossinessInvert;

uniform half _Glossiness;

#ifndef ENABLE_PACKED_MODE
DECLARE_TEX2D_CUSTOM(_OcclusionMap);
#endif
uniform half _Occlusion;


DECLARE_TEX2D_CUSTOM(_MetallicGlossMap);

uniform int _GSAA;
uniform half _specularAntiAliasingVariance;
uniform half _specularAntiAliasingThreshold;

uniform half4 _FresnelColor;
uniform float3 _SheenColor;
uniform float _SheenRoughness;
uniform int _SpecularWorkflow;
//uniform float3 _SpecColor; defined in unity cginc
DECLARE_TEX2D_CUSTOM(_SpecGlossMap);

uniform half _GetDominantLight;

uniform half _Reflectance;
uniform int _EnableAnisotropy;
uniform half _Anisotropy;
DECLARE_TEX2D_CUSTOM(_AnisotropyMap);
TextureCube<float4> _GIJoeReflProbe;
SamplerState sampler_GIJoeReflProbe;
float4 _GIJoeReflProbe_HDR;


sampler2D _GIJOE_INPUT;
DECLARE_TEX2D_CUSTOM_SAMPLER(_LM_GIJOE_0);
DECLARE_TEX2D_CUSTOM(_RNM0_GIJOE_0);
DECLARE_TEX2D_CUSTOM(_RNM1_GIJOE_0);
DECLARE_TEX2D_CUSTOM(_RNM2_GIJOE_0);
DECLARE_TEX2D_CUSTOM(_LM_GIJOE_1);
DECLARE_TEX2D_CUSTOM(_RNM0_GIJOE_1);
DECLARE_TEX2D_CUSTOM(_RNM1_GIJOE_1);
DECLARE_TEX2D_CUSTOM(_RNM2_GIJOE_1);
//SamplerState sampler_BakeryL0;
//DECLARE_TEX2D_CUSTOM(_BakeryL0);


uniform half _LightmapMultiplier;
uniform half _SpecularOcclusion;

uniform half _EnableEmission;
uniform int _EmissionMultBase;
DECLARE_TEX2D_CUSTOM(_EmissionMap);
uniform half3 _EmissionColor;



#ifdef ENABLE_PARALLAX
UNITY_DECLARE_TEX2D_NOSAMPLER(_ParallaxMap);
uniform float4 _ParallaxMap_ST;
uniform float _ParallaxSteps;
uniform float _ParallaxOffset;
uniform float _Parallax;
#endif

DECLARE_TEX2D_CUSTOM(_DetailMap);
uniform half _DetailAlbedoScale;
uniform half _DetailNormalScale;
uniform half _DetailSmoothnessScale;

#ifdef ENABLE_DISPLACEMENT
UNITY_DECLARE_TEX2D(_DisplacementMask);
uniform int _DisplacementMaskUV;
uniform float _DisplacementIntensity;

UNITY_DECLARE_TEX2D(_DisplacementNoise);
uniform int _RandomizePosition;
uniform float2 _DisplacementNoisePan;

#endif

float _Scale;
float _Power;
float _Distortion;
int _SubsurfaceScattering;
float4 _SubsurfaceTint;
DECLARE_TEX2D_CUSTOM(_ThicknessMap);



//sampler2D_float _CameraDepthTexture;
//float4 _CameraDepthTexture_TexelSize;

uniform float _LightProbeMethod;

uniform float _FlatShading;
float bakeryLightmapMode;

struct Lighting
{
    half3 color;
    float3 direction;
    half NoL;
    half LoH;
    float3 halfVector;
    half attenuation;
    half3 indirectDominantColor;
    half3 finalLight;
    half3 indirectDiffuse;
    half3 directSpecular;
    half3 indirectSpecular;
    float4 bakedDir;
};
static Lighting light;

struct Surface
{
    half4 albedo;
    half metallic;
    half oneMinusMetallic;
    half perceptualRoughness;
    half roughness;
    half occlusion;
    half3 emission;
};
static Surface surface;

struct Pixel
{
    float3 anisotropicT;
    float3 anisotropicB;
    float3 anisotropicDirection;
    float2 parallaxOffset;
    float3 worldPos;
    float3 worldNormal;
};

static Pixel pixel;

#if defined(VERTEXLIGHT_ON) && defined(UNITY_PASS_FORWARDBASE)
struct VertexLightInformation {
    float3 Direction[4];
    float3 ColorFalloff[4];
    float Attenuation[4];
};
static VertexLightInformation vertexLightInformation;
#endif

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "Lighting.cginc"
#include "LitLighting.cginc"

#ifdef UNITY_PASS_META
    #include "UnityMetaPass.cginc"
#endif

#if defined(BAKERY_SH) || defined(BAKERY_RNM) || defined(BAKERY_LMSPEC)
    #ifdef UNITY_PASS_FORWARDBASE
//#if_BAKERY_SH,_BAKERY_RNM
        #include "Bakery.cginc"
    #else
    #undef BAKERY_SH
    #undef BAKERY_RNM
    #undef BAKERY_LMSPEC
    #endif
#endif

#if defined(LOD_FADE_CROSSFADE)
    #if defined(UNITY_PASS_META)
        #undef LOD_FADE_CROSSFADE
    #endif
#endif