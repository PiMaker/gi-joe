#if !defined(UNITY_PASS_SHADOWCASTER)
half4 frag(v2f i) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(i);
    #if defined(LOD_FADE_CROSSFADE)
		UnityApplyDitherCrossFade(i.pos);
	#endif

    initUVs(i);
    float3 worldPos = i.worldPos;
    pixel.worldPos = i.worldPos;
    half2 parallaxOffset = 0;
    half alpha = 1;
    half4 maskMap = 1;
    half4 detailMap = 1;
    half metallicMap = 1;
    half smoothnessMap = 1;
    half occlusionMap = 1;
    half4 mainTex = 1;
    float3 tangentNormal = 0.5;
    half2 lightmapUV = 0;
    float3 vLight = 0;
    float3 vertexLightColor = 0;
    float3 subsurfaceColor = 0;
    pixel.anisotropicDirection = 0.5;

    #ifdef CENTROID_NORMAL
        if (dot(i.worldNormal.xyz, i.worldNormal.xyz) >= 1.01) i.worldNormal.xyz = i.centroidWorldNormal.xyz;
    #endif

    float3 worldNormal = normalize(i.worldNormal);
    pixel.worldNormal = worldNormal;
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
    half NoV = abs(dot(worldNormal, viewDir)) + 1e-5;

    
    #if defined(ENABLE_PARALLAX)
        parallaxOffset = ParallaxOffset(i.viewDirForParallax);
        pixel.parallaxOffset = parallaxOffset;
    #endif

    getMainTex(mainTex, parallaxOffset, i.color);

    
    #ifdef ENABLE_TRANSPARENCY
        alpha = calcAlpha(surface.albedo.a);
    #endif


    initSurfaceData(metallicMap, smoothnessMap, occlusionMap, maskMap, parallaxOffset);

    #if defined(PROP_DETAILMAP)
        detailMap = applyDetailMap(parallaxOffset, maskMap.a);
    #endif

    applySaturation();


    #if defined(ENABLE_REFLECTIONS) || defined(ENABLE_SPECULAR_HIGHLIGHTS) || defined (PROP_BUMPMAP) || defined(UNITY_PASS_META)
        half3 tangent = i.tangent;
        half3 bitangent = i.bitangent;
    #endif


    #ifdef PROP_BUMPMAP
        half4 normalMap = SampleTexture(_BumpMap, _BumpMap_ST, sampler_BumpMap, _BumpMapUV);
        float4 detailNormalMap = float4(0.5, 0.5, 1, 1);
        #if defined(PROP_DETAILMAP)
            detailNormalMap = float4(detailMap.a, detailMap.g, 1, 1);
        #endif
        initNormalMap(normalMap, bitangent, tangent, worldNormal, detailNormalMap, tangentNormal);
    #endif


    #if !defined(LIGHTMAP_ON) || defined(USING_LIGHT_MULTI_COMPILE)
        initLighting(i, worldNormal, viewDir, NoV, tangentNormal, subsurfaceColor);
    #endif

    #if defined(VERTEXLIGHT_ON) && defined(UNITY_PASS_FORWARDBASE)
        initVertexLights(worldPos, worldNormal, vLight, vertexLightColor);
    #endif
    
    getIndirectDiffuse(worldNormal, parallaxOffset, lightmapUV);

    #if defined(LIGHTMAP_SHADOW_MIXING) && defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN) && defined(LIGHTMAP_ON)
        light.finalLight *= UnityComputeForwardShadows(lightmapUV, pixel.worldPos, i.screenPos);
    #endif
    

    UNITY_BRANCH
    if(_GSAA) surface.perceptualRoughness = GSAA_Filament(worldNormal, surface.perceptualRoughness);

    float3 f0 = 1;
    float3 specularIntensity = 0;
    float3 fresnel = 1;

    #ifdef PROP_SPECGLOSSMAP
        float3 specularColor = SampleTexture(_SpecGlossMap, _SpecGlossMap_ST, _SpecGlossMapUV).rgb * _SpecColor.rgb;
    #else
        float3 specularColor = _SpecColor.rgb;
    #endif

    UNITY_BRANCH
    if(_SpecularWorkflow == 1)
    {
        
        f0 = _Reflectance;
        specularIntensity = saturate(specularColor.r + specularColor.b + specularColor.g);
        surface.oneMinusMetallic = 1 - specularIntensity;
        fresnel = F_Schlick(NoV, specularColor);
    }
    else
    {
        f0 = 0.16 * _Reflectance * _Reflectance * surface.oneMinusMetallic + surface.albedo * surface.metallic;
        fresnel = lerp(f0, F_Schlick(NoV, f0) , _FresnelColor.a) * _FresnelColor.rgb;
    }

    fresnel *= _SpecularOcclusion ? saturate(lerp(1, pow(length(light.indirectDiffuse), _SpecularOcclusionSensitivity), _SpecularOcclusion)) * surface.oneMinusMetallic : 1;
    
    #if defined(UNITY_PASS_FORWARDBASE)

        #if defined(ENABLE_REFLECTIONS)
            float3 reflViewDir = reflect(-viewDir, worldNormal);
            float3 reflWorldNormal = worldNormal;
            
            if(_EnableAnisotropy) reflViewDir = getAnisotropicReflectionVector(viewDir, bitangent, tangent, worldNormal, surface.perceptualRoughness);
            
            calcIndirectSpecular(reflViewDir, worldPos, reflWorldNormal, fresnel, f0);
        #endif
        
        #ifdef BAKERY_LMSPEC
            light.directSpecular += indirectDiffuseSpecular(worldNormal, viewDir, tangentNormal) * fresnel;
        #endif

        light.indirectSpecular *= computeSpecularAO(NoV, surface.occlusion, surface.perceptualRoughness * surface.perceptualRoughness);
    #endif

    #if defined(ENABLE_SPECULAR_HIGHLIGHTS) || defined(UNITY_PASS_META)
        calcDirectSpecular(worldNormal, tangent, bitangent, f0, NoV, viewDir, specularColor);
    #endif

    
    #if defined(UNITY_PASS_FORWARDBASE) || defined(UNITY_PASS_META)
        applyEmission();
    #endif

    #if defined(BAKERY_RNM)
        if (bakeryLightmapMode == BAKERYMODE_RNM)
        {
            float3 eyeVecT = 0;
            #ifdef BAKERY_LMSPEC
                eyeVecT = -normalize(i.viewDirForParallax);
            #endif

            float3 prevSpec = light.indirectSpecular;
            BakeryRNM(light.indirectDiffuse, light.indirectSpecular, lightmapUV, tangentNormal, surface.perceptualRoughness, eyeVecT);
            light.indirectSpecular *= fresnel;
            light.indirectSpecular += prevSpec;
        }
    #endif

    #ifdef BAKERY_SH
    if (bakeryLightmapMode == BAKERYMODE_SH)
    {
        float3 prevSpec = light.indirectSpecular;
        BakerySH(light.indirectDiffuse, light.indirectSpecular, lightmapUV, worldNormal, -viewDir, surface.perceptualRoughness, worldPos);
        #ifdef BAKERY_SH_GIJOE
        BakerySH_GIJOE(light.indirectDiffuse, light.indirectSpecular, lightmapUV, worldNormal, -viewDir, surface.perceptualRoughness, worldPos);
        #endif
        light.indirectSpecular *= fresnel;
        light.indirectSpecular += prevSpec;
    }
    #endif
    
    alpha -= mainTex.a * 0.00001; // fix main tex sampler without changing the color;
    
    UNITY_BRANCH
    if(_Mode == 3)
    {
        surface.albedo.rgb *= alpha;
        alpha = lerp(alpha, 1, surface.metallic);
    }
    else if(_Mode == 2)
    {
        light.finalLight *= alpha;
        light.directSpecular *= alpha;
    }


    if(_FlatShading) light.finalLight = saturate(light.color + vertexLightColor) * light.attenuation;



 
    half4 finalColor = half4( surface.albedo * surface.oneMinusMetallic * (light.indirectDiffuse * surface.occlusion + (light.finalLight + vLight + subsurfaceColor)) + light.indirectSpecular + light.directSpecular + surface.emission, alpha);
    
    #ifdef UNITY_PASS_META
        return getMeta(surface, light, alpha);
    #endif

    #ifdef USE_FOG
        UNITY_APPLY_FOG(i.fogCoord, finalColor);
    #endif

    return finalColor;
}
#endif

#if defined(UNITY_PASS_SHADOWCASTER)
half4 ShadowCasterfrag(v2f i) : SV_Target
{
    #if defined(LOD_FADE_CROSSFADE)
		UnityApplyDitherCrossFade(i.pos);
	#endif
    
    initUVs(i);
    half2 parallaxOffset = 0;
    pixel.worldNormal = 1;
    half4 mainTex = SampleTexture(_MainTex, _MainTex_ST, _MainTexUV);

    half alpha = mainTex.a * _Color.a;

    #ifdef ENABLE_TRANSPARENCY
        if(_Mode == 1) clip(alpha - _Cutoff);
        if(_Mode > 1) clip(alpha-0.5);
    #endif

    SHADOW_CASTER_FRAGMENT(i);
}
#endif