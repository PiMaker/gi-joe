using UnityEditor;
using UnityEngine;
using System.Collections.Generic;
using System;
using System.Reflection;

namespace z3y
{
    public partial class LitFoldoutDictionary
    {
        public bool AnimatedProps = false;

        public bool ShowSurfaceInputs = true;
        public bool ShowSpecular = false;
        public bool ShowAdvanced = false;
        public bool ShowBakedLight = false;
        public bool ShowShaderFeatures = false;

        public bool Show_MainTex = false;
        public bool Show_MetallicGlossMap = false;
        public bool Show_BumpMap = false;
        public bool Show_EmissionMap = false;
        public bool Show_DetailMap = false;
        public bool Show_AnisotropyMap = false;

        public bool Show_MetallicMap = false;
        public bool Show_SmoothnessMap = false;
        public bool Show_OcclusionMap = false;


    }
    
    public class LitShaderEditor : ShaderGUI
    {
        protected MaterialProperty _MainTex = null;
        protected MaterialProperty _Color = null;
        protected MaterialProperty _Saturation = null;
        protected MaterialProperty _MainTexUV = null;
        protected MaterialProperty _SuperSamplingBias = null;
        protected MaterialProperty _Metallic = null;
        protected MaterialProperty _Glossiness = null;
        protected MaterialProperty _Occlusion = null;
        protected MaterialProperty _MetallicGlossMap = null;
        protected MaterialProperty _MetallicGlossMapUV = null;
        protected MaterialProperty _BumpMap = null;
        protected MaterialProperty _BumpScale = null;
        protected MaterialProperty _BumpMapUV = null;
        protected MaterialProperty _NormalMapOrientation = null;
        protected MaterialProperty _EmissionMap = null;
        protected MaterialProperty _EmissionColor = null;
        protected MaterialProperty _EmissionMapUV = null;
        protected MaterialProperty _EnableEmission = null;
        protected MaterialProperty _EmissionMultBase = null;
        protected MaterialProperty _EnableNormalMap = null;
        protected MaterialProperty _HemiOctahedron = null;
        protected MaterialProperty _SpecularHighlights = null;
        protected MaterialProperty _GlossyReflections = null;
        protected MaterialProperty _Reflectance = null;
        protected MaterialProperty _Mode = null;
        protected MaterialProperty _AlphaToMask = null;
        protected MaterialProperty _Cutoff = null;
        protected MaterialProperty _GSAA = null;
        protected MaterialProperty _specularAntiAliasingVariance = null;
        protected MaterialProperty _specularAntiAliasingThreshold = null;
        protected MaterialProperty _FresnelColor = null;
        protected MaterialProperty _BicubicLightmap = null;
        protected MaterialProperty _LightmapMultiplier = null;
        protected MaterialProperty _SpecularOcclusion = null;
        protected MaterialProperty _SpecularOcclusionSensitivity = null;
        protected MaterialProperty _LightProbeMethod = null;
        protected MaterialProperty _SpecularDirection = null;

        protected MaterialProperty _EnableAnisotropy = null;
        protected MaterialProperty _Anisotropy = null;
        protected MaterialProperty _AnisotropyMap = null;

        protected MaterialProperty _Cull = null;

        protected MaterialProperty _EnablePackedMode = null;
        protected MaterialProperty _SmoothnessMap = null;
        protected MaterialProperty _SmoothnessMapUV = null;
        protected MaterialProperty _GlossinessInvert = null;
        protected MaterialProperty _MetallicMap = null;
        protected MaterialProperty _MetallicMapUV = null;
        protected MaterialProperty _OcclusionMap = null;
        protected MaterialProperty _OcclusionMapUV = null;

        protected MaterialProperty _EnableParallax = null;
        protected MaterialProperty _Parallax = null;
        protected MaterialProperty _ParallaxMap = null;
        protected MaterialProperty _ParallaxSteps = null;
        protected MaterialProperty _ParallaxOffset = null;

        protected MaterialProperty _DetailMap = null;
        protected MaterialProperty _DetailMapUV = null;
        protected MaterialProperty _DetailAlbedoScale = null;
        protected MaterialProperty _DetailNormalScale = null;
        protected MaterialProperty _DetailSmoothnessScale = null;

