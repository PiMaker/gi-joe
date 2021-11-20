// https://github.com/Xiexe/Unity-Lit-Shader-Templates/blob/master/LICENSE
// https://github.com/google/filament/blob/main/LICENSE
#define grayscaleVec half3(0.2125, 0.7154, 0.0721)
#define TAU 6.28318530718
float pow5(float x) {
    float x2 = x * x;
    return x2 * x2 * x;
}

float sq(float x) {
    return x * x;
}

half D_GGX(half NoH, half roughness) {
    half a = NoH * roughness;
    half k = roughness / (1.0 - NoH * NoH + a * a);
    return k * k * (1.0 / UNITY_PI);
}


float D_GGX_Anisotropic(float at, float ab, float ToH, float BoH, float NoH) {
    // Burley 2012, "Physically-Based Shading at Disney"

    // The values at and ab are perceptualRoughness^2, a2 is therefore perceptualRoughness^4
    // The dot product below computes perceptualRoughness^8. We cannot fit in fp16 without clamping
    // the roughness to too high values so we perform the dot product and the division in fp32
    float a2 = at * ab;
    float3 d = float3(ab * ToH, at * BoH, a2 * NoH);
    float d2 = dot(d, d);
    float b2 = a2 / d2;
    return a2 * b2 * b2 * (1.0 / UNITY_PI);
}

float V_SmithGGXCorrelated_Anisotropic(float at, float ab, float ToV, float BoV, float ToL, float BoL, float NoV, float NoL) {
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    // TODO: lambdaV can be pre-computed for all the lights, it should be moved out of this function
    float lambdaV = NoL * length(float3(at * ToV, ab * BoV, NoV));
    float lambdaL = NoV * length(float3(at * ToL, ab * BoL, NoL));
    float v = 0.5 / (lambdaV + lambdaL);
    return saturate(v);
}

half V_Kelemen(half LoH) {
    return 0.25 / (LoH * LoH);
}

float3 F_Schlick(float u, float3 f0)
{
    return f0 + (1.0 - f0) * pow(1.0 - u, 5.0);
}

float F_Schlick(float f0, float f90, float VoH) {
    return f0 + (f90 - f0) * pow5(1.0 - VoH);
}

float Fd_Burley(float roughness, float NoV, float NoL, float LoH)
{
    // Burley 2012, "Physically-Based Shading at Disney"
    float f90 = 0.5 + 2.0 * roughness * LoH * LoH;
    float lightScatter = F_Schlick(1.0, f90, NoL);
    float viewScatter  = F_Schlick(1.0, f90, NoV);
    return lightScatter * viewScatter;
}

// Energy conserving wrap diffuse term, does *not* include the divide by pi
float Fd_Wrap(float NoL, float w) {
    return saturate((NoL + w) / sq(1.0 + w));
}

float V_SmithGGXCorrelated(float NoV, float NoL, float roughness) {
    float a2 = roughness * roughness;
    float GGXV = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float GGXL = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / (GGXV + GGXL);
}

half V_SmithGGXCorrelatedFast(half NoV, half NoL, half roughness) {
    half a = roughness;
    half GGXV = NoL * (NoV * (1.0 - a) + a);
    half GGXL = NoV * (NoL * (1.0 - a) + a);
    return 0.5 / (GGXV + GGXL);
}

float D_Ashikhmin(float roughness, float NoH) {
    // Ashikhmin 2007, "Distribution-based BRDFs"
	float a2 = roughness * roughness;
	float cos2h = NoH * NoH;
	float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
	float sin4h = sin2h * sin2h;
	float cot2 = -cos2h / (a2 * sin2h);
	return 1.0 / (UNITY_PI * (4.0 * a2 + 1.0) * sin4h) * (4.0 * exp(cot2) + sin4h);
}

float D_Charlie(float roughness, float NoH) {
    // Estevez and Kulla 2017, "Production Friendly Microfacet Sheen BRDF"
    float invAlpha  = 1.0 / roughness;
    float cos2h = NoH * NoH;
    float sin2h = max(1.0 - cos2h, 0.0078125); // 2^(-14/2), so sin2h^2 > 0 in fp16
    return (2.0 + invAlpha) * pow(sin2h, invAlpha * 0.5) / (2.0 * UNITY_PI);
}

float V_Neubelt(float NoV, float NoL) {
    // Neubelt and Pettineo 2013, "Crafting a Next-gen Material Pipeline for The Order: 1886"
    return saturate(1.0 / (4.0 * (NoL + NoV - NoL * NoV)));
}

float Fd_Lambert()
{
    return 1.0 / UNITY_PI;
}

