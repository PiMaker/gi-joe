// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles

#define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))

void initUVs(v2f i)
{
    uvs[0] = i.texcoord0.xy;

    
    uvs[1] = i.texcoord0.zw;
    

    #ifdef NEEDS_UV2
        uvs[2] = i.texcoord1.xy;
    #endif
}

// custom uv sample texture
// type 0: uv0 and locked to maintex tiling
// type 1: uv1 unlocked
// type 2: uv2 unlocked
// type 3: uv0 unlocked
// type 4: triplanar
// type 5: uv0 stochastic
// type 6: uv0 super sampled



float2 hash2D2D (float2 s)
{
    //magic numbers
    return frac(sin(glsl_mod(float2(dot(s, float2(127.1,311.7)), dot(s, float2(269.5,183.3))), 3.14159))*43758.5453);
}

float4 SampleTexture(Texture2D tex, float4 st, sampler s, int type)
{
    float4 sampledTexture = 0;

    switch(type)
    {
        case 0:
            sampledTexture = tex.Sample(s, uvs[0] * _MainTex_ST.xy + _MainTex_ST.zw + pixel.parallaxOffset);
            break;
        case 1:
            sampledTexture = tex.Sample(s, uvs[1] * st.xy + st.zw + pixel.parallaxOffset);
            break;
        case 2:
            sampledTexture = tex.Sample(s, uvs[2] * st.xy + st.zw + pixel.parallaxOffset);
            break;
        case 3:
            sampledTexture = tex.Sample(s, uvs[0] * st.xy + st.zw + pixel.parallaxOffset);
            break;
        case 4:
            float3 n = abs(pixel.worldNormal);
            float3 w = n / (n.x + n.y + n.z);
            float4 tzy = tex.Sample(s, pixel.worldPos.zy * st.xy + st.zw);
            float4 txz = tex.Sample(s, pixel.worldPos.xz * st.xy + st.zw);
            float4 txy = tex.Sample(s, pixel.worldPos.xy * st.xy + st.zw);
            sampledTexture = tzy * w.x + txz * w.y + txy * w.z;
            break;
        case 5:
            // https://www.reddit.com/r/Unity3D/comments/dhr5g2/i_made_a_stochastic_texture_sampling_shader/
            //triangle vertices and blend weights
            //BW_vx[0...2].xyz = triangle verts
            //BW_vx[3].xy = blend weights (z is unused)
            float4x3 BW_vx;

            //uv transformed into triangular grid space with UV scaled by approximation of 2*sqrt(3)
            float2 skewUV = mul(float2x2 (1.0 , 0.0 , -0.57735027 , 1.15470054), (uvs[0] * st.xy + st.zw) * 3.464);

            //vertex IDs and barycentric coords
            float2 vxID = float2 (floor(skewUV));
            float3 barry = float3 (frac(skewUV), 0);
            barry.z = 1.0-barry.x-barry.y;

            BW_vx = ((barry.z>0) ? 
                float4x3(float3(vxID, 0), float3(vxID + float2(0, 1), 0), float3(vxID + float2(1, 0), 0), barry.zyx) :
                float4x3(float3(vxID + float2 (1, 1), 0), float3(vxID + float2 (1, 0), 0), float3(vxID + float2 (0, 1), 0), float3(-barry.z, 1.0-barry.y, 1.0-barry.x)));

            //calculate derivatives to avoid triangular grid artifacts
            float2 dxu = ddx(uvs[0] * st.xy + st.zw);
            float2 dyu = ddy(uvs[0] * st.xy + st.zw);

            //blend samples with calculated weights
            sampledTexture =    mul(tex.SampleGrad(s, (uvs[0] * st.xy + st.zw) + hash2D2D(BW_vx[0].xy), dxu, dyu), BW_vx[3].x) + 
                                mul(tex.SampleGrad(s, (uvs[0] * st.xy + st.zw) + hash2D2D(BW_vx[1].xy), dxu, dyu), BW_vx[3].y) + 
                                mul(tex.SampleGrad(s, (uvs[0] * st.xy + st.zw) + hash2D2D(BW_vx[2].xy), dxu, dyu), BW_vx[3].z);
            break;
        case 6:
            // not sure what this does, I copied it directly from bgolus
            // https://bgolus.medium.com/sharper-mipmapping-using-shader-based-supersampling-ed7aadb47bec
            // per pixel partial derivatives
            float2 dx = ddx(uvs[0] * st.xy + st.zw + pixel.parallaxOffset);
            float2 dy = ddy(uvs[0] * st.xy + st.zw + pixel.parallaxOffset);
            // manually calculate the per axis mip level, clamp to 0 to 1
            // and use that to scale down the derivatives
            
            dx *= saturate( 0.5 * log2(dot(dx * _MainTex_TexelSize.zw, dx * _MainTex_TexelSize.zw)) );
            dy *= saturate( 0.5 * log2(dot(dy * _MainTex_TexelSize.zw, dy * _MainTex_TexelSize.zw)) );
                
            // rotated grid uv offsets
            float2 uvOffsets = float2(0.125, 0.375);
            float4 offsetUV = float4(0.0, 0.0, 0.0, _SuperSamplingBias);
            // supersampled using 2x2 rotated grid
            offsetUV.xy = (uvs[0] * st.xy + st.zw + pixel.parallaxOffset) + uvOffsets.x * dx + uvOffsets.y * dy;
            sampledTexture = tex.SampleBias(s, offsetUV.xy, offsetUV.w);
            offsetUV.xy = (uvs[0] * st.xy + st.zw + pixel.parallaxOffset) - uvOffsets.x * dx - uvOffsets.y * dy;
            sampledTexture += tex.SampleBias(s, offsetUV.xy, offsetUV.w);
            offsetUV.xy = (uvs[0] * st.xy + st.zw + pixel.parallaxOffset) + uvOffsets.y * dx - uvOffsets.x * dy;
            sampledTexture += tex.SampleBias(s, offsetUV.xy, offsetUV.w);
            offsetUV.xy = (uvs[0] * st.xy + st.zw + pixel.parallaxOffset) - uvOffsets.y * dx + uvOffsets.x * dy;
            sampledTexture += tex.SampleBias(s, offsetUV.xy, offsetUV.w);
            sampledTexture *= 0.25;
            break;

    }

    return sampledTexture;
}

