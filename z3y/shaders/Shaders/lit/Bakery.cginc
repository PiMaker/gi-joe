#ifndef BAKERY_INCLUDED
#define BAKERY_INCLUDED

//float2 bakeryLightmapSize;
#define BAKERYMODE_DEFAULT 0
#define BAKERYMODE_VERTEXLM 1.0f
#define BAKERYMODE_RNM 2.0f
#define BAKERYMODE_SH 3.0f

#ifdef ENABLE_BICUBIC_LIGHTMAP
#define BAKERY_BICUBIC
#endif

//#define BAKERY_SSBUMP

// can't fit vertexLM SH to sm3_0 interpolators
#ifndef SHADER_API_D3D11
    #undef BAKERY_VERTEXLMSH
#endif

// can't do stuff on sm2_0 due to standard shader alrady taking up all instructions
#if SHADER_TARGET < 30
    #undef BAKERY_BICUBIC
    #undef BAKERY_LMSPEC

    #undef BAKERY_RNM
    #undef BAKERY_SH
    #undef BAKERY_VERTEXLM
#endif

#ifndef UNITY_SHOULD_SAMPLE_SH
    #undef BAKERY_PROBESHNONLINEAR
#endif

#if defined(BAKERY_RNM) && defined(BAKERY_LMSPEC)
#define BAKERY_RNMSPEC
#endif

#ifndef BAKERY_VERTEXLM
    #undef BAKERY_VERTEXLMDIR
    #undef BAKERY_VERTEXLMSH
    #undef BAKERY_VERTEXLMMASK
#endif

#define lumaConv float3(0.2125f, 0.7154f, 0.0721f)

#if defined(BAKERY_SH) || defined(BAKERY_VERTEXLMSH) || defined(BAKERY_PROBESHNONLINEAR) || defined(BAKERY_VOLUME)
float shEvaluateDiffuseL1Geomerics(float L0, float3 L1, float3 n)
{
    // average energy
    float R0 = L0;

    // avg direction of incoming light
    float3 R1 = 0.5f * L1;

    // directional brightness
    float lenR1 = length(R1);

    // linear angle between normal and direction 0-1
    //float q = 0.5f * (1.0f + dot(R1 / lenR1, n));
    //float q = dot(R1 / lenR1, n) * 0.5 + 0.5;
    float q = dot(normalize(R1), n) * 0.5 + 0.5;

    // power for q
    // lerps from 1 (linear) to 3 (cubic) based on directionality
    float p = 1.0f + 2.0f * lenR1 / R0;

    // dynamic range constant
    // should vary between 4 (highly directional) and 0 (ambient)
    float a = (1.0f - lenR1 / R0) / (1.0f + lenR1 / R0);

    return R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p));
}
#endif

#ifdef BAKERY_VERTEXLM
    float4 unpack4NFloats(float src) {
        //return fmod(float4(src / 262144.0, src / 4096.0, src / 64.0, src), 64.0)/64.0;
        return frac(float4(src / (262144.0*64), src / (4096.0*64), src / (64.0*64), src));
    }
    float3 unpack3NFloats(float src) {
        float r = frac(src);
        float g = frac(src * 256.0);
        float b = frac(src * 65536.0);
        return float3(r, g, b);
    }
#if defined(BAKERY_VERTEXLMDIR)
    void BakeryVertexLMDirection(inout float3 diffuseColor, inout float3 specularColor, float3 lightDirection, float3 vertexNormalWorld, float3 normalWorld, float3 viewDir, float smoothness)
    {
        float3 dominantDir = Unity_SafeNormalize(lightDirection);
        half halfLambert = dot(normalWorld, dominantDir) * 0.5 + 0.5;
        half flatNormalHalfLambert = dot(vertexNormalWorld, dominantDir) * 0.5 + 0.5;

        #ifdef BAKERY_LMSPEC
            half3 halfDir = Unity_SafeNormalize(normalize(dominantDir) - viewDir);
            half nh = saturate(dot(normalWorld, halfDir));
            half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
            half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
            half spec = GGXTerm(nh, roughness);
            specularColor = spec * diffuseColor;
        #endif

        diffuseColor *= halfLambert / max(1e-4h, flatNormalHalfLambert);
    }