float shEvaluateDiffuseL1Geomerics_local(float L0, float3 L1, float3 n)
{
    // average energy
    float R0 = max(0, L0);
    
    // avg direction of incoming light
    float3 R1 = 0.5f * L1;
    
    // directional brightness
    float lenR1 = length(R1);
    
    // linear angle between normal and direction 0-1
    //float q = 0.5f * (1.0f + dot(R1 / lenR1, n));
    //float q = dot(R1 / lenR1, n) * 0.5 + 0.5;
    float q = dot(normalize(R1), n) * 0.5 + 0.5;
    q = saturate(q); // Thanks to ScruffyRuffles for the bug identity.
    
    // power for q
    // lerps from 1 (linear) to 3 (cubic) based on directionality
    float p = 1.0f + 2.0f * lenR1 / R0;
    
    // dynamic range constant
    // should vary between 4 (highly directional) and 0 (ambient)
    float a = (1.0f - lenR1 / R0) / (1.0f + lenR1 / R0);
    
    return R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p));
}



float3 getBoxProjection (float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
{
#ifndef SHADER_API_MOBILE
     #if defined(UNITY_SPECCUBE_BOX_PROJECTION)
        if (cubemapPosition.w > 0) {
            float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
            float scalar = min(min(factors.x, factors.y), factors.z);
            direction = direction * scalar + (position - cubemapPosition);
        }
    #endif
#endif
    return direction;
}


float3 getAnisotropicReflectionVector(float3 viewDir, float3 bitangent, float3 tangent, float3 normal, float roughness)
{
    float3 anisotropicDirection = (_Anisotropy >= 0.0 ? pixel.anisotropicB : pixel.anisotropicT);
    float3 anisotropicTangent = cross(anisotropicDirection, viewDir);
    float3 anisotropicNormal = cross(anisotropicTangent, anisotropicDirection);
    float bendFactor = abs(_Anisotropy) * saturate(5.0 * roughness) ;
    float3 bentNormal = normalize(lerp(normal, anisotropicNormal, bendFactor));
    return reflect(-viewDir, bentNormal);
}

#ifdef DYNAMICLIGHTMAP_ON
float3 getRealtimeLightmap(float2 uv, float3 worldNormal, float2 parallaxOffset)
{
    float2 realtimeUV = uv * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw + parallaxOffset;
    half4 bakedCol = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, realtimeUV);
    float3 realtimeLightmap = DecodeRealtimeLightmap(bakedCol);

    #ifdef DIRLIGHTMAP_COMBINED
        half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, realtimeUV);
        realtimeLightmap += DecodeDirectionalLightmap (realtimeLightmap, realtimeDirTex, worldNormal);
    #endif

    return realtimeLightmap;
}
#endif


// w0, w1, w2, and w3 are the four cubic B-spline basis functions
float w0(float a)
{
    //    return (1.0f/6.0f)*(-a*a*a + 3.0f*a*a - 3.0f*a + 1.0f);
    return (1.0f/6.0f)*(a*(a*(-a + 3.0f) - 3.0f) + 1.0f);   // optimized
}

float w1(float a)
{
    //    return (1.0f/6.0f)*(3.0f*a*a*a - 6.0f*a*a + 4.0f);
    return (1.0f/6.0f)*(a*a*(3.0f*a - 6.0f) + 4.0f);
}

float w2(float a)
{
    //    return (1.0f/6.0f)*(-3.0f*a*a*a + 3.0f*a*a + 3.0f*a + 1.0f);
    return (1.0f/6.0f)*(a*(a*(-3.0f*a + 3.0f) + 3.0f) + 1.0f);
}

float w3(float a)
{
    return (1.0f/6.0f)*(a*a*a);
}

// g0 and g1 are the two amplitude functions
float g0(float a)
{
    return w0(a) + w1(a);
}

float g1(float a)
{
    return w2(a) + w3(a);
}

// h0 and h1 are the two offset functions
float h0(float a)
{
    // note +0.5 offset to compensate for CUDA linear filtering convention
    return -1.0f + w1(a) / (w0(a) + w1(a)) + 0.5f;
}

float h1(float a)
{
    return 1.0f + w3(a) / (w2(a) + w3(a)) + 0.5f;
}