float4 SampleTexture(Texture2D tex, float4 st, int type)
{
    return SampleTexture(tex, st, sampler_MainTex, type);
}

float4 SampleTexture(Texture2D tex, float4 st)
{
    return SampleTexture(tex, st, sampler_MainTex, 3);
}

float4 SampleTexture(Texture2D tex)
{
    return SampleTexture(tex, float4(1,1,0,0), sampler_MainTex, 3);
}





half calcAlpha(half alpha)
{
    UNITY_BRANCH
    if(_Mode == 1)
    {
        switch(_AlphaToMask)
        {
            case 0:
                clip(alpha - _Cutoff);
                break;
            case 2:
                alpha = (alpha - _Cutoff) / max(fwidth(alpha), 0.0001) + 0.5;
                break;
        }
    }

    return alpha;
}

void getMainTex(inout half4 mainTex, half2 parallaxOffset, half4 vertexColor)
{
    //mainTex = MAIN_TEX(_MainTex, sampler_MainTex, uvs[_MainTexUV], _MainTex_ST);
    mainTex = SampleTexture(_MainTex, _MainTex_ST, _MainTexUV);

    

    surface.albedo = mainTex * _Color;

    #ifdef PROP_ENABLEVERTEXCOLOR
        surface.albedo.rgb *= _EnableVertexColor ? GammaToLinearSpace(vertexColor) : 1;
    #endif
}