#elif defined(BAKERY_VERTEXLMSH)
    void BakeryVertexLMSH(inout float3 diffuseColor, inout float3 specularColor, float3 shL1x, float3 shL1y, float3 shL1z, float3 normalWorld, float3 viewDir, float smoothness)
    {
        float3 L0 = diffuseColor;
        float3 nL1x = shL1x;
        float3 nL1y = shL1y;
        float3 nL1z = shL1z;
        float3 L1x = nL1x * L0 * 2;
        float3 L1y = nL1y * L0 * 2;
        float3 L1z = nL1z * L0 * 2;

        float3 sh;
    #ifdef BAKERY_SHNONLINEAR
        //sh.r = shEvaluateDiffuseL1Geomerics(L0.r, float3(L1x.r, L1y.r, L1z.r), normalWorld);
        //sh.g = shEvaluateDiffuseL1Geomerics(L0.g, float3(L1x.g, L1y.g, L1z.g), normalWorld);
        //sh.b = shEvaluateDiffuseL1Geomerics(L0.b, float3(L1x.b, L1y.b, L1z.b), normalWorld);

        float lumaL0 = dot(L0, 1);
        float lumaL1x = dot(L1x, 1);
        float lumaL1y = dot(L1y, 1);
        float lumaL1z = dot(L1z, 1);
        float lumaSH = shEvaluateDiffuseL1Geomerics(lumaL0, float3(lumaL1x, lumaL1y, lumaL1z), normalWorld);

        sh = L0 + normalWorld.x * L1x + normalWorld.y * L1y + normalWorld.z * L1z;
        float regularLumaSH = dot(sh, 1);
        //sh *= regularLumaSH < 0.001 ? 1 : (lumaSH / regularLumaSH);
        sh *= lerp(1, lumaSH / regularLumaSH, saturate(regularLumaSH*16));

    #else
        sh = L0 + normalWorld.x * L1x + normalWorld.y * L1y + normalWorld.z * L1z;
    #endif

        diffuseColor = max(sh, 0.0);

        #ifdef BAKERY_LMSPEC
            float3 dominantDir = float3(dot(nL1x, lumaConv), dot(nL1y, lumaConv), dot(nL1z, lumaConv));
            float focus = saturate(length(dominantDir));
            half3 halfDir = Unity_SafeNormalize(normalize(dominantDir) - viewDir);
            half nh = saturate(dot(normalWorld, halfDir));
            half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness );//* sqrt(focus));
            half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
            half spec = GGXTerm(nh, roughness);
            specularColor = max(spec * sh, 0.0);
        #endif
    }
#endif
#endif

#ifdef BAKERY_BICUBIC
float BakeryBicubic_w0(float a)
{
    return (1.0f/6.0f)*(a*(a*(-a + 3.0f) - 3.0f) + 1.0f);
}

float BakeryBicubic_w1(float a)
{
    return (1.0f/6.0f)*(a*a*(3.0f*a - 6.0f) + 4.0f);
}

float BakeryBicubic_w2(float a)
{
    return (1.0f/6.0f)*(a*(a*(-3.0f*a + 3.0f) + 3.0f) + 1.0f);
}

float BakeryBicubic_w3(float a)
{
    return (1.0f/6.0f)*(a*a*a);
}

float BakeryBicubic_g0(float a)
{
    return BakeryBicubic_w0(a) + BakeryBicubic_w1(a);
}

float BakeryBicubic_g1(float a)
{
    return BakeryBicubic_w2(a) + BakeryBicubic_w3(a);
}

float BakeryBicubic_h0(float a)
{
    return -1.0f + BakeryBicubic_w1(a) / (BakeryBicubic_w0(a) + BakeryBicubic_w1(a)) + 0.5f;
}

