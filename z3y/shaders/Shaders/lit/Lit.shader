Shader "z3y/lit"
{

    Properties
    {
        wAg6H2wQzc7UbxaL ("Is Locked", Int) = 0
        [ToggleUI] _BakeUnityKeywords ("Bake Unity Keywords", Int) = 0


        [Enum(Opaque, 0, Cutout, 1, Fade, 2, Transparent, 3)] _Mode("Rendering Mode", Int) = 0
            [Enum(Off, 0, On, 1, Sharpened, 2)] _AlphaToMask ("Alpha To Coverage", Int) = 0
            _Cutoff ("Alpha Cuttoff", Range(0, 1)) = 0.5

        
        _MainTex ("Base Map", 2D) = "white" {}
            [Enum(UV 0, 0, UV 1, 1, UV 2, 2, Triplanar, 4, Stochastic, 5, SuperSampling, 6)] _MainTexUV ("UV Type", Int) = 0
            _MainTex_STAnimated("_MainTex_ST", Int) = 1
            _Color ("Base Color", Color) = (1,1,1,1)
            _Saturation ("Saturation", Range(-1,1)) = 0
            _SuperSamplingBias ("SuperSampling Bias", Range(-2,1)) = -1
            [ToggleUI] _EnableVertexColor ("Vertex Colors Mulitply Base", Int) = 0
      

        [Toggle(ENABLE_PACKED_MODE)] _EnablePackedMode ("Packed Mode", Float) = 1 

        _MetallicGlossMap ("Mask Map:Metallic(R), Occlusion(G), Detail Mask(B), Smoothness(A)", 2D) = "white" {}
            [Enum(UV 0 Locked, 0, UV 1, 1, UV 2, 2, UV 0 Unlocked, 3, Triplanar, 4, Stochastic, 5)] _MetallicGlossMapUV ("UV Type", Int) = 0

        _SmoothnessMap ("Smoothness Map", 2D) = "white" {}
            [Enum(UV 0 Locked, 0, UV 1, 1, UV 2, 2, UV 0 Unlocked, 3, Triplanar, 4, Stochastic, 5)]  _SmoothnessMapUV ("UV Type", Int) = 0
            [ToggleUI] _GlossinessInvert ("Invert Smoothness", Float) = 0

        _MetallicMap ("Metallic Map", 2D) = "white" {}
            [Enum(UV 0 Locked, 0, UV 1, 1, UV 2, 2, UV 0 Unlocked, 3, Triplanar, 4, Stochastic, 5)]  _MetallicMapUV ("UV Type", Int) = 0

        _OcclusionMap ("Occlusion Map", 2D) = "white" {}
            [Enum(UV 0 Locked, 0, UV 1, 1, UV 2, 2, UV 0 Unlocked, 3, Triplanar, 4, Stochastic, 5)]  _OcclusionMapUV ("UV Type", Int) = 0

        _Metallic ("Metallic", Range(0,1)) = 0
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Occlusion ("Occlusion", Range(0,1)) = 0


        [Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
            _BumpScale ("Bump Scale", Range(0,10)) = 0
            [Enum(OpenGL, 0, Direct3D, 1)] _NormalMapOrientation ("Orientation", Int) = 0
            [Enum(UV 0 Locked, 0, UV 1, 1, UV 2, 2, UV 0 Unlocked, 3, Triplanar, 4, Stochastic, 5)] _BumpMapUV ("UV Type", Int) = 0
            [ToggleUI] _HemiOctahedron ("Hemi Octahedron", Int) = 0


        [ToggleUI] _EnableEmission ("Emission", Float) = 0
            _EmissionMap ("Emission Map", 2D) = "white" {}
            [ToggleUI] _EmissionMultBase ("Multiply Base", Int) = 0
            [HDR] _EmissionColor ("Emission Color", Color) = (0,0,0)
            [Enum(UV 0 Locked, 0, UV 1, 1, UV 2, 2, UV 0 Unlocked, 3, Triplanar, 4, Stochastic, 5)]  _EmissionMapUV ("UV Type", Int) = 0


        [ToggleUI] _EnableAnisotropy ("Anisotropy", Int) = 0
            _Anisotropy ("Anisotropy", Range(-1,1)) = 0
            _AnisotropyMap ("Anisotropy Direction Map:Bitangent(R), Tangent(G)", 2D) = "white" {}


        [Toggle(ENABLE_SPECULAR_HIGHLIGHTS)] _SpecularHighlights("Specular Highlights", Float) = 1
        [Toggle(ENABLE_REFLECTIONS)] _GlossyReflections("Reflections", Float) = 1
            [Enum(Metallic, 0, Specular, 1)] _SpecularWorkflow ("Workflow", Int) = 0
            _SpecGlossMap ("Specular Color", 2D) = "white" {}
            _SpecColor ("Specular Color", Color) = (0.5,0.5,0.5,0.5)
            [Enum(UV 0 Locked, 0, UV 1, 1, UV 2, 2, UV 0 Unlocked, 3, Triplanar, 4, Stochastic, 5)]  _SpecGlossMapUV ("UV Type", Int) = 0
            _SheenColor ("Sheen Color", Color) = (0.5,0.5,0.5,0.5)
            _SheenRoughness ("Sheen Roughness", Range(0.004,1)) = 0.004
            _FresnelColor ("Tint", Color) = (1,1,1,1)
            _Reflectance ("Reflectance", Range(0,1)) = 0.5
            _GIJoeReflProbe ("GI Joe Reflection Probe", Cube) = "blackCube" {}


        [ToggleUI] _GSAA ("Geometric Specular AA", Int) = 0
            [PowerSlider(3)] _specularAntiAliasingVariance ("Variance", Range(0.0, 1.0)) = 0.15
            [PowerSlider(3)] _specularAntiAliasingThreshold ("Threshold", Range(0.0, 1.0)) = 0.1
            

        [Toggle(ENABLE_BICUBIC_LIGHTMAP)] _BicubicLightmap ("Bicubic Lightmap", Float) = 0
        [ToggleUI] _LightProbeMethod ("Non-linear Light Probe SH", Int) = 0
        _LightmapMultiplier ("Lightmap Multiplier", Range(0, 2)) = 1
        _SpecularOcclusion ("Indirect Specular Occlusion", Range(0, 1)) = 0
        _SpecularOcclusionSensitivity ("Occlusion Sensitivity", Range(0, 1)) = 0


        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp ("Blend Op", Int) = 0
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOpAlpha ("Blend Op Alpha", Int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Source Blend", Int) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Destination Blend", Int) = 0

        [Enum(Off, 0, On, 1)] _ZWrite ("ZWrite", Int) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Int) = 4
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Int) = 2


        [Toggle(ENABLE_PARALLAX)] _EnableParallax ("Parallax", Int) = 0
            _Parallax ("Height Scale", Range (0, 0.2)) = 0.02
            _ParallaxMap ("Height Map", 2D) = "black" {}
            [IntRange] _ParallaxSteps ("Parallax Steps", Range(1,50)) = 25
            _ParallaxOffset ("Parallax Offset", Range(-1, 1)) = 0


        _DetailMap ("Detail Map:Desaturated Albedo(R), Normal Y(G), Smoothness(B), Normal X(A)", 2D) = "linearGrey" {}
            [Enum(UV 0 Locked, 0, UV 1, 1, UV 2, 2, UV 0 Unlocked, 3, Triplanar, 4, Stochastic, 5)]  _DetailMapUV ("UV Type", Int) = 0
            _DetailAlbedoScale ("Albedo Scale", Range(0.0, 2.0)) = 1
            _DetailNormalScale ("Normal Scale", Range(0.0, 2.0)) = 0
            _DetailSmoothnessScale ("Smoothness Scale", Range(0.0, 2.0)) = 1
        
        
        [Toggle(ENABLE_AUDIOLINK)] _EnableAudioLink ("Audio Link", Float) = 0
            _AudioTexture ("Audio Link Render Texture", 2D) = "black" {}
            _ALSmoothing ("Audio Link Smoothing", Range(0, 1)) = 0.5

            [Enum(Bass, 0, Low Mids, 1, High Mids, 2, Treble, 3)] _ALEmissionBand ("Audio Link Emission Band", Int) = 0
            [Enum(Disabled, 0, Gradient, 1, Path, 2, Intensity, 3)] _ALEmissionType ("Audio Link Emission Type", Int) = 0
            _ALEmissionMap ("Audio Link Emission Path & Mask: Path(G), Mask(A)", 2D) = "white" {}


        [Toggle(BAKERY_LMSPEC)] _BAKERY_LMSPEC ("Baked Specular Highlights ", Int) = 0
        [Toggle(BAKERY_SH)] _BAKERY_SH ("Enable SH", Float) = 0
        [Toggle(BAKERY_SHNONLINEAR)] _BAKERY_SHNONLINEAR ("SH non-linear mode", Int) = 0
        [Toggle(BAKERY_RNM)] _BAKERY_RNM ("Enable RNM", Int) = 0
        [Enum(BAKERYMODE_DEFAULT, 0, BAKERYMODE_VERTEXLM, 1, BAKERYMODE_RNM, 2, BAKERYMODE_SH, 3)] bakeryLightmapMode ("bakeryLightmapMode", Int) = 0
            _SpecularDirection ("Non-Directional Lightmap Specular Direction", Vector) = (0, 0, 0, 1)
            _RNM0("RNM0", 2D) = "black" {}
            _RNM1("RNM1", 2D) = "black" {}
            _RNM2("RNM2", 2D) = "black" {}


        [Toggle(BAKERY_SH_GIJOE)] _BAKERY_SH_GIJOE ("Enable SH GI Joe", Float) = 0
            _GIJOE_INPUT("GIJOE Input", 2D) = "black" {}
                _LM_GIJOE_0("LM GIJOE 0", 2D) = "black" {}
            _RNM0_GIJOE_0("RNM0 GIJOE 0", 2D) = "black" {}
            _RNM1_GIJOE_0("RNM1 GIJOE 0", 2D) = "black" {}
            _RNM2_GIJOE_0("RNM2 GIJOE 0", 2D) = "black" {}
                _LM_GIJOE_1("LM GIJOE 1", 2D) = "black" {}
            _RNM0_GIJOE_1("RNM0 GIJOE 1", 2D) = "black" {}
            _RNM1_GIJOE_1("RNM1 GIJOE 1", 2D) = "black" {}
            _RNM2_GIJOE_1("RNM2 GIJOE 1", 2D) = "black" {}


        [Toggle(CENTROID_NORMAL)] _CentroidNormal ("Centroid Normal", Int) = 0


        [Toggle(LOD_FADE_CROSSFADE)] _LodCrossFade ("Dithered LOD Cross-Fade", Int) = 0
            [ToggleUI] _FlatShading ("Flat Shading", Float) = 0


        [Toggle(ENABLE_DISPLACEMENT)] _EnableDisplacement ("Vertex Displacement", Int) = 0
            _DisplacementMask ("Displacement Mask:XYZ (RGB)", 2D) = "white" {}
            _DisplacementIntensity ("Displacement Intensity", Float) = 0
            _DisplacementScale ("Displacement Scale", Float) = 1
            [Enum(UV 0 , 0, UV 1, 1, UV 2, 2)] _DisplacementMaskUV ("Displacement UV", Int) = 0

            _DisplacementNoise ("Displacement Noise", 2D) = "white" {}
            _DisplacementNoisePan ("Noise Pan Speed XY", Vector) = (1, 1, 0)
            [ToggleUI] _RandomizePosition ("Randomize Panning", Int) = 0


            [ToggleUI] _SubsurfaceScattering ("Subsurface Scattering", Int) = 0
                _Scale ("Scale", Float) = 1
                _Power ("Power", Float) = 1
                _ThicknessMap ("Thickness Map", 2D) = "white" {}
                [Enum(UV 0 Locked, 0, UV 1, 1, UV 2, 2, UV 0 Unlocked, 3)]  _ThicknessMapUV ("UV Type", Int) = 0
                _SubsurfaceTint ("Subsurface Tint", Color) = (1,1,1,1)




    }

    SubShader
    {

        Tags { "RenderType"="Opaque" "Queue"="Geometry" }

        Pass
        {
            Name "FORWARD"
            Tags { "LightMode"="ForwardBase" }
            
            ZWrite [_ZWrite]
            Cull [_Cull]
            ZTest [_ZTest]
            AlphaToMask [_AlphaToMask]
            BlendOp [_BlendOp], [_BlendOpAlpha]
            Blend [_SrcBlend] [_DstBlend]

            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma fragmentoption ARB_precision_hint_fastest
            #pragma multi_compile_fwdbase
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma require 2darray

            #pragma shader_feature_local ENABLE_SPECULAR_HIGHLIGHTS
            #pragma shader_feature_local ENABLE_REFLECTIONS
            #pragma shader_feature_local ENABLE_PACKED_MODE
            #pragma shader_feature_local ENABLE_BICUBIC_LIGHTMAP
            #pragma shader_feature_local ENABLE_PARALLAX
            #pragma shader_feature_local ENABLE_AUDIOLINK
            #pragma shader_feature_local BAKERY_SHNONLINEAR
            #pragma shader_feature_local CENTROID_NORMAL
            #pragma shader_feature_local ENABLE_DISPLACEMENT

            #pragma shader_feature_local BAKERY_SH
            #pragma shader_feature_local BAKERY_RNM
            #pragma shader_feature_local BAKERY_LMSPEC

            #pragma shader_feature_local BAKERY_SH_GIJOE


            #ifndef UNITY_PASS_FORWARDBASE
                #define UNITY_PASS_FORWARDBASE
            #endif

            #include "LitPass.cginc"
            ENDCG
        }


        Pass
        {
            Name "FWDADD"
            Tags { "LightMode"="ForwardAdd" }
            Fog { Color (0,0,0,0) }
            ZWrite Off
            BlendOp [_BlendOp], [_BlendOpAlpha]
            Blend One One
            Cull [_Cull]
            ZTest [_ZTest]
            AlphaToMask [_AlphaToMask]

            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma shader_feature_local ENABLE_SPECULAR_HIGHLIGHTS
            #pragma shader_feature_local ENABLE_PACKED_MODE
            #pragma shader_feature_local ENABLE_PARALLAX
            #pragma shader_feature_local CENTROID_NORMAL
            #pragma shader_feature_local ENABLE_DISPLACEMENT


            #ifndef UNITY_PASS_FORWARDADD
                #define UNITY_PASS_FORWARDADD
            #endif

            #include "LitPass.cginc"
            ENDCG
        }


        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            AlphaToMask Off
            ZWrite On
            Cull [_Cull]
            ZTest LEqual

            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment ShadowCasterfrag
            #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            #pragma multi_compile _ LOD_FADE_CROSSFADE
            #pragma skip_variants FOG_LINEAR FOG_EXP FOG_EXP2
            
            #pragma shader_feature_local ENABLE_DISPLACEMENT

            #ifndef UNITY_PASS_SHADOWCASTER
                #define UNITY_PASS_SHADOWCASTER
            #endif

            #include "LitPass.cginc"
            ENDCG
        }

        Pass
        {
            Name "META"
            Tags { "LightMode"="Meta" }
            Cull Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local ENABLE_PACKED_MODE
            #pragma shader_feature EDITOR_VISUALIZATION
            #pragma shader_feature_local ENABLE_AUDIOLINK
            


            #ifndef UNITY_PASS_META
                #define UNITY_PASS_META
            #endif

            #include "LitPass.cginc"
            ENDCG
        }

    }
    FallBack "Mobile/Unlit (Supports Lightmap)"
    CustomEditor "z3y.LitShaderEditor"
}