#include "LitInputs.cginc"

struct appdata
{
    float4 vertex : POSITION;
    float3 normal : NORMAL;

    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;

    #ifdef NEEDS_UV2
        float2 uv2 : TEXCOORD2;
    #endif
    

    #if !defined(UNITY_PASS_SHADOWCASTER)

        #if defined(ENABLE_REFLECTIONS) || defined(ENABLE_SPECULAR_HIGHLIGHTS) || defined (PROP_BUMPMAP) || defined(ENABLE_MATCAP) || defined(ENABLE_PARALLAX) || defined (UNITY_PASS_META) || defined(BAKERY_INCLUDED)
            half4 tangent : TANGENT;
        #endif
    
        #ifdef PROP_ENABLEVERTEXCOLOR
            half4 color : COLOR;
        #endif
    #endif

    uint vertexId : SV_VertexID;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 pos : SV_POSITION;

    float4 texcoord0 : TEXCOORD0;
    
    #ifdef NEEDS_UV2
        float4 texcoord1 : TEXCOORD1;
    #endif



    #if !defined(UNITY_PASS_SHADOWCASTER)

        #if defined(ENABLE_REFLECTIONS) || defined(ENABLE_SPECULAR_HIGHLIGHTS) || defined (PROP_BUMPMAP) || defined(ENABLE_MATCAP) || defined (UNITY_PASS_META)
            float3 bitangent : TEXCOORD2;
            float3 tangent : TEXCOORD3;
        #endif

        float3 worldNormal : TEXCOORD4;

        float4 worldPos : TEXCOORD5;
    
        UNITY_SHADOW_COORDS(6)

        #ifdef USE_FOG
            UNITY_FOG_COORDS(7)
        #endif

        #if defined(ENABLE_PARALLAX) || defined(BAKERY_RNM)
            float3 viewDirForParallax : TEXCOORD8;
        #endif

        #ifdef PROP_ENABLEVERTEXCOLOR
            centroid half4 color : COLOR;
        #endif

        #ifdef CENTROID_NORMAL
            centroid float3 centroidWorldNormal : TEXCOORD9;
        #endif

        #if defined(LIGHTMAP_SHADOW_MIXING) && defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN) && defined(LIGHTMAP_ON)
            float4 screenPos : TEXCOORD10;
        #endif

    #endif
    

    UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};

// UNITY_INSTANCING_BUFFER_START(Props)
//     //UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
// UNITY_INSTANCING_BUFFER_END(Props)

v2f vert(appdata v)
{
    v2f o;
    UNITY_INITIALIZE_OUTPUT(v2f, o);

    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    #ifdef ENABLE_DISPLACEMENT

        float2 dUV = 0;
        switch(_DisplacementMaskUV)
        {
            case(0):
                dUV = v.uv0;
                break;
            case(1):
                dUV = v.uv1;
                break;
            #ifdef NEEDS_UV2
            case(2):
                dUV = v.uv2;
                break;
            #endif
        }

        float3 offset = 0;

        UNITY_BRANCH
        if(_RandomizePosition)
        {
            float2 seed = unity_ObjectToWorld._m03_m23;
            offset = lerp( 0.0 , 1.0 , frac( ( sin( dot( seed, float2( 12.9898,78.233 ) ) ) * 43758.55 ) )).x;
        }

        #ifdef PROP_DISPLACEMENTMASK
            float4 dMask = _DisplacementMask.SampleLevel(sampler_DisplacementMask, dUV, 0);
        #else 
            float4 dMask = 1;
        #endif
        

        #ifdef PROP_DISPLACEMENTNOISE
            float2 dPan = _Time.xx * _DisplacementNoisePan;
            float4 dNoise = _DisplacementNoise.SampleLevel(sampler_DisplacementNoise, dUV + dPan + offset.xx, 0);
        #else 
            float4 dNoise = 0.5;
        #endif

        float3 displacement = (dNoise.xyz - 0.5) * 2;

        displacement *= dMask * _DisplacementIntensity;
        v.vertex.xyz += displacement;
    #endif


    #ifdef UNITY_PASS_META
    o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);
    #else
        #if !defined(UNITY_PASS_SHADOWCASTER)
            o.pos = UnityObjectToClipPos(v.vertex);
        #endif
    #endif


    o.texcoord0.xy = v.uv0;
    o.texcoord0.zw = v.uv1;

    #ifdef NEEDS_UV2
    o.texcoord1.xy = v.uv2;
    #endif
    

    
    #if !defined(UNITY_PASS_SHADOWCASTER)
        float3 worldNormal = UnityObjectToWorldNormal(v.normal);

        #if defined(ENABLE_REFLECTIONS) || defined(ENABLE_SPECULAR_HIGHLIGHTS) || defined (PROP_BUMPMAP) || defined(ENABLE_MATCAP)
            half3 tangent = UnityObjectToWorldDir(v.tangent);
            half3 bitangent = cross(tangent, worldNormal) * v.tangent.w;
            o.bitangent = bitangent;
            o.tangent = tangent;
        #endif

        #if defined(LIGHTMAP_SHADOW_MIXING) && defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN) && defined(LIGHTMAP_ON)
            o.screenPos = ComputeScreenPos(o.pos);
        #endif

        o.worldNormal = worldNormal;
        #ifdef CENTROID_NORMAL
            o.centroidWorldNormal = worldNormal;
        #endif
        o.worldPos = mul(unity_ObjectToWorld, v.vertex);

        #ifdef USE_FOG
            UNITY_TRANSFER_FOG(o, o.pos);
        #endif

         #if defined(ENABLE_PARALLAX) || defined(BAKERY_RNM)
            TANGENT_SPACE_ROTATION;
            o.viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
        #endif

        #ifdef PROP_ENABLEVERTEXCOLOR
            o.color = v.color;
        #endif
        
        UNITY_TRANSFER_SHADOW(o, o.texcoord0.zw);
        
    #else
        o.pos = UnityClipSpaceShadowCasterPos(v.vertex, v.normal);
        o.pos = UnityApplyLinearShadowBias(o.pos);
        TRANSFER_SHADOW_CASTER_NOPOS(o, o.pos);
    #endif

    


    return o;
}

#include "LitFunctions.cginc"
#include "LitFrag.cginc"