float BakeryBicubic_h1(float a)
{
    return 1.0f + BakeryBicubic_w3(a) / (BakeryBicubic_w2(a) + BakeryBicubic_w3(a)) + 0.5f;
}
#endif

#if defined(BAKERY_RNM) || defined(BAKERY_SH)
sampler2D _RNM0, _RNM1, _RNM2;
float4 _RNM0_TexelSize;
#endif

#ifdef BAKERY_VOLUME
Texture3D _Volume0, _Volume1, _Volume2, _VolumeMask;
SamplerState sampler_Volume0;
float3 _VolumeMin, _VolumeInvSize;
float3 _GlobalVolumeMin, _GlobalVolumeInvSize;
#endif

#ifdef BAKERY_BICUBIC
    // Bicubic
    float4 BakeryTex2D(sampler2D tex, float2 uv, float4 texelSize)
    {
        float x = uv.x * texelSize.z;
        float y = uv.y * texelSize.z;

        x -= 0.5f;
        y -= 0.5f;

        float px = floor(x);
        float py = floor(y);

        float fx = x - px;
        float fy = y - py;

        float g0x = BakeryBicubic_g0(fx);
        float g1x = BakeryBicubic_g1(fx);
        float h0x = BakeryBicubic_h0(fx);
        float h1x = BakeryBicubic_h1(fx);
        float h0y = BakeryBicubic_h0(fy);
        float h1y = BakeryBicubic_h1(fy);

        return     BakeryBicubic_g0(fy) * ( g0x * tex2D(tex, (float2(px + h0x, py + h0y) * texelSize.x))   +
                              g1x * tex2D(tex, (float2(px + h1x, py + h0y) * texelSize.x))) +

                   BakeryBicubic_g1(fy) * ( g0x * tex2D(tex, (float2(px + h0x, py + h1y) * texelSize.x))   +
                              g1x * tex2D(tex, (float2(px + h1x, py + h1y) * texelSize.x)));
    }
    float4 BakeryTex2D(Texture2D tex, SamplerState s, float2 uv, float4 texelSize)
    {
        float x = uv.x * texelSize.z;
        float y = uv.y * texelSize.z;

        x -= 0.5f;
        y -= 0.5f;

        float px = floor(x);
        float py = floor(y);

        float fx = x - px;
        float fy = y - py;

        float g0x = BakeryBicubic_g0(fx);
        float g1x = BakeryBicubic_g1(fx);
        float h0x = BakeryBicubic_h0(fx);
        float h1x = BakeryBicubic_h1(fx);
        float h0y = BakeryBicubic_h0(fy);
        float h1y = BakeryBicubic_h1(fy);

        return     BakeryBicubic_g0(fy) * ( g0x * tex.Sample(s, (float2(px + h0x, py + h0y) * texelSize.x))   +
                              g1x * tex.Sample(s, (float2(px + h1x, py + h0y) * texelSize.x))) +

                   BakeryBicubic_g1(fy) * ( g0x * tex.Sample(s, (float2(px + h0x, py + h1y) * texelSize.x))   +
                              g1x * tex.Sample(s, (float2(px + h1x, py + h1y) * texelSize.x)));
    }
#else
    // Bilinear
    float4 BakeryTex2D(sampler2D tex, float2 uv, float4 texelSize)
    {
        return tex2D(tex, uv);
    }
    float4 BakeryTex2D(Texture2D tex, SamplerState s, float2 uv, float4 texelSize)
    {
        return tex.Sample(s, uv);
    }
#endif