        protected MaterialProperty _EnableAudioLink = null;
        protected MaterialProperty _ALSmoothing = null;
        protected MaterialProperty _AudioTexture = null;

        protected MaterialProperty _ALEmissionBand = null;
        protected MaterialProperty _ALEmissionType = null;
        protected MaterialProperty _ALEmissionMap = null;
        
        protected MaterialProperty _BAKERY_SH = null;
        protected MaterialProperty _BAKERY_SHNONLINEAR = null;
        protected MaterialProperty _BAKERY_RNM = null;
        protected MaterialProperty _BAKERY_LMSPEC = null;

        protected MaterialProperty _BAKERY_SH_GIJOE = null;
        protected MaterialProperty _GIJOE_INPUT = null;
        protected MaterialProperty _LM_GIJOE_0 = null;
        protected MaterialProperty _RNM0_GIJOE_0 = null;
        protected MaterialProperty _RNM1_GIJOE_0 = null;
        protected MaterialProperty _RNM2_GIJOE_0 = null;
        protected MaterialProperty _LM_GIJOE_1 = null;
        protected MaterialProperty _RNM0_GIJOE_1 = null;
        protected MaterialProperty _RNM1_GIJOE_1 = null;
        protected MaterialProperty _RNM2_GIJOE_1 = null;
        protected MaterialProperty _LM_GIJOE_2 = null;
        protected MaterialProperty _RNM0_GIJOE_2 = null;
        protected MaterialProperty _RNM1_GIJOE_2 = null;
        protected MaterialProperty _RNM2_GIJOE_2 = null;
        protected MaterialProperty _LM_GIJOE_3 = null;
        protected MaterialProperty _RNM0_GIJOE_3 = null;
        protected MaterialProperty _RNM1_GIJOE_3 = null;
        protected MaterialProperty _RNM2_GIJOE_3 = null;
        protected MaterialProperty _LM_GIJOE_4 = null;
        protected MaterialProperty _RNM0_GIJOE_4 = null;
        protected MaterialProperty _RNM1_GIJOE_4 = null;
        protected MaterialProperty _RNM2_GIJOE_4 = null;
        protected MaterialProperty _LM_GIJOE_5 = null;
        protected MaterialProperty _RNM0_GIJOE_5 = null;
        protected MaterialProperty _RNM1_GIJOE_5 = null;
        protected MaterialProperty _RNM2_GIJOE_5 = null;

        protected MaterialProperty bakeryLightmapMode = null;
        protected MaterialProperty _RNM0 = null;
        protected MaterialProperty _RNM1 = null;
        protected MaterialProperty _RNM2 = null;

        protected MaterialProperty _LodCrossFade = null;
        protected MaterialProperty _FlatShading = null;

        protected MaterialProperty _BlendOp = null;
        protected MaterialProperty _BlendOpAlpha = null;
        protected MaterialProperty _SrcBlend = null;
        protected MaterialProperty _DstBlend = null;

        protected MaterialProperty _CentroidNormal = null;
        
        protected MaterialProperty _SpecularWorkflow = null;
        protected MaterialProperty _SpecGlossMap = null;
        protected MaterialProperty _SpecColor = null;
        protected MaterialProperty _SpecGlossMapUV = null;

        protected MaterialProperty _EnableDisplacement = null;
        protected MaterialProperty _DisplacementMask = null;
        protected MaterialProperty _DisplacementMaskUV = null;
        protected MaterialProperty _DisplacementIntensity = null;
        protected MaterialProperty _DisplacementNoise = null;
        protected MaterialProperty _DisplacementNoisePan = null;
        protected MaterialProperty _RandomizePosition = null;

        protected MaterialProperty _BakeUnityKeywords = null;

        protected MaterialProperty _SubsurfaceScattering = null;
        protected MaterialProperty _Scale = null;
        protected MaterialProperty _Power = null;
        protected MaterialProperty _ThicknessMap = null;
        protected MaterialProperty _ThicknessMapUV = null;
        protected MaterialProperty _SubsurfaceTint = null;

        protected MaterialProperty _GIJoeReflProbe = null;

        protected string GIJoeDir = "TheaterStatic_Joe", GIJoeGroup = "GroundPlane";