void initNormalMap(half4 normalMap, inout half3 bitangent, inout half3 tangent, inout half3 normal, half4 detailNormalMap, inout float3 tangentNormal)
{

    if(!_HemiOctahedron) tangentNormal = UnpackScaleNormal(normalMap, _BumpScale);
    else
    {
        half2 f = normalMap.ag * 2 - 1;
        // https://twitter.com/Stubbesaurus/status/937994790553227264
        normalMap.xyz = float3(f.x, f.y, 1 - abs(f.x) - abs(f.y));
        float t = saturate(-normalMap.z);
        normalMap.xy += normalMap.xy >= 0.0 ? -t : t;
        normalMap.xy *= _BumpScale;
        tangentNormal = normalize(normalMap);
    }

    #if defined(PROP_DETAILMAP)
        detailNormalMap.g = 1-detailNormalMap.g;
        half3 detailNormal = UnpackScaleNormal(detailNormalMap, _DetailNormalScale);
        tangentNormal = BlendNormals(tangentNormal, detailNormal);
    #endif




    tangentNormal.g *= _NormalMapOrientation ? 1 : -1;

    half3 calcedNormal = normalize
    (
		tangentNormal.x * tangent +
		tangentNormal.y * bitangent +
		tangentNormal.z * normal
    );


    normal = calcedNormal;
    tangent = normalize(cross(normal, bitangent));
    bitangent = normalize(cross(normal, tangent));

    #if defined(PROP_ANISOTROPYMAP)
        pixel.anisotropicDirection = float3(_AnisotropyMap.Sample(sampler_MainTex, (uvs[0] * _AnisotropyMap_ST.xy + _AnisotropyMap_ST.zw)).rg, 1);
        pixel.anisotropicT = normalize(tangent * pixel.anisotropicDirection);
        pixel.anisotropicB = normalize(cross(normal, pixel.anisotropicT));
    #else
        pixel.anisotropicT = tangent;
        pixel.anisotropicB = bitangent;
    #endif
}


bool isInMirror()
{
    return unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
}

float3 ACESFilm(float3 x)
{
    float a = 2.51f;
    float b = 0.03f;
    float c = 2.43f;
    float d = 0.59f;
    float e = 0.14f;
    return saturate((x*(a*x+b))/(x*(c*x+d)+e));
}

half BlendMode_Overlay(half base, half blend)
{
	return (base <= 0.5) ? 2*base*blend : 1 - 2*(1-base)*(1-blend);
}

half3 BlendMode_Overlay(half3 base, half3 blend)
{
    return half3(   BlendMode_Overlay(base.r, blend.r),
                    BlendMode_Overlay(base.g, blend.g),
                    BlendMode_Overlay(base.b, blend.b));
}

float2 Rotate(float2 coords, float rot){
	rot *= (UNITY_PI/180.0);
	float sinVal = sin(rot);
	float cosX = cos(rot);
	float2x2 mat = float2x2(cosX, -sinVal, sinVal, cosX);
	mat = ((mat*0.5)+0.5)*2-1;
	return mul(coords, mat);
}



#ifdef ENABLE_PARALLAX
float3 CalculateTangentViewDir(float3 tangentViewDir)
{
    tangentViewDir = Unity_SafeNormalize(tangentViewDir);
    tangentViewDir.xy /= (tangentViewDir.z + 0.42);
	return tangentViewDir;
}