#ifdef DIRLIGHTMAP_COMBINED
#ifdef BAKERY_LMSPEC
float BakeryDirectionalLightmapSpecular(float2 lmUV, float3 normalWorld, float3 viewDir, float smoothness)
{
    float3 dominantDir = UNITY_SAMPLE_TEX2D_SAMPLER(unity_LightmapInd, unity_Lightmap, lmUV).xyz * 2 - 1;
    half3 halfDir = Unity_SafeNormalize(normalize(dominantDir) - viewDir);
    half nh = saturate(dot(normalWorld, halfDir));
    half perceptualRoughness = SmoothnessToPerceptualRoughness(smoothness);
    half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    half spec = GGXTerm(nh, roughness);
    return spec;
}
#endif
#endif

#ifdef BAKERY_RNM
void BakeryRNM(inout float3 diffuseColor, inout float3 specularColor, float2 lmUV, float3 normalMap, float perceptualRoughness, float3 viewDirT)
{
    normalMap.g *= -1;
    const float3 rnmBasis0 = float3(0.816496580927726f, 0, 0.5773502691896258f);
    const float3 rnmBasis1 = float3(-0.4082482904638631f, 0.7071067811865475f, 0.5773502691896258f);
    const float3 rnmBasis2 = float3(-0.4082482904638631f, -0.7071067811865475f, 0.5773502691896258f);

    float3 rnm0 = DecodeLightmap(BakeryTex2D(_RNM0, lmUV, _RNM0_TexelSize));
    float3 rnm1 = DecodeLightmap(BakeryTex2D(_RNM1, lmUV, _RNM0_TexelSize));
    float3 rnm2 = DecodeLightmap(BakeryTex2D(_RNM2, lmUV, _RNM0_TexelSize));

    #ifdef BAKERY_SSBUMP
        diffuseColor = normalMap.x * rnm0
                     + normalMap.z * rnm1
                     + normalMap.y * rnm2;
         diffuseColor *= 2;
    #else
        diffuseColor = saturate(dot(rnmBasis0, normalMap)) * rnm0
                     + saturate(dot(rnmBasis1, normalMap)) * rnm1
                     + saturate(dot(rnmBasis2, normalMap)) * rnm2;
    #endif

    #ifdef BAKERY_LMSPEC
        float3 dominantDirT = rnmBasis0 * dot(rnm0, lumaConv) +
                              rnmBasis1 * dot(rnm1, lumaConv) +
                              rnmBasis2 * dot(rnm2, lumaConv);

        float3 dominantDirTN = normalize(dominantDirT);
        float3 specColor = saturate(dot(rnmBasis0, dominantDirTN)) * rnm0 +
                           saturate(dot(rnmBasis1, dominantDirTN)) * rnm1 +
                           saturate(dot(rnmBasis2, dominantDirTN)) * rnm2;

        half3 halfDir = Unity_SafeNormalize(dominantDirTN - viewDirT);
        half nh = saturate(dot(normalMap, halfDir));
        half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
        half spec = GGXTerm(nh, roughness);
        specularColor = spec * specColor;
    #endif
}
#endif