        public void ShaderPropertiesGUI(Material material)
        {
            #if UNITY_ANDROID && (VRC_SDK_VRCSDK2 || VRC_SDK_VRCSDK3)
            EditorGUILayout.HelpBox("This shader is not supported on Quest", MessageType.Warning);
            EditorGUILayout.Space();
            #endif
            
            
            md[material].ShowSurfaceInputs = Foldout("Surface Inputs", md[material].ShowSurfaceInputs, ()=> {

                EditorGUI.BeginChangeCheck();
                prop(_Mode);
                if (EditorGUI.EndChangeCheck())
                {
                    if(me.targets.Length > 1)
                        foreach(Material m in me.targets)
                        {
                            Func.SetupMaterialWithBlendMode(m, _Mode.floatValue);
                        }
                    else
                        Func.SetupMaterialWithBlendMode(material, _Mode.floatValue);
                }


                if(_Mode.floatValue == 1){
                    prop(_AlphaToMask);
                    prop(_Cutoff);
                }
                EditorGUILayout.Space();;

                prop(_MainTex, _Color);

                md[material].Show_MainTex = Func.TriangleFoldout(md[material].Show_MainTex, ()=> {
                    prop(_MainTexUV);
                    propTileOffset(_MainTex);
                    if(_MainTexUV.floatValue == 6) prop(_SuperSamplingBias);
                    prop(_Saturation);
                });

            
                if(_EnablePackedMode.floatValue == 1)
                {
                    prop(_Metallic);
                    prop(_Glossiness);

                    if (_MetallicGlossMap.textureValue || _EnablePackedMode.floatValue == 0) prop(_Occlusion);

                
                    prop(_MetallicGlossMap);
                    md[material].Show_MetallicGlossMap = Func.TriangleFoldout(md[material].Show_MetallicGlossMap, ()=> {
                        prop(_MetallicGlossMapUV);
                        if(_MetallicGlossMapUV.floatValue != 0) propTileOffset(_MetallicGlossMap);
                    });
                    Func.sRGBWarning(_MetallicGlossMap);
                }
                else
                {
                    prop(_MetallicMap, _Metallic);
                    md[material].Show_MetallicMap = Func.TriangleFoldout(md[material].Show_MetallicMap, ()=> {
                        prop(_MetallicMapUV);
                        if(_MetallicMapUV.floatValue != 0)  propTileOffset(_MetallicMap);
                    });
                    Func.sRGBWarning(_MetallicMap);
                    
                    prop(_SmoothnessMap, _Glossiness);
                    md[material].Show_SmoothnessMap = Func.TriangleFoldout(md[material].Show_SmoothnessMap, ()=> {
                        prop(_SmoothnessMapUV);
                        if(_SmoothnessMapUV.floatValue != 0) propTileOffset(_SmoothnessMap);
                        
                        prop(_GlossinessInvert);
                    });
                    Func.sRGBWarning(_SmoothnessMap);
                    
                    prop(_OcclusionMap, _Occlusion);
                    md[material].Show_OcclusionMap = Func.TriangleFoldout(md[material].Show_OcclusionMap, ()=> {
                        prop(_OcclusionMapUV);
                        if(_OcclusionMapUV.floatValue != 0) propTileOffset(_OcclusionMap);
                        
                    });
                    Func.sRGBWarning(_OcclusionMapUV);
                }




                prop(_BumpMap, _BumpMap.textureValue ? _BumpScale : null);

                md[material].Show_BumpMap = Func.TriangleFoldout(md[material].Show_BumpMap, ()=> {
                    prop(_BumpMapUV);
                    if(_BumpMapUV.floatValue != 0) propTileOffset(_BumpMap);
                    
                    prop(_NormalMapOrientation);
                    prop(_HemiOctahedron);
                });
                

                prop(_DetailMap);
                md[material].Show_DetailMap = Func.TriangleFoldout(md[material].Show_DetailMap, ()=> {
                    prop(_DetailMapUV);
                    if(_DetailMapUV.floatValue != 0) propTileOffset(_DetailMap);
                    
                    prop(_DetailAlbedoScale);
                    prop(_DetailNormalScale);
                    prop(_DetailSmoothnessScale);
                });


                


            });

            md[material].ShowSpecular = Foldout("Specular Reflections", md[material].ShowSpecular, ()=> {
                prop(_SpecularWorkflow);

                if(_SpecularWorkflow.floatValue == 1)
                {
                    prop(_SpecGlossMap, _SpecColor);
                    Func.PropertyGroup(() => {
                    prop(_SpecGlossMapUV);
                    propTileOffset(_SpecGlossMap);
                    });
                }

                else
                {
                    prop(_FresnelColor);
                }
                prop(_Reflectance);

                EditorGUILayout.Space();
                prop(_GIJoeReflProbe);
                
                EditorGUILayout.Space();
                prop(_GlossyReflections);
                prop(_SpecularHighlights);
            });

            md[material].ShowShaderFeatures = Foldout("Shader Features", md[material].ShowShaderFeatures, ()=> {

                prop(_EnableEmission);
                if(_EnableEmission.floatValue == 1)
                {
                    Func.PropertyGroup(() => {
                        prop(_EmissionMap, _EmissionColor);

                        md[material].Show_EmissionMap = Func.TriangleFoldout(md[material].Show_EmissionMap, ()=> {
                            prop(_EmissionMapUV);
                            if(_EmissionMapUV.floatValue != 0) propTileOffset(_EmissionMap);
                            
                        });
                        me.LightmapEmissionProperty();
                        prop(_EmissionMultBase);


                        if(_EnableAudioLink.floatValue == 1)
                        {
                            EditorGUILayout.Space();;
                            prop(_ALEmissionType);
                            if(_ALEmissionType.floatValue != 0){
                                prop(_ALEmissionBand);
                                prop(_ALEmissionMap);
                                Func.sRGBWarning(_ALEmissionMap);
                            }
                        }
                    });
                }

                prop(_EnableParallax);
                if(_EnableParallax.floatValue == 1)
                {
                    Func.PropertyGroup(() => {
                        prop(_ParallaxMap, _Parallax);
                        Func.sRGBWarning(_ParallaxMap);
                        prop(_ParallaxOffset);
                        prop(_ParallaxSteps);
                    });
                }

                prop(_EnableAnisotropy);
                if(_EnableAnisotropy.floatValue == 1)
                {
                    Func.PropertyGroup(() => {
                        prop(_Anisotropy);
                        prop(_AnisotropyMap);
                        md[material].Show_AnisotropyMap = Func.TriangleFoldout(md[material].Show_AnisotropyMap, ()=> {
                            propTileOffset(_AnisotropyMap);
                        });
                        Func.sRGBWarning(_AnisotropyMap);
                    });
                }
                

                prop(_GSAA);
                if(_GSAA.floatValue == 1){
                    Func.PropertyGroup(() => {
                        prop(_specularAntiAliasingVariance);
                        prop(_specularAntiAliasingThreshold);
                    });
                };

                prop(_EnableAudioLink);
                if(_EnableAudioLink.floatValue == 1){
                    Func.PropertyGroup(() => {
                    prop(_AudioTexture);
                    prop(_ALSmoothing);
                    });
                };

                prop(_LodCrossFade);
                prop(_FlatShading);

                prop(_EnableDisplacement);
                if(_EnableDisplacement.floatValue == 1)
                {
                    Func.PropertyGroup(() => {
                        prop(_DisplacementMaskUV);
                        prop(_DisplacementMask);
                        Func.sRGBWarning(_DisplacementMask);
                        prop(_DisplacementIntensity);
                        prop(_DisplacementNoise);
                        Func.sRGBWarning(_DisplacementNoise);
                        prop(_DisplacementNoisePan);
                        prop(_RandomizePosition);
                        if(!material.enableInstancing && _RandomizePosition.floatValue==1) EditorGUILayout.LabelField("Enable GPU Instancing or disable batching to use random panning", EditorStyles.boldLabel);
                    });
                }

                prop(_SubsurfaceScattering);
                if(_SubsurfaceScattering.floatValue == 1){
                    Func.PropertyGroup(() => {
                        prop(_ThicknessMap, _SubsurfaceTint);
                        Func.sRGBWarning(_ThicknessMap);
                        prop(_ThicknessMapUV);
                        if(_ThicknessMapUV.floatValue != 0) propTileOffset(_ThicknessMap);
                        prop(_Scale);
                        prop(_Power);

                    });
                };

            });

            md[material].ShowBakedLight = Foldout("Baked Light", md[material].ShowBakedLight, ()=> {
                prop(_SpecularOcclusion);
                prop(_SpecularOcclusionSensitivity);
                prop(_LightmapMultiplier);
                prop(_LightProbeMethod);
                prop(_BicubicLightmap);
                prop(_BAKERY_LMSPEC);
                if(false && _BAKERY_LMSPEC.floatValue == 1)
                {
                    prop(_SpecularDirection);
                }
                
                #if BAKERY_INCLUDED
                Func.PropertyGroup(() => {
                    EditorGUILayout.LabelField("Bakery", EditorStyles.boldLabel);
                    prop(_BAKERY_SH);
                    prop(_BAKERY_SHNONLINEAR);
                    prop(_BAKERY_RNM);
                    //prop(_BakeryL0);
                    EditorGUI.BeginDisabledGroup(false);
                    if(_BAKERY_SH.floatValue == 1 || _BAKERY_RNM.floatValue == 1)
                    {
                        prop(bakeryLightmapMode);
                        prop(_RNM0);
                        prop(_RNM1);
                        prop(_RNM2);
                    }
                    EditorGUI.EndDisabledGroup();
                    prop(_BAKERY_SH_GIJOE);
                    if(_BAKERY_SH_GIJOE.floatValue == 1)
                    {
                        EditorGUI.BeginDisabledGroup(isLocked);
                        var go = GIJoeDir = GUILayout.TextField(GIJoeDir);
                        var gr = GIJoeGroup = GUILayout.TextField(GIJoeGroup);
                        if (GUILayout.Button("Auto-Fill"))
                        {
                            //_GIJOE_INPUT.textureValue = AssetDatabase.LoadAssetAtPath<RenderTexture>("Assets/Video.renderTexture");
                            _LM_GIJOE_0.textureValue = AssetDatabase.LoadAssetAtPath<Texture2D>($"Assets/BakeryLightmaps_{go}_0/LMGroup_{gr}_L0.hdr");
                            _RNM0_GIJOE_0.textureValue = AssetDatabase.LoadAssetAtPath<Texture2D>($"Assets/BakeryLightmaps_{go}_0/LMGroup_{gr}_L1x.tga");
                            _RNM1_GIJOE_0.textureValue = AssetDatabase.LoadAssetAtPath<Texture2D>($"Assets/BakeryLightmaps_{go}_0/LMGroup_{gr}_L1y.tga");
                            _RNM2_GIJOE_0.textureValue = AssetDatabase.LoadAssetAtPath<Texture2D>($"Assets/BakeryLightmaps_{go}_0/LMGroup_{gr}_L1z.tga");
                            _LM_GIJOE_1.textureValue = AssetDatabase.LoadAssetAtPath<Texture2D>($"Assets/BakeryLightmaps_{go}_1/LMGroup_{gr}_L0.hdr");
                            _RNM0_GIJOE_1.textureValue = AssetDatabase.LoadAssetAtPath<Texture2D>($"Assets/BakeryLightmaps_{go}_1/LMGroup_{gr}_L1x.tga");
                            _RNM1_GIJOE_1.textureValue = AssetDatabase.LoadAssetAtPath<Texture2D>($"Assets/BakeryLightmaps_{go}_1/LMGroup_{gr}_L1y.tga");
                            _RNM2_GIJOE_1.textureValue = AssetDatabase.LoadAssetAtPath<Texture2D>($"Assets/BakeryLightmaps_{go}_1/LMGroup_{gr}_L1z.tga");
                        }
                        EditorGUI.EndDisabledGroup();
                        prop(_GIJOE_INPUT);
                        prop(_LM_GIJOE_0);
                        prop(_RNM0_GIJOE_0);
                        prop(_RNM1_GIJOE_0);
                        prop(_RNM2_GIJOE_0);
                        prop(_LM_GIJOE_1);
                        prop(_RNM0_GIJOE_1);
                        prop(_RNM1_GIJOE_1);
                        prop(_RNM2_GIJOE_1);
                    }
                });
                #endif
            });


            md[material].ShowAdvanced = Foldout("Advanced", md[material].ShowAdvanced, ()=> {
                Func.PropertyGroup(() => {
                prop(_BlendOp);
                prop(_BlendOpAlpha);
                prop(_SrcBlend);
                prop(_DstBlend);
                });
                EditorGUILayout.Space();

                prop(_Cull);
                prop(_BakeUnityKeywords);
                prop(_EnablePackedMode);
                prop(_CentroidNormal);
                me.DoubleSidedGIField();
                me.EnableInstancingField();
                me.RenderQueueField();
                EditorGUILayout.Space();;
                ListAnimatedProps();
            });

            

            


            
        }