// uwu https://github.com/MochiesCode/Mochies-Unity-Shaders/blob/7d48f101d04dac11bd4702586ee838ca669f426b/Mochie/Standard%20Shader/MochieStandardParallax.cginc#L13
float2 ParallaxOffsetMultiStep(float surfaceHeight, float strength, float2 uv, float3 tangentViewDir)
{
    float2 uvOffset = 0;
	float2 prevUVOffset = 0;
	float stepSize = 1.0/_ParallaxSteps;
	float stepHeight = 1;
	float2 uvDelta = tangentViewDir.xy * (stepSize * strength);
	float prevStepHeight = stepHeight;
	float prevSurfaceHeight = surfaceHeight;

    [unroll(50)]
    for (int j = 1; j <= _ParallaxSteps && stepHeight > surfaceHeight; j++){
        prevUVOffset = uvOffset;
        prevStepHeight = stepHeight;
        prevSurfaceHeight = surfaceHeight;
        uvOffset -= uvDelta;
        stepHeight -= stepSize;
        surfaceHeight = _ParallaxMap.Sample(sampler_MainTex, (uv + uvOffset)) + _ParallaxOffset;
    }
    [unroll(3)]
    for (int k = 0; k < 3; k++) {
        uvDelta *= 0.5;
        stepSize *= 0.5;

        if (stepHeight < surfaceHeight) {
            uvOffset += uvDelta;
            stepHeight += stepSize;
        }
        else {
            uvOffset -= uvDelta;
            stepHeight -= stepSize;
        }
        surfaceHeight = _ParallaxMap.Sample(sampler_MainTex, (uv + uvOffset)) + _ParallaxOffset;
    }

    return uvOffset;
}

float2 ParallaxOffset (float3 viewDirForParallax)
{
    viewDirForParallax = CalculateTangentViewDir(viewDirForParallax);

    float2 mainTexUV = uvs[clamp(_MainTexUV, 0, 2)]; // for now
    float h = _ParallaxMap.Sample(sampler_MainTex, (mainTexUV * _MainTex_ST.xy + _MainTex_ST.zw));
    h = clamp(h, 0, 0.999);
    float2 offset = ParallaxOffsetMultiStep(h, _Parallax, mainTexUV * _MainTex_ST.xy + _MainTex_ST.zw, viewDirForParallax);

	return offset;
}
#endif

#ifdef UNITY_PASS_META
float4 getMeta(Surface surface, Lighting light, float alpha)
{
    UnityMetaInput metaInput;
    UNITY_INITIALIZE_OUTPUT(UnityMetaInput, metaInput);
    metaInput.Emission = surface.emission;
    metaInput.Albedo = surface.albedo;
    // metaInput.SpecularColor = light.directSpecular;
    return float4(UnityMetaFragment(metaInput).rgb, alpha);
}
#endif

void applyEmission()
{
    half4 emissionMap = 1;
    #if defined(PROP_EMISSIONMAP)
        emissionMap = SampleTexture(_EmissionMap, _EmissionMap_ST, _EmissionMapUV);
    #endif

    UNITY_BRANCH
    if(_EmissionMultBase) emissionMap.rgb *= surface.albedo.rgb;

    #if defined(ENABLE_AUDIOLINK)
        float4 alEmissionMap = 1;
        #if defined(PROP_ALEMISSIONMAP)
            alEmissionMap = SampleTexture(_ALEmissionMap, _EmissionMap_ST, _EmissionMapUV);
        #endif
        
        float alEmissionType = 0;
        float alEmissionBand = _ALEmissionBand;
        float alSmoothing = (1 - _ALSmoothing);
        float alemissionMask = ((alEmissionMap.b * 256) > 1 ) * alEmissionMap.a;
        

        switch(_ALEmissionType)
        {
            case 1:
                alEmissionType = alSmoothing * 15;
                alEmissionBand += ALPASS_FILTEREDAUDIOLINK.y;
                alemissionMask = alEmissionMap.b;
                break;
            case 2:
                alEmissionType = alEmissionMap.b * (128 *  (1 - alSmoothing));
                break;
            case 3:
                alEmissionType = alSmoothing * 15;
                alEmissionBand += ALPASS_FILTEREDAUDIOLINK.y;
                break;
        }

        float alEmissionSample = _ALEmissionType ? AudioLinkLerpMultiline(float2(alEmissionType , alEmissionBand)).r * alemissionMask : 1;
        emissionMap *= alEmissionSample;
    #endif

    surface.emission = _EnableEmission ? emissionMap * pow(_EmissionColor.rgb, 2.2) : 0;
}