#ifdef BAKERY_SH
static bool mirrrror = unity_CameraProjection[2][0] != 0.f || unity_CameraProjection[2][1] != 0.f;
#ifdef BAKERY_SH_GIJOE
inline float3 idx_float3(in float3 i, in uint idx) {
    return idx == 0 ? i.rrr : (idx == 1 ? i.ggg : i.bbb);
}
void BakerySH_GIJOE(inout float3 diffuseColor, inout float3 specularColor, float2 lmUV, float3 normalWorld, float3 viewDir, float perceptualRoughness, float3 worldPos)
{
    #ifdef BAKERY_LMSPEC
        half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
    #endif

    uint i;

    // TOP
    [unroll(3)]
    for (i = 0; i < 3; i++) {
        float2 giuv;
        [flatten]
        switch (i) {
            case 0:
                giuv = float2(0.01, 0.05);
                break;
            case 1:
                giuv = float2(0.5, 0.05);
                break;
            case 2:
                giuv = float2(0.99, 0.05);
                break;
        }
        #if UNITY_UV_STARTS_AT_TOP
        giuv.y = 1 - giuv.y;
        #endif
        float4 bakerytex = BakeryTex2D(_LM_GIJOE_0, sampler_LM_GIJOE_0, lmUV, _RNM0_TexelSize);
        float3 L0 = idx_float3(DecodeLightmap(bakerytex), i % 3);
        float3 giColor = tex2Dlod(_GIJOE_INPUT, float4(giuv, 9, 9 /* empirically determined */));
        L0 *= pow(giColor, 1.15) + 0.0005;
        float3 nL1x = idx_float3(BakeryTex2D(_RNM0_GIJOE_0, sampler_LM_GIJOE_0, lmUV, _RNM0_TexelSize), i % 3) * 2 - 1;
        float3 nL1y = idx_float3(BakeryTex2D(_RNM1_GIJOE_0, sampler_LM_GIJOE_0, lmUV, _RNM0_TexelSize), i % 3) * 2 - 1;
        float3 nL1z = idx_float3(BakeryTex2D(_RNM2_GIJOE_0, sampler_LM_GIJOE_0, lmUV, _RNM0_TexelSize), i % 3) * 2 - 1;
        float3 L1x = nL1x * L0 * 2;
        float3 L1y = nL1y * L0 * 2;
        float3 L1z = nL1z * L0 * 2;
        float3 sh = L0 + normalWorld.x * L1x + normalWorld.y * L1y + normalWorld.z * L1z;
        diffuseColor = saturate(diffuseColor + max(sh, 0.0));

        // #ifdef BAKERY_LMSPEC
        //     float3 dominantDir = float3(dot(nL1x, lumaConv), dot(nL1y, lumaConv), dot(nL1z, lumaConv)) * _SpecularDirection.rgb;
        //     float focus = saturate(length(dominantDir));
        //     half3 halfDir = Unity_SafeNormalize(normalize(dominantDir) - viewDir);
        //     half nh = saturate(dot(normalWorld, halfDir));
        //     half spec = GGXTerm(nh, roughness);

        //     sh = L0 + dominantDir.x * L1x + dominantDir.y * L1y + dominantDir.z * L1z;

        //     specularColor = saturate(specularColor + max(spec * sh, 0.0));
        // #endif
    }

    // BOTTOM
    [unroll(3)]
    for (i = 0; i < 3; i++) {
        float2 giuv;
        [flatten]
        switch (i) {
            case 0:
                giuv = float2(0.01, 0.95);
                break;
            case 1:
                giuv = float2(0.5, 0.95);
                break;
            case 2:
                giuv = float2(0.99, 0.95);
                break;
        }
        #if UNITY_UV_STARTS_AT_TOP
        giuv.y = 1 - giuv.y;
        #endif
        float4 bakerytex = BakeryTex2D(_LM_GIJOE_1, sampler_LM_GIJOE_0, lmUV, _RNM0_TexelSize);
        float3 L0 = idx_float3(DecodeLightmap(bakerytex), i % 3);
        float3 giColor = tex2Dlod(_GIJOE_INPUT, float4(giuv, 9, 9 /* empirically determined */));
        L0 *= pow(giColor, 1.15) + 0.005;
        float3 nL1x = idx_float3(BakeryTex2D(_RNM0_GIJOE_1, sampler_LM_GIJOE_0, lmUV, _RNM0_TexelSize), i % 3) * 2 - 1;
        float3 nL1y = idx_float3(BakeryTex2D(_RNM1_GIJOE_1, sampler_LM_GIJOE_0, lmUV, _RNM0_TexelSize), i % 3) * 2 - 1;
        float3 nL1z = idx_float3(BakeryTex2D(_RNM2_GIJOE_1, sampler_LM_GIJOE_0, lmUV, _RNM0_TexelSize), i % 3) * 2 - 1;
        float3 L1x = nL1x * L0 * 2;
        float3 L1y = nL1y * L0 * 2;
        float3 L1z = nL1z * L0 * 2;
        float3 sh = L0 + normalWorld.x * L1x + normalWorld.y * L1y + normalWorld.z * L1z;
        diffuseColor = saturate(diffuseColor + max(sh, 0.0));

        #ifdef BAKERY_LMSPEC
            float3 dominantDir = float3(dot(nL1x, lumaConv), dot(nL1y, lumaConv), dot(nL1z, lumaConv)) * _SpecularDirection.rgb;
            float focus = saturate(length(dominantDir));
            half3 halfDir = Unity_SafeNormalize(normalize(dominantDir) - viewDir);
            half nh = saturate(dot(normalWorld, halfDir));
            half spec = GGXTerm(nh, roughness);

            sh = L0 + dominantDir.x * L1x + dominantDir.y * L1y + dominantDir.z * L1z;

            specularColor = saturate(specularColor + max(spec * sh, 0.0));
        #endif
    }
}
#endif // BAKERY_SH_GIJOE