        // On inspector change
        private void ApplyChanges()
        {
            Func.SetupGIFlags(_EnableEmission.floatValue, material);

            if(wAg6H2wQzc7UbxaL.floatValue != 0) return;
        }

        protected static Dictionary<Material, LitFoldoutDictionary> md = new Dictionary<Material, LitFoldoutDictionary>();
        protected BindingFlags bindingFlags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static;
        MaterialEditor me;
        public bool m_FirstTimeApply = true;
        protected MaterialProperty wAg6H2wQzc7UbxaL = null;

        public bool isLocked;
        Material material = null;
        MaterialProperty[] allProps;

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            FindProperties(props);
            me = materialEditor;
            material = materialEditor.target as Material;
            SetupFoldoutDictionary(material);
            allProps = props;

            if (m_FirstTimeApply)
            {
                m_FirstTimeApply = false;
            }
            
            Func.ShaderOptimizerButton(wAg6H2wQzc7UbxaL, me);
            isLocked = wAg6H2wQzc7UbxaL.floatValue == 1;
            EditorGUI.BeginChangeCheck();
            EditorGUI.indentLevel++;

            ShaderPropertiesGUI(material);

            if (EditorGUI.EndChangeCheck()) {
                ApplyChanges();
            };
        }

        private void prop(MaterialProperty property) => Func.MaterialProp(property, null, me, isLocked, material);
        private void prop(MaterialProperty property, MaterialProperty extraProperty) => Func.MaterialProp(property, extraProperty, me, isLocked, material);
        