void calcDirectSpecular(float3 worldNormal, half3 tangent, half3 bitangent, half3 f0, half NoV, float3 viewDir, float3 specularColor)
{
    half NoH = saturate(dot(worldNormal, light.halfVector));
    half roughness = max(surface.perceptualRoughness * surface.perceptualRoughness, 0.002);

    float3 F = 1;

    UNITY_BRANCH
    if(_SpecularWorkflow == 1)
    {
        F = F_Schlick(light.LoH, specularColor);
    }
    else
    {
        F = F_Schlick(light.LoH, f0);
    }
    float D = 0;
    float V = 0;

    UNITY_BRANCH
    if(_EnableAnisotropy)
    {

        float anisotropy = _Anisotropy;
        float3 l = light.direction;
        float3 t = pixel.anisotropicT;
        float3 b = pixel.anisotropicB;
        float3 v = viewDir;
        float3 h = light.halfVector;

        float ToV = dot(t, v);
        float BoV = dot(b, v);
        float ToL = dot(t, l);
        float BoL = dot(b, l);
        float ToH = dot(t, h);
        float BoH = dot(b, h);

        half at = max(roughness * (1.0 + anisotropy), 0.002);
        half ab = max(roughness * (1.0 - anisotropy), 0.002);
        D = D_GGX_Anisotropic(at, ab, ToH, BoH, NoH);
        V = V_SmithGGXCorrelated_Anisotropic(at, ab, ToV, BoV, ToL, BoL, NoV, light.NoL);
    }
    else
    {
        D = GGXTerm (NoH, roughness);
        V = V_SmithGGXCorrelated ( NoV,light.NoL, roughness);
    }



    light.directSpecular += max(0, (D * V) * F) * light.finalLight * UNITY_PI;
}

half3 GIJOE_GlossyEnvironment(UNITY_ARGS_TEXCUBE(tex), half4 hdr, Unity_GlossyEnvironmentData glossIn)
{
    //half perceptualRoughness = glossIn.roughness;
    //perceptualRoughness = perceptualRoughness*(1.7 - 0.7*perceptualRoughness);
    //half mip = perceptualRoughness * UNITY_SPECCUBE_LOD_STEPS;
    float3 R = glossIn.reflUVW;
    half4 rgbm_hdr = UNITY_SAMPLE_TEXCUBE_LOD(tex, R, 0 /* mip */);
    half3 rgbm = DecodeHDR(rgbm_hdr, hdr);

    if (rgbm.x > 0.004 || rgbm.y > 0.004) {
        const float lod = 2;
        float2 viduv = float2(rgbm.x, rgbm.y);
        return tex2Dlod(_GIJOE_INPUT, float4(viduv, lod, lod));
    }
    return half3(0, 0, 0);
}

void calcIndirectSpecular(float3 reflDir, float3 worldPos, float3 reflWorldNormal, half3 fresnel, half3 f0)
{
    Unity_GlossyEnvironmentData envData;
    envData.roughness = surface.perceptualRoughness;
    envData.reflUVW = getBoxProjection(
        reflDir, worldPos,
        unity_SpecCube0_ProbePosition,
        unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
    );

    half3 probe0 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
    half3 probe0_joe = GIJOE_GlossyEnvironment(UNITY_PASS_TEXCUBE(_GIJoeReflProbe), _GIJoeReflProbe_HDR, envData);

    half3 indirectSpecular = probe0 + probe0_joe;

    // #if false //defined(UNITY_SPECCUBE_BLENDING)
    //     half interpolator = unity_SpecCube0_BoxMin.w;
    //     UNITY_BRANCH
    //     if (interpolator < 0.99999)
    //     {
    //         envData.reflUVW = getBoxProjection(
    //             reflDir, worldPos,
    //             unity_SpecCube1_ProbePosition,
    //             unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
    //         );
    //         half3 probe1 = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube1_HDR, envData);
    //         indirectSpecular = lerp(probe1, probe0, interpolator);
    //     }
    // #endif

    half horizon = min(1 + dot(reflDir, reflWorldNormal), 1);
    indirectSpecular *= horizon * horizon;

    light.indirectSpecular = indirectSpecular * lerp(fresnel, f0, surface.perceptualRoughness);
}