void BakerySH(inout float3 diffuseColor, inout float3 specularColor, float2 lmUV, float3 normalWorld, float3 viewDir, float perceptualRoughness, float3 worldPos)
{
#ifdef SHADER_API_D3D11
    float3 L0 = DecodeLightmap(BakeryTex2D(unity_Lightmap, samplerunity_Lightmap, lmUV, _RNM0_TexelSize));
#else
    float3 L0 = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, lmUV));
#endif
    float3 nL1x = BakeryTex2D(_RNM0, lmUV, _RNM0_TexelSize) * 2 - 1;
    float3 nL1y = BakeryTex2D(_RNM1, lmUV, _RNM0_TexelSize) * 2 - 1;
    float3 nL1z = BakeryTex2D(_RNM2, lmUV, _RNM0_TexelSize) * 2 - 1;
    float3 L1x = nL1x * L0 * 2;
    float3 L1y = nL1y * L0 * 2;
    float3 L1z = nL1z * L0 * 2;

    float3 sh;
#ifdef BAKERY_SHNONLINEAR
    float lumaL0 = dot(L0, float(1));
    float lumaL1x = dot(L1x, float(1));
    float lumaL1y = dot(L1y, float(1));
    float lumaL1z = dot(L1z, float(1));
    float lumaSH = shEvaluateDiffuseL1Geomerics(lumaL0, float3(lumaL1x, lumaL1y, lumaL1z), normalWorld);

    sh = L0 + normalWorld.x * L1x + normalWorld.y * L1y + normalWorld.z * L1z;
    float regularLumaSH = dot(sh, 1);
    //sh *= regularLumaSH < 0.001 ? 1 : (lumaSH / regularLumaSH);
    sh *= lerp(1, lumaSH / regularLumaSH, saturate(regularLumaSH*16));

    //sh.r = shEvaluateDiffuseL1Geomerics(L0.r, float3(L1x.r, L1y.r, L1z.r), normalWorld);
    //sh.g = shEvaluateDiffuseL1Geomerics(L0.g, float3(L1x.g, L1y.g, L1z.g), normalWorld);
    //sh.b = shEvaluateDiffuseL1Geomerics(L0.b, float3(L1x.b, L1y.b, L1z.b), normalWorld);

#else
    sh = L0 + normalWorld.x * L1x + normalWorld.y * L1y + normalWorld.z * L1z;
#endif

    diffuseColor = max(sh, 0.0);

    #ifdef BAKERY_LMSPEC
        float3 dominantDir = float3(dot(nL1x, lumaConv), dot(nL1y, lumaConv), dot(nL1z, lumaConv));
        float focus = saturate(length(dominantDir));
        half3 halfDir = Unity_SafeNormalize(normalize(dominantDir) - viewDir);
        half nh = saturate(dot(normalWorld, halfDir));
        half roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
        half spec = GGXTerm(nh, roughness);

        sh = L0 + dominantDir.x * L1x + dominantDir.y * L1y + dominantDir.z * L1z;

        specularColor = max(spec * sh, 0.0);
    #endif
}
#endif
#endif