        private void propTileOffset(MaterialProperty property) => Func.propTileOffset(property, isLocked, me, material);
        private void ListAnimatedProps() => Func.ListAnimatedProps(isLocked, allProps, material);
        private bool Foldout(string foldoutText, bool foldoutName, Action action) => Func.Foldout(foldoutText, foldoutName, action);

        

        private void SetupFoldoutDictionary(Material material)
        {
            if (md.ContainsKey(material)) return;

            LitFoldoutDictionary toggles = new LitFoldoutDictionary();
            md.Add(material, toggles);
        }
        
        public void FindProperties(MaterialProperty[] props)
        {
            //Find all material properties listed in the script using reflection, and set them using a loop only if they're of type MaterialProperty.
            //This makes things a lot nicer to maintain and cleaner to look at.
            foreach (var property in GetType().GetFields(bindingFlags))
            {
                if (property.FieldType == typeof(MaterialProperty))
                {
                    try { property.SetValue(this, FindProperty(property.Name, props)); } catch { /*Is it really a problem if it doesn't exist?*/ }
                }
            }
        }
        public static string litShaderName = "z3y/lit";

       // [MenuItem("Tools/Lit/Standard -> Lit")]
        public static void SwitchToLit()
        {
            Material[] mats = ShaderOptimizer.GetAllMaterialsWithShader("Standard");

            Shader lit = Shader.Find(litShaderName);

            for (int i=0; i<mats.Length; i++)
            {
                Func.SetupMaterialWithBlendMode(mats[i], mats[i].GetFloat("_Mode"));
                mats[i].shader = lit;
            }
        }

       // [MenuItem("Tools/Lit/Lit -> Standard")]
        public static void SwitchToStandard()
        {
            Material[] mats = ShaderOptimizer.GetAllMaterialsWithShader(litShaderName);

            Shader standard = Shader.Find("Standard");

            for (int i=0; i<mats.Length; i++)
            {
                mats[i].shader = standard;
            }
        }
    }
}