//https://ndotl.wordpress.com/2018/08/29/baking-artifact-free-lightmaps
float3 tex2DFastBicubicLightmap(float2 uv, inout float4 bakedColorTex)
{
    #if defined(SHADER_API_D3D11) && defined(ENABLE_BICUBIC_LIGHTMAP)
    float width;
    float height;
    unity_Lightmap.GetDimensions(width, height);
    float x = uv.x * width;
    float y = uv.y * height;

    
    
    x -= 0.5f;
    y -= 0.5f;
    float px = floor(x);
    float py = floor(y);
    float fx = x - px;
    float fy = y - py;

    // note: we could store these functions in a lookup table texture, but maths is cheap
    float g0x = g0(fx);
    float g1x = g1(fx);
    float h0x = h0(fx);
    float h1x = h1(fx);
    float h0y = h0(fy);
    float h1y = h1(fy);

    float4 r = g0(fy) * ( g0x * UNITY_SAMPLE_TEX2D(unity_Lightmap, (float2(px + h0x, py + h0y) * 1.0f/width)) +
                         g1x * UNITY_SAMPLE_TEX2D(unity_Lightmap, (float2(px + h1x, py + h0y) * 1.0f/width))) +
                         g1(fy) * ( g0x * UNITY_SAMPLE_TEX2D(unity_Lightmap, (float2(px + h0x, py + h1y) * 1.0f/width)) +
                         g1x * UNITY_SAMPLE_TEX2D(unity_Lightmap, (float2(px + h1x, py + h1y) * 1.0f/width)));
    bakedColorTex = r;
    return DecodeLightmap(r);
    #else
    bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, uv);
    return DecodeLightmap(bakedColorTex);
    #endif
}


float GSAA_Filament(float3 worldNormal,float perceptualRoughness) {
    // Kaplanyan 2016, "Stable specular highlights"
    // Tokuyoshi 2017, "Error Reduction and Simplification for Shading Anti-Aliasing"
    // Tokuyoshi and Kaplanyan 2019, "Improved Geometric Specular Antialiasing"

    // This implementation is meant for deferred rendering in the original paper but
    // we use it in forward rendering as well (as discussed in Tokuyoshi and Kaplanyan
    // 2019). The main reason is that the forward version requires an expensive transform
    // of the half vector by the tangent frame for every light. This is therefore an
    // approximation but it works well enough for our needs and provides an improvement
    // over our original implementation based on Vlachos 2015, "Advanced VR Rendering".

    float3 du = ddx(worldNormal);
    float3 dv = ddy(worldNormal);

    float variance = _specularAntiAliasingVariance * (dot(du, du) + dot(dv, dv));

    float roughness = perceptualRoughness * perceptualRoughness;
    float kernelRoughness = min(2.0 * variance, _specularAntiAliasingThreshold);
    float squareRoughness = saturate(roughness * roughness + kernelRoughness);

    return sqrt(sqrt(squareRoughness));
}



float GSAA_Valve(float3 vGeometricNormalWs,float3 vRoughness)
{
    float3 vNormalWsDdx = ddx( vGeometricNormalWs.xyz );
    float3 vNormalWsDdy = ddy( vGeometricNormalWs.xyz );
    float flGeometricRoughnessFactor = pow( saturate( max( dot( vNormalWsDdx.xyz, vNormalWsDdx.xyz ), dot( vNormalWsDdy.xyz, vNormalWsDdy.xyz ) ) ), 0.333 );

    return flGeometricRoughnessFactor;
}

float computeSpecularAO(float NoV, float ao, float roughness) {
    return clamp(pow(NoV + ao, exp2(-16.0 * roughness - 1.0)) - 1.0 + ao, 0.0, 1.0);
}

//https://forum.unity.com/threads/fixing-screen-space-directional-shadows-and-anti-aliasing.379902/
/*
float SSDirectionalShadowAA(float4 _ShadowCoord, sampler2D_float depthTex, float4 depthTextureTexelSize, sampler2D _ShadowMapTexture, half atten){
    half a = atten;
    float2 screenUV = _ShadowCoord.xy / _ShadowCoord.w;
    half shadow = tex2D(_ShadowMapTexture, screenUV).r;

    if(frac(_Time.x) > 0.5)
	    a = shadow;

    float fragDepth = _ShadowCoord.z / _ShadowCoord.w;
    float depth_raw = tex2D(depthTex, screenUV).r;

    float depthDiff = abs(fragDepth - depth_raw);
    float diffTest = 1.0 / 100000.0;

    if (depthDiff > diffTest){
	    float2 texelSize = depthTextureTexelSize.xy;
    	float4 offsetDepths = 0;

	    float2 uvOffsets[5] = {
	    float2(1.0, 0.0) * texelSize,
	    float2(-1.0, 0.0) * texelSize,
	    float2(0.0, 1.0) * texelSize,
	    float2(0.0, -1.0) * texelSize,
	    float2(0.0, 0.0)
	    };

    	offsetDepths.x = tex2D(depthTex, screenUV + uvOffsets[0]).r;
    	offsetDepths.y = tex2D(depthTex, screenUV + uvOffsets[1]).r;
	    offsetDepths.z = tex2D(depthTex, screenUV + uvOffsets[2]).r;
	    offsetDepths.w = tex2D(depthTex, screenUV + uvOffsets[3]).r;

    	float4 offsetDiffs = abs(fragDepth - offsetDepths);

    	float diffs[4] = {offsetDiffs.x, offsetDiffs.y, offsetDiffs.z, offsetDiffs.w};

    	int lowest = 4;
    	float tempDiff = depthDiff;
    	for (int i=0; i<4; i++){
		    if(diffs[i] < tempDiff){
    			tempDiff = diffs[i];
				lowest = i;
		    }
	    }

    a = tex2D(_ShadowMapTexture, screenUV + uvOffsets[lowest]).r;
    }
    return a;
}
*/