float3 Unity_NormalReconstructZ_float(float2 In)
{
    float reconstructZ = sqrt(1.0 - saturate(dot(In.xy, In.xy)));
    float3 normalVector = float3(In.x, In.y, reconstructZ);
    return normalize(normalVector);
}
// https://github.com/DarthShader/Kaj-Unity-Shaders/blob/926f07a0bf3dc950db4d7346d022c89f9dfdb440/Shaders/Kaj/KajCore.cginc#L1041
#ifdef POINT
#define LIGHT_ATTENUATION_NO_SHADOW_MUL(destName, input, worldPos) \
        unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        fixed destName = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).r;
#endif
#ifdef SPOT
#define LIGHT_ATTENUATION_NO_SHADOW_MUL(destName, input, worldPos) \
        DECLARE_LIGHT_COORD(input, worldPos); \
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        fixed destName = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz);
#endif
#ifdef DIRECTIONAL
#define LIGHT_ATTENUATION_NO_SHADOW_MUL(destName, input, worldPos) \
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        fixed destName = 1;
#endif
#ifdef POINT_COOKIE
#define LIGHT_ATTENUATION_NO_SHADOW_MUL(destName, input, worldPos) \
        DECLARE_LIGHT_COORD(input, worldPos); \
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        fixed destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).r * texCUBE(_LightTexture0, lightCoord).w;
#endif
#ifdef DIRECTIONAL_COOKIE
#define LIGHT_ATTENUATION_NO_SHADOW_MUL(destName, input, worldPos) \
        DECLARE_LIGHT_COORD(input, worldPos); \
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        fixed destName = tex2D(_LightTexture0, lightCoord).w;
#endif

#if !defined(UNITY_PASS_SHADOWCASTER)
void initLighting(v2f i, float3 worldNormal, float3 viewDir, half NoV, float3 tangentNormal, inout float3 subsurfaceColor)
{
    light.direction = Unity_SafeNormalize(UnityWorldSpaceLightDir(i.worldPos));
    light.color = _LightColor0.rgb;
    light.halfVector = Unity_SafeNormalize(light.direction + viewDir);
    light.NoL = saturate(dot(worldNormal, light.direction));
    light.LoH = saturate(dot(light.direction, light.halfVector));
    LIGHT_ATTENUATION_NO_SHADOW_MUL(lightAttenNoShadows, i, i.worldPos.xyz);
    light.attenuation = lightAttenNoShadows * shadow;
    light.finalLight = (light.NoL * light.attenuation * light.color);
    light.finalLight *= Fd_Burley(surface.perceptualRoughness, NoV, light.NoL, light.LoH);

    UNITY_BRANCH
    if(_SubsurfaceScattering)
    {
        // https://www.alanzucconi.com/2017/08/30/fast-subsurface-scattering-2/
        float VomL = pow(saturate(dot(viewDir, -light.direction)), _Power) * _Scale;
        float4 thicknessMap = 1;
        #ifdef PROP_THICKNESSMAP
            thicknessMap = SampleTexture(_ThicknessMap, _ThicknessMap_ST, _ThicknessMapUV);
        #endif
        subsurfaceColor = VomL * light.color * lightAttenNoShadows * thicknessMap * _SubsurfaceTint;
    }
}
#endif

#if defined(PROP_DETAILMAP)
float4 applyDetailMap(half2 parallaxOffset, float maskMapAlpha)
{
    float4 detailMap = SampleTexture(_DetailMap, _DetailMap_ST, _DetailMapUV);

    float detailMask = maskMapAlpha;
    float detailAlbedo = detailMap.r * 2.0 - 1.0;
    float detailSmoothness = (detailMap.b * 2.0 - 1.0);

    // Goal: we want the detail albedo map to be able to darken down to black and brighten up to white the surface albedo.
    // The scale control the speed of the gradient. We simply remap detailAlbedo from [0..1] to [-1..1] then perform a lerp to black or white
    // with a factor based on speed.
    // For base color we interpolate in sRGB space (approximate here as square) as it get a nicer perceptual gradient

    float albedoDetailSpeed = saturate(abs(detailAlbedo) * _DetailAlbedoScale);
    float3 baseColorOverlay = lerp(sqrt(surface.albedo.rgb), (detailAlbedo < 0.0) ? float3(0.0, 0.0, 0.0) : float3(1.0, 1.0, 1.0), albedoDetailSpeed * albedoDetailSpeed);
    baseColorOverlay *= baseColorOverlay;							   
    // Lerp with details mask
    surface.albedo.rgb = lerp(surface.albedo.rgb, saturate(baseColorOverlay), detailMask);

    float perceptualSmoothness = (1 - surface.perceptualRoughness);
    // See comment for baseColorOverlay
    float smoothnessDetailSpeed = saturate(abs(detailSmoothness) * _DetailSmoothnessScale);
    float smoothnessOverlay = lerp(perceptualSmoothness, (detailSmoothness < 0.0) ? 0.0 : 1.0, smoothnessDetailSpeed);
    // Lerp with details mask
    perceptualSmoothness = lerp(perceptualSmoothness, saturate(smoothnessOverlay), detailMask);

    surface.perceptualRoughness = (1 - perceptualSmoothness);
    return detailMap;
}
#endif

void applySaturation()
{
    half desaturated = dot(surface.albedo.rgb, grayscaleVec);
    surface.albedo.rgb = lerp(desaturated, surface.albedo.rgb, (_Saturation+1));
}

void initSurfaceData(inout half metallicMap, inout half smoothnessMap, inout half occlusionMap, inout half4 maskMap, half2 parallaxOffset)
{
    bool isRoughness = _GlossinessInvert;
    
    #ifndef ENABLE_PACKED_MODE

        #ifdef PROP_METALLICMAP
            metallicMap = SampleTexture(_MetallicMap, _MetallicMap_ST, _MetallicMapUV);
        #endif

        #ifdef PROP_SMOOTHNESSMAP
            smoothnessMap = SampleTexture(_SmoothnessMap, _SmoothnessMap_ST, _SmoothnessMapUV);
        #endif

        #ifdef PROP_OCCLUSIONMAP
            occlusionMap = SampleTexture(_OcclusionMap, _OcclusionMap_ST, _OcclusionMapUV);
        #endif

    #else

        #ifdef PROP_METALLICGLOSSMAP
            maskMap = SampleTexture(_MetallicGlossMap, _MetallicGlossMap_ST, _MetallicGlossMapUV);
        #endif
        
        metallicMap = maskMap.r;
        smoothnessMap = maskMap.a;
        occlusionMap = maskMap.g;
        isRoughness = 0;
    #endif

    half smoothness = _Glossiness * smoothnessMap;
    surface.perceptualRoughness = isRoughness ? smoothness : 1-smoothness;
    surface.metallic = metallicMap * _Metallic * _Metallic;
    surface.oneMinusMetallic = 1 - surface.metallic;
    surface.occlusion = lerp(1,occlusionMap , _Occlusion);
}