#if defined(VERTEXLIGHT_ON) && defined(UNITY_PASS_FORWARDBASE)
//Lifted vertex light support from XSToon: https://github.com/Xiexe/Xiexes-Unity-Shaders
//Returns the average color of all lights and writes to a struct contraining individual colors
float3 get4VertexLightsColFalloff(inout VertexLightInformation vLight, float3 worldPos, float3 normal, inout float4 vertexLightAtten)
{
    float3 lightColor = 0;
    #if defined(VERTEXLIGHT_ON)
        float4 toLightX = unity_4LightPosX0 - worldPos.x;
        float4 toLightY = unity_4LightPosY0 - worldPos.y;
        float4 toLightZ = unity_4LightPosZ0 - worldPos.z;

        float4 lengthSq = 0;
        lengthSq += toLightX * toLightX;
        lengthSq += toLightY * toLightY;
        lengthSq += toLightZ * toLightZ;

        float4 atten = 1.0 / (1.0 + lengthSq * unity_4LightAtten0);
        float4 atten2 = saturate(1 - (lengthSq * unity_4LightAtten0 / 25));
        atten = min(atten, atten2 * atten2);
        // Cleaner, nicer looking falloff. Also prevents the "Snapping in" effect that Unity's normal integration of vertex lights has.
        vertexLightAtten = atten;

        lightColor.rgb += unity_LightColor[0] * atten.x;
        lightColor.rgb += unity_LightColor[1] * atten.y;
        lightColor.rgb += unity_LightColor[2] * atten.z;
        lightColor.rgb += unity_LightColor[3] * atten.w;

        vLight.ColorFalloff[0] = unity_LightColor[0] * atten.x;
        vLight.ColorFalloff[1] = unity_LightColor[1] * atten.y;
        vLight.ColorFalloff[2] = unity_LightColor[2] * atten.z;
        vLight.ColorFalloff[3] = unity_LightColor[3] * atten.w;

        vLight.Attenuation[0] = atten.x;
        vLight.Attenuation[1] = atten.y;
        vLight.Attenuation[2] = atten.z;
        vLight.Attenuation[3] = atten.w;
    #endif
    return lightColor;
}

//Returns the average direction of all lights and writes to a struct contraining individual directions
float3 getVertexLightsDir(inout VertexLightInformation vLights, float3 worldPos, float4 vertexLightAtten)
{
    float3 dir = float3(0,0,0);
    float3 toLightX = float3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
    float3 toLightY = float3(unity_4LightPosX0.y, unity_4LightPosY0.y, unity_4LightPosZ0.y);
    float3 toLightZ = float3(unity_4LightPosX0.z, unity_4LightPosY0.z, unity_4LightPosZ0.z);
    float3 toLightW = float3(unity_4LightPosX0.w, unity_4LightPosY0.w, unity_4LightPosZ0.w);

    float3 dirX = toLightX - worldPos;
    float3 dirY = toLightY - worldPos;
    float3 dirZ = toLightZ - worldPos;
    float3 dirW = toLightW - worldPos;

    dirX *= length(toLightX) * vertexLightAtten.x;
    dirY *= length(toLightY) * vertexLightAtten.y;
    dirZ *= length(toLightZ) * vertexLightAtten.z;
    dirW *= length(toLightW) * vertexLightAtten.w;

    vLights.Direction[0] = dirX;
    vLights.Direction[1] = dirY;
    vLights.Direction[2] = dirZ;
    vLights.Direction[3] = dirW;

    dir = (dirX + dirY + dirZ + dirW) / 4;
    return dir;
}
#endif