void getIndirectDiffuse(float3 worldNormal, float2 parallaxOffset, inout half2 lightmapUV)
{
    #if defined(LIGHTMAP_ON)

        lightmapUV = uvs[1] * unity_LightmapST.xy + unity_LightmapST.zw;
        float4 bakedColorTex = 0;

        half3 lightMap = tex2DFastBicubicLightmap(lightmapUV, bakedColorTex) * (_LightmapMultiplier);

        #if defined(DIRLIGHTMAP_COMBINED)
            light.bakedDir = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, lightmapUV);
            lightMap = DecodeDirectionalLightmap(lightMap, light.bakedDir, worldNormal);
        #endif

        #if defined(DYNAMICLIGHTMAP_ON)
            half3 realtimeLightMap = getRealtimeLightmap(uvs[2], worldNormal, float2(0, 0));
            lightMap += realtimeLightMap; 
        #endif

        #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
            light.finalLight = 0;
            light.NoL = 0;
            light.direction = float3(0,1,0);
            lightMap = SubtractMainLightWithRealtimeAttenuationFromLightmap (lightMap, light.attenuation, bakedColorTex, worldNormal);
        #endif

        
        
        light.indirectDiffuse = lightMap;

    #else
        if(_FlatShading) worldNormal = half3(0,0,0);
        lightmapUV = 0;
        UNITY_BRANCH
        if(_LightProbeMethod == 0)
        {
            light.indirectDiffuse = max(0, ShadeSH9(float4(worldNormal, 1)));
        }
        else
        {
            half3 L0 = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
            light.indirectDiffuse.r = shEvaluateDiffuseL1Geomerics_local(L0.r, unity_SHAr.xyz, worldNormal);
            light.indirectDiffuse.g = shEvaluateDiffuseL1Geomerics_local(L0.g, unity_SHAg.xyz, worldNormal);
            light.indirectDiffuse.b = shEvaluateDiffuseL1Geomerics_local(L0.b, unity_SHAb.xyz, worldNormal);
            light.indirectDiffuse = max(0, light.indirectDiffuse);
        }

    #endif
}

#if defined(VERTEXLIGHT_ON) && defined(UNITY_PASS_FORWARDBASE)
void initVertexLights(float3 worldPos, float3 worldNormal, inout float3 vLight, inout float3 vertexLightColor)
{
    float3 vertexLightData = 0;
    float4 vertexLightAtten = float4(0,0,0,0);
    vertexLightColor = get4VertexLightsColFalloff(vertexLightInformation, worldPos, worldNormal, vertexLightAtten);
    float3 vertexLightDir = getVertexLightsDir(vertexLightInformation, worldPos, vertexLightAtten);
    [unroll(4)]
    for(int i = 0; i < 4; i++)
    {
        vertexLightData += saturate(dot(vertexLightInformation.Direction[i], worldNormal)) * vertexLightInformation.ColorFalloff[i];
    }
    vLight = vertexLightData;
}
#endif

#define MOD3 float3(443.8975,397.2973, 491.1871)
float ditherNoiseFuncLow(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * MOD3 + _Time.y);
    p3 += dot(p3, p3.yzx + 19.19);
    return frac((p3.x + p3.y) * p3.z);
}

float3 ditherNoiseFuncHigh(float2 p)
{
    float3 p3 = frac(float3(p.xyx) * (MOD3 + _Time.y));
    p3 += dot(p3, p3.yxz + 19.19);
    return frac(float3((p3.x + p3.y)*p3.z, (p3.x + p3.z)*p3.y, (p3.y + p3.z)*p3.x));
}

float3 indirectDiffuseSpecular(float3 worldNormal, float3 viewDir, float3 tangentNormal)
{
    half roughness = max(surface.perceptualRoughness * surface.perceptualRoughness, 0.002);
    float3 dominantDir = 1;
    float3 specColor = 0;

    #if !defined(BAKERY_SH) && !defined(BAKERY_RNM)
        if(bakeryLightmapMode < 2)
        {
            #ifdef DIRLIGHTMAP_COMBINED
                dominantDir = (light.bakedDir.xyz) * 2 - 1;
                specColor = light.indirectDiffuse;
            #endif
            #if defined(LIGHTMAP_ON) && !defined(DIRLIGHTMAP_COMBINED)
                dominantDir = _SpecularDirection.xyz;
                specColor = light.indirectDiffuse;
            #endif
            #ifndef LIGHTMAP_ON
                specColor = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
                dominantDir = unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz;
            #endif
        }
    #endif

    half3 halfDir = Unity_SafeNormalize(normalize(dominantDir) + viewDir );
    half nh = saturate(dot(worldNormal, halfDir));
    half spec = D_GGX(nh, roughness);
    return spec * specColor;
}