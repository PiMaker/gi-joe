/*
MIT License

Copyright (c) 2020 DarthShader

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;
using System;
using System.IO;
using System.Text.RegularExpressions;
using System.Text;
using System.Globalization;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEditor.Rendering;
using System.Linq;
using UnityEngine.SceneManagement;

#if VRC_SDK_VRCSDK3
using VRC.SDKBase;
#endif
#if VRC_SDK_VRCSDK2
using VRCSDK2;
#endif
#if VRC_SDK_VRCSDK2 || VRC_SDK_VRCSDK3
using VRC.SDKBase.Editor.BuildPipeline;
#endif


namespace z3y
{
    
    class AutoLockOnBuild : IPreprocessBuildWithReport
    {
        public int callbackOrder { get { return 69; } }
        public void OnPreprocessBuild(BuildReport report)
        {
            ShaderOptimizer.LockAllMaterials();
        }
    }

#if VRC_SDK_VRCSDK2 || VRC_SDK_VRCSDK3
    public class LockMaterialsOnVRCWorldUpload : IVRCSDKBuildRequestedCallback
    {
        public int callbackOrder => 69;

        bool IVRCSDKBuildRequestedCallback.OnBuildRequested(VRCSDKRequestedBuildType requestedBuildType)
        {
            ShaderOptimizer.LockAllMaterials();
            return true;
        }
    }
#endif

    public class OnShaderPreprocess : IPreprocessShaders
    {
        public int callbackOrder { get { return 69; } }

        public void OnProcessShader(Shader shader, ShaderSnippetData snippet, IList<ShaderCompilerData> data)
        {
            bool shouldStrip = false;

            bool usingOptimizer = false;
            try 
            {
                usingOptimizer = ShaderUtil.GetPropertyName(shader, 0) == ShaderOptimizer.ShaderOptimizerEnabled;
            }
            catch {}
            
            if (usingOptimizer && !shader.name.StartsWith("Hidden/")) shouldStrip = true; // make your shader pink if you dont lock it :>

            for (int i = data.Count - 1; i >= 0; --i)
            {
                if (shouldStrip) data.RemoveAt(i);
            }
        }
    }

    
    public enum LightMode
    {
        Always=1,
        ForwardBase=2,
        ForwardAdd=4,
        Deferred=8,
        ShadowCaster=16,
        MotionVectors=32,
        PrepassBase=64,
        PrepassFinal=128,
        Vertex=256,
        VertexLMRGBM=512,
        VertexLM=1024
    }

    // Static methods to generate new shader files with in-place constants based on a material's properties
    // and link that new shader to the material automatically
    public class ShaderOptimizer
    {
        // For some reason, 'if' statements with replaced constant (literal) conditions cause some compilation error
        // So until that is figured out, branches will be removed by default
        // Set to false if you want to keep UNITY_BRANCH and [branch]
        public static bool RemoveUnityBranches = true;


        // LOD Crossfade Dithing doesn't have multi_compile keyword correctly toggled at build time (its always included) so
        // this hard-coded material property will uncomment //#pragma multi_compile _ LOD_FADE_CROSSFADE in optimized .shader files
        public static readonly string LODCrossFadePropertyName = "_LodCrossFade";


        

        // Material property suffix that controls whether the property of the same name gets baked into the optimized shader
        // e.g. if _Color exists and _ColorAnimated = 1, _Color will not be baked in
        public static readonly string AnimatedPropertySuffix = "Animated";

        public static readonly string OriginalShaderTag = "OriginalShaderTag";
        public static readonly string ShaderOptimizerEnabled = "wAg6H2wQzc7UbxaL";


        // Material properties are put into each CGPROGRAM as preprocessor defines when the optimizer is run.
        // This is mainly targeted at culling interpolators and lines that rely on those interpolators.
        // (The compiler is not smart enough to cull VS output that isn't used anywhere in the PS)
        // Additionally, simply enabling the optimizer can define a keyword, whose name is stored here.
        // This keyword is added to the beginning of all passes, right after CGPROGRAM
        public static readonly string OptimizerEnabledKeyword = "OPTIMIZER_ENABLED";


        private static bool ReplaceAnimatedParameters = false;

        public static void LockMaterial(Material mat, bool applyLater, Material sharedMaterial, string unityKeywords)
        {

            mat.SetFloat(ShaderOptimizerEnabled, 1);
            MaterialProperty[] props = MaterialEditor.GetMaterialProperties(new UnityEngine.Object[] { mat });
            if (!ShaderOptimizer.Lock(mat, props, applyLater, sharedMaterial, unityKeywords)) // Error locking shader, revert property
                mat.SetFloat(ShaderOptimizerEnabled, 0);
        }

        [MenuItem("Tools/Shader Optimizer/Unlock Materials In Scene")]
        public static void UnlockAllMaterials()
        {
            #if BAKERY_INCLUDED
                ftLightmapsStorage storage = ftRenderLightmap.FindRenderSettingsStorage();
                if(storage.renderSettingsRenderDirMode == 3 || storage.renderSettingsRenderDirMode == 4) RevertHandleBakeryPropertyBlocks();
            #endif

            Material[] mats = GetMaterialsUsingOptimizer(true);

            foreach (Material m in mats)
            {
                Unlock(m);
                m.SetFloat(ShaderOptimizerEnabled, 0);
            }
        }

        public static readonly string[] PropertiesToSkip = new string[]
        {
            ShaderOptimizerEnabled,
            "_BlendOp",
            "_BlendOpAlpha",
            "_SrcBlend",
            "_DstBlend",
            "_ZWrite",
            "_ZTest",
            "_Cull",
            "_MainTex"
        };

        public static readonly string[] TexelSizeCheck = new string[]
        {
            "_RNM0",
            "_RNM1",
            "_RNM2"
        };
        
        [MenuItem("Tools/Shader Optimizer/Lock Materials In Scene")]
        public static void LockAllMaterials()
        {
            #if BAKERY_INCLUDED
                ftLightmapsStorage storage = ftRenderLightmap.FindRenderSettingsStorage();
                if(storage.renderSettingsRenderDirMode == 3 || storage.renderSettingsRenderDirMode == 4) HandleBakeryPropertyBlocks();
            #endif
            Material[] mats = GetMaterialsUsingOptimizer(false);
            float progress = mats.Length;

            if(progress == 0) return;
            
            AssetDatabase.StartAssetEditing();
            Dictionary<string, Material> MaterialsPropertyHash = new Dictionary<string, Material>();

            string unityKeywords = UnityGlobalKeywords();


            for (int i=0; i<progress; i++)
            {
                EditorUtility.DisplayCancelableProgressBar("Generating Shaders", mats[i].name, i/progress);

                int propCount = ShaderUtil.GetPropertyCount(mats[i].shader);

                StringBuilder materialPropertyValues = new StringBuilder(mats[i].shader.name);

                for(int l=0; l<propCount; l++)
                {
                    string propName = ShaderUtil.GetPropertyName(mats[i].shader, l);
                    
                    if(PropertiesToSkip.Contains(propName))
                    {
                        materialPropertyValues.Append(propName);
                        continue;
                    }

                    bool isAnimated = mats[i].GetTag(propName, false) != "";

                    if(isAnimated)
                    {
                        materialPropertyValues.Append(propName + "_Animated");
                        continue;
                    }
                    
                    switch(ShaderUtil.GetPropertyType(mats[i].shader, l))
                    {
                        case(ShaderUtil.ShaderPropertyType.Float):
                            materialPropertyValues.Append(mats[i].GetFloat(propName).ToString());
                            break;

                        case(ShaderUtil.ShaderPropertyType.TexEnv):
                            Texture t = mats[i].GetTexture(propName);
                            Vector4 texelSize = new Vector4(1.0f, 1.0f, 1.0f, 1.0f);
                            
                            materialPropertyValues.Append(t != null ? "true" : "false");
                            materialPropertyValues.Append(mats[i].GetTextureOffset(propName).ToString());
                            materialPropertyValues.Append(mats[i].GetTextureScale(propName).ToString());

                            if (t != null && TexelSizeCheck.Contains(propName)) texelSize = new Vector4(1.0f / t.width, 1.0f / t.height, t.width, t.height);
                            materialPropertyValues.Append(texelSize.ToString());
                            break;

                        case(ShaderUtil.ShaderPropertyType.Color):
                            materialPropertyValues.Append(mats[i].GetColor(propName).ToString());
                            break;

                        case(ShaderUtil.ShaderPropertyType.Range):
                            materialPropertyValues.Append(mats[i].GetFloat(propName).ToString());
                            break;

                        case(ShaderUtil.ShaderPropertyType.Vector):
                            materialPropertyValues.Append(mats[i].GetVector(propName).ToString());
                            break;
                    }
                }

                Material sharedMaterial = null;
                string matPropHash = ComputeMD5(materialPropertyValues.ToString());
                if (MaterialsPropertyHash.ContainsKey(matPropHash))
                {
                    MaterialsPropertyHash.TryGetValue(matPropHash, out sharedMaterial);
                }
                else
                {
                    MaterialsPropertyHash.Add(matPropHash, mats[i]);
                }
                
                LockMaterial(mats[i], true, sharedMaterial, unityKeywords);
            }
            
            EditorUtility.ClearProgressBar();
            AssetDatabase.StopAssetEditing();
            AssetDatabase.Refresh();

            for (int i=0; i<progress; i++)
            {
                EditorUtility.DisplayCancelableProgressBar("Replacing Shaders", mats[i].name, i/progress);
                LockApplyShader(mats[i]);
            }
            EditorUtility.ClearProgressBar();
            
        }


        public static Material[] GetAllMaterialsWithShader(string shaderName)
        {
            List<Material> materials = new List<Material>();
            Scene scene = SceneManager.GetActiveScene();
            string[] materialPaths = AssetDatabase.GetDependencies(scene.path).Where(x => x.EndsWith(".mat")).ToArray();
            var renderers = UnityEngine.Object.FindObjectsOfType<Renderer>();
            
            for (int i = 0; i < materialPaths.Length; i++)
            {
                Material material = AssetDatabase.LoadAssetAtPath<Material>(materialPaths[i]);
                if(material.shader.name == shaderName) materials.Add(material);
            }

            if(renderers != null) foreach (var rend in renderers)
            {
                if(rend != null) foreach (var mat in rend.sharedMaterials)
                {
                    if(mat != null) if(mat.shader.name == shaderName)
                    {
                        materials.Add(mat);
                    }
                }
            }

            return materials.Distinct().ToArray();
        }

        public static Material[] GetMaterialsUsingOptimizer(bool isLocked)
        {
            List<Material> materials = new List<Material>();
            List<Material> foundMaterials = new List<Material>();
            Scene scene = SceneManager.GetActiveScene();

            string[] materialPaths = AssetDatabase.GetDependencies(scene.path).Where(x => x.EndsWith(".mat")).ToArray();
            var renderers = UnityEngine.Object.FindObjectsOfType<Renderer>();

            for (int i = 0; i < materialPaths.Length; i++)
            {
                Material mat = AssetDatabase.LoadAssetAtPath<Material>(materialPaths[i]);
                foundMaterials.Add(mat);
            }

            if(renderers != null) foreach (var rend in renderers)
            {
                if(rend != null) foreach (var mat in rend.sharedMaterials)
                {
                    if(mat != null)
                    {
                        foundMaterials.Add(mat);
                    }
                }
            }

            foreach (Material mat in foundMaterials)
            {

                if(mat.shader.name != "Hidden/InternalErrorShader")
                {
                    bool usingOptimizer = false;
                    try 
                    {
                        usingOptimizer = ShaderUtil.GetPropertyName(mat.shader, 0) == ShaderOptimizerEnabled;
                    }
                    catch {}

                    if(!materials.Contains(mat) && usingOptimizer)
                        if(mat.GetFloat(ShaderOptimizerEnabled) == (isLocked ? 1 : 0))
                            materials.Add(mat);
                }
                else
                {
                    if(!materials.Contains(mat) && mat.GetTag(OriginalShaderTag, false) != String.Empty)
                        if(isLocked)
                            materials.Add(mat);
                }
            }
            return materials.Distinct().ToArray();
        }

        /**
        * MIT License
        * 
        * Copyright (c) 2019 Merlin
        * 
        * Permission is hereby granted, free of charge, to any person obtaining a copy
        * of this software and associated documentation files (the "Software"), to deal
        * in the Software without restriction, including without limitation the rights
        * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        * copies of the Software, and to permit persons to whom the Software is
        * furnished to do so, subject to the following conditions:
        * 
        * The above copyright notice and this permission notice shall be included in all
        * copies or substantial portions of the Software.
        * 
        * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        * SOFTWARE.
        */
        #if BAKERY_INCLUDED
        [MenuItem("Tools/Shader Optimizer/Generate Bakery Materials")]
        #endif
        public static void HandleBakeryPropertyBlocks()
        {
            const string newMaterialPath = "Assets/GeneratedMaterials/";
            if (!Directory.Exists(newMaterialPath)) Directory.CreateDirectory(newMaterialPath);

            MeshRenderer[] mr = UnityEngine.Object.FindObjectsOfType<MeshRenderer>();
            Dictionary<string, Material> generatedMaterialList = new Dictionary<string, Material>();
            

            for (int i = 0; i < mr.Length; i++)
            {
                EditorUtility.DisplayCancelableProgressBar("Generating Materials", mr[i].name, (float)i/mr.Length);
                MaterialPropertyBlock propertyBlock = new MaterialPropertyBlock();
                mr[i].GetPropertyBlock(propertyBlock);
                Texture RNM0 = propertyBlock.GetTexture("_RNM0");
                Texture RNM1 = propertyBlock.GetTexture("_RNM1");
                Texture RNM2 = propertyBlock.GetTexture("_RNM2");
                int propertyLightmapMode = (int)propertyBlock.GetFloat("bakeryLightmapMode");

                if(RNM0 && RNM1 && RNM2 && propertyLightmapMode != 0)
                {
                    Material[] newSharedMaterials = new Material[mr[i].sharedMaterials.Length];

                    for (int j = 0; j < mr[i].sharedMaterials.Length; j++)
                    {
                        Material material = mr[i].sharedMaterials[j];

                        if(material != null)
                        {
                            bool usingOptimizer = false;
                            try 
                            {
                                usingOptimizer = ShaderUtil.GetPropertyName(material.shader, 0) == ShaderOptimizerEnabled;
                            }
                            catch {}
                            
                            if  (usingOptimizer && material.GetTag("OriginalMaterialPath", false) == String.Empty && (material.shaderKeywords.Contains("BAKERY_SH") || material.shaderKeywords.Contains("BAKERY_RNM")))
                            {
                                string materialPath = AssetDatabase.GetAssetPath(material);
                                string textureName = AssetDatabase.GetAssetPath(RNM0) + "_" + AssetDatabase.GetAssetPath(RNM1) + "_" + AssetDatabase.GetAssetPath(RNM2);
                                string matTexHash = ComputeMD5(materialPath + textureName);


                                Material newMaterial = null;

                                generatedMaterialList.TryGetValue(matTexHash, out newMaterial);
                                if (newMaterial == null)
                                {
                                    newMaterial = new Material(material);
                                    newMaterial.name = matTexHash;
                                    newMaterial.SetTexture("_RNM0", RNM0);
                                    newMaterial.SetTexture("_RNM1", RNM1);
                                    newMaterial.SetTexture("_RNM2", RNM2);
                                    newMaterial.SetInt("bakeryLightmapMode", propertyLightmapMode);
                                    newMaterial.SetOverrideTag("OriginalMaterialPath", AssetDatabase.AssetPathToGUID(materialPath));
                                    generatedMaterialList.Add(matTexHash, newMaterial);

                                    
                                    try
                                    {
                                        AssetDatabase.CreateAsset(newMaterial, newMaterialPath + matTexHash + ".mat");
                                    }
                                    catch(Exception e)
                                    {
                                        Debug.LogError($"Unable to create new material {newMaterial.name} for {mr} {e}");
                                    }

                                    //Debug.Log($"Created new material for {mr} named {newMaterial.name}");

                                }

                                newSharedMaterials[j] = newMaterial;

                            }
                            else if (material != null)
                            {
                                newSharedMaterials[j] = material;
                            }
                        }
                    }

                    mr[i].sharedMaterials = newSharedMaterials;
                }
            }
            EditorUtility.ClearProgressBar();
            AssetDatabase.Refresh();
        }
        /**
        * MIT License
        * 
        * Copyright (c) 2019 Merlin
        * 
        * Permission is hereby granted, free of charge, to any person obtaining a copy
        * of this software and associated documentation files (the "Software"), to deal
        * in the Software without restriction, including without limitation the rights
        * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        * copies of the Software, and to permit persons to whom the Software is
        * furnished to do so, subject to the following conditions:
        * 
        * The above copyright notice and this permission notice shall be included in all
        * copies or substantial portions of the Software.
        * 
        * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
        * SOFTWARE.
        */
        #if BAKERY_INCLUDED
        [MenuItem("Tools/Shader Optimizer/Only Set Bakery Materials")]
        #endif
        public static void HandleBakeryPropertyBlocksSet()
        {
            MeshRenderer[] mr = UnityEngine.Object.FindObjectsOfType<MeshRenderer>();

            for (int i = 0; i < mr.Length; i++)
            {
                EditorUtility.DisplayCancelableProgressBar("Setting Bakery Stuff on Materials", mr[i].name, (float)i/mr.Length);
                MaterialPropertyBlock propertyBlock = new MaterialPropertyBlock();
                mr[i].GetPropertyBlock(propertyBlock);
                Texture RNM0 = propertyBlock.GetTexture("_RNM0");
                Texture RNM1 = propertyBlock.GetTexture("_RNM1");
                Texture RNM2 = propertyBlock.GetTexture("_RNM2");
                int propertyLightmapMode = (int)propertyBlock.GetFloat("bakeryLightmapMode");

                if(RNM0 && RNM1 && RNM2 && propertyLightmapMode != 0)
                {
                    for (int j = 0; j < mr[i].sharedMaterials.Length; j++)
                    {
                        Material material = mr[i].sharedMaterials[j];

                        if(material != null)
                        {
                            bool usingOptimizer = false;
                            try 
                            {
                                usingOptimizer = ShaderUtil.GetPropertyName(material.shader, 0) == ShaderOptimizerEnabled;
                            }
                            catch {}
                            
                            if  (usingOptimizer && material.GetTag("OriginalMaterialPath", false) == String.Empty && (material.shaderKeywords.Contains("BAKERY_SH") || material.shaderKeywords.Contains("BAKERY_RNM")))
                            {
                                material.SetTexture("_RNM0", RNM0);
                                material.SetTexture("_RNM1", RNM1);
                                material.SetTexture("_RNM2", RNM2);
                                material.SetInt("bakeryLightmapMode", propertyLightmapMode);
                            }
                        }
                    }
                }
            }
            EditorUtility.ClearProgressBar();
            AssetDatabase.Refresh();
        }
        #if BAKERY_INCLUDED
        [MenuItem("Tools/Shader Optimizer/Revert Bakery Materials")]
        #endif
        public static void RevertHandleBakeryPropertyBlocks()
        {
            var renderers = UnityEngine.Object.FindObjectsOfType<MeshRenderer>();

            if(renderers != null) foreach (var rend in renderers)
            {
                Material[] oldMaterials = new Material[rend.sharedMaterials.Length];

                if(rend != null)
                {
                    for (int i = 0; i < rend.sharedMaterials.Length; i++)
                    {

                        if( rend.sharedMaterials[i] != null)
                        {
                            string originalMatPath = rend.sharedMaterials[i].GetTag("OriginalMaterialPath", false, String.Empty);
                            if(originalMatPath != "")
                            {
                                try
                                {
                                    Material oldMat = (Material)AssetDatabase.LoadAssetAtPath(AssetDatabase.GUIDToAssetPath(originalMatPath), typeof(Material));
                                    oldMaterials[i] = oldMat;
                                }
                                catch
                                {
                                    Debug.LogError($"Unable to find original material  at {originalMatPath} for {rend.sharedMaterials[i]} for {rend}");
                                    oldMaterials[i] = rend.sharedMaterials[i];
                                }
                            }
                            else
                            {
                                oldMaterials[i] = rend.sharedMaterials[i];
                            }
                        }
                    }
                    rend.sharedMaterials = oldMaterials;
                }
            }
        }

        // https://forum.unity.com/threads/hash-function-for-game.452779/
        private static string ComputeMD5(string str)
        {
            System.Text.ASCIIEncoding encoding = new System.Text.ASCIIEncoding();
            byte[] bytes = encoding.GetBytes(str);
            var sha = new System.Security.Cryptography.MD5CryptoServiceProvider();
            return BitConverter.ToString(sha.ComputeHash(bytes)).Replace("-", "").ToLower();
        }

        // Would be better to dynamically parse the "C:\Program Files\UnityXXXX\Editor\Data\CGIncludes\" folder
        // to get version specific includes but eh
        public static readonly string[] DefaultUnityShaderIncludes = new string[]
        {
            "UnityUI.cginc",
            "AutoLight.cginc",
            "GLSLSupport.glslinc",
            "HLSLSupport.cginc",
            "Lighting.cginc",
            "SpeedTreeBillboardCommon.cginc",
            "SpeedTreeCommon.cginc",
            "SpeedTreeVertex.cginc",
            "SpeedTreeWind.cginc",
            "TerrainEngine.cginc",
            "TerrainSplatmapCommon.cginc",
            "Tessellation.cginc",
            "UnityBuiltin2xTreeLibrary.cginc",
            "UnityBuiltin3xTreeLibrary.cginc",
            "UnityCG.cginc",
            "UnityCG.glslinc",
            "UnityCustomRenderTexture.cginc",
            "UnityDeferredLibrary.cginc",
            "UnityDeprecated.cginc",
            "UnityGBuffer.cginc",
            "UnityGlobalIllumination.cginc",
            "UnityImageBasedLighting.cginc",
            "UnityInstancing.cginc",
            "UnityLightingCommon.cginc",
            "UnityMetaPass.cginc",
            "UnityPBSLighting.cginc",
            "UnityShaderUtilities.cginc",
            "UnityShaderVariables.cginc",
            "UnityShadowLibrary.cginc",
            "UnitySprites.cginc",
            "UnityStandardBRDF.cginc",
            "UnityStandardConfig.cginc",
            "UnityStandardCore.cginc",
            "UnityStandardCoreForward.cginc",
            "UnityStandardCoreForwardSimple.cginc",
            "UnityStandardInput.cginc",
            "UnityStandardMeta.cginc",
            "UnityStandardParticleInstancing.cginc",
            "UnityStandardParticles.cginc",
            "UnityStandardParticleShadow.cginc",
            "UnityStandardShadow.cginc",
            "UnityStandardUtils.cginc"
        };

        public static readonly char[] ValidSeparators = new char[] {' ','\t','\r','\n',';',',','.','(',')','[',']','{','}','>','<','=','!','&','|','^','+','-','*','/','#','?' };

        public static readonly string[] ValidPropertyDataTypes = new string[]
        {
            "float",
            "float2",
            "float3",
            "float4",
            "half",
            "half2",
            "half3",
            "half4",
            "fixed",
            "fixed2",
            "fixed3",
            "fixed4",
            "int",
            "uint",
            "double"
        };

        public enum PropertyType
        {
            Vector,
            Float
        }

        public class PropertyData
        {
            public PropertyType type;
            public string name;
            public Vector4 value;
        }

        public class Macro
        {
            public string name;
            public string[] args;
            public string contents;
        }

        public class ParsedShaderFile
        {
            public string filePath;
            public string[] lines;
        }

        public class TextureProperty
        {
            public string name;
            public Texture texture;
            public int uv;
            public Vector2 scale;
            public Vector2 offset;
        }

        public static string UnityGlobalKeywords()
        {
            StringBuilder skipVariants = new StringBuilder("#pragma skip_variants ");

                var lights = UnityEngine.Object.FindObjectsOfType<Light>();
                int pixelLightCount = 0;
                bool hasVertexLights = false;
                bool hasCookie = false;
                bool hasShadows = false;
                bool hasSoftShadows = false;
                bool hasSpotLight = false;
                bool hasPointLight = false;

                for (int j = 0; j < lights.Length; j++)
                {
                    if(lights[j].lightmapBakeType == LightmapBakeType.Baked) continue;

                    if((lights[j].renderMode == LightRenderMode.Auto || lights[j].renderMode == LightRenderMode.ForcePixel)) pixelLightCount += 1;
                    if(lights[j].renderMode == LightRenderMode.ForceVertex) hasVertexLights = true;
                    if(lights[j].cookie != null) hasCookie = true;
                    if(lights[j].shadows != LightShadows.None) hasShadows = true;
                    if(lights[j].shadows == LightShadows.Soft) hasSoftShadows = true;
                    if(lights[j].type == LightType.Spot) hasSpotLight = true;
                    if(lights[j].type == LightType.Point) hasPointLight = true;
                } 

                if(pixelLightCount > 4) hasVertexLights = true;

                if(!hasPointLight) skipVariants.Append("POINT ");
                if(!hasVertexLights) skipVariants.Append("VERTEXLIGHT_ON ");
                if(!hasCookie) skipVariants.Append("DIRECTIONAL_COOKIE POINT_COOKIE ");
                if(!hasShadows) skipVariants.Append("SHADOWS_SCREEN ");
                if(!hasSoftShadows) skipVariants.Append("SHADOWS_SOFT ");
                if(!hasSpotLight) skipVariants.Append("SPOT ");

                if(!Lightmapping.realtimeGI) skipVariants.Append("DYNAMICLIGHTMAP_ON ");
                if(!RenderSettings.fog) skipVariants.Append("FOG_LINEAR FOG_EXP FOG_EXP2 ");

                return skipVariants.ToString();
        }

        public static bool Lock(Material material, MaterialProperty[] props)
        {
            Lock(material, props, false, null, null);
            return true;
        }

        public static bool Lock(Material material, MaterialProperty[] props, bool applyShaderLater, Material sharedMaterial, string unityKeywords)
        {
 
            Shader shader = material.shader;
            string shaderFilePath = AssetDatabase.GetAssetPath(shader);
            string smallguid = AssetDatabase.AssetPathToGUID(AssetDatabase.GetAssetPath(material));
            string newShaderName = "Hidden/" + shader.name + "/" + smallguid;
            string newShaderDirectory = "Assets/OptimizedShaders/" + smallguid + "/";
            ApplyLater applyLater = new ApplyLater();
            
            
            if(sharedMaterial != null)
            {
                applyLater.material = material;
                applyLater.shader = sharedMaterial.shader;
                applyLater.smallguid = AssetDatabase.AssetPathToGUID(AssetDatabase.GetAssetPath(sharedMaterial));
                applyLater.newShaderName = "Hidden/" + shader.name + "/" + applyLater.smallguid;
                applyStructsLater.Add(material, applyLater);
                return true;

            }


            // Get collection of all properties to replace
            // Simultaneously build a string of #defines for each CGPROGRAM
            StringBuilder definesSB = new StringBuilder();
            // Append convention OPTIMIZER_ENABLED keyword
            definesSB.Append(Environment.NewLine);
            definesSB.Append("#define ");
            definesSB.Append(OptimizerEnabledKeyword);
            definesSB.Append(Environment.NewLine);
            // Append all keywords active on the material
            foreach (string keyword in material.shaderKeywords)
            {
                if (keyword == "") continue; // idk why but null keywords exist if _ keyword is used and not removed by the editor at some point
                definesSB.Append("#define ");
                definesSB.Append(keyword);
                definesSB.Append(Environment.NewLine);
            }

            List<PropertyData> constantProps = new List<PropertyData>();
            List<string> animatedProps = new List<string>();

            MaterialProperty bakeUnityKeywords = Array.Find(props, x => x.name == "_BakeUnityKeywords");

            if(bakeUnityKeywords.floatValue == 1)
            {
                definesSB.Append(String.IsNullOrEmpty(unityKeywords) ? UnityGlobalKeywords(): unityKeywords);
                definesSB.Append(Environment.NewLine);
            }

            foreach (MaterialProperty prop in props)
            {
                if (prop == null) continue;

                // Every property gets turned into a preprocessor variable
                switch(prop.type)
                {
                    case MaterialProperty.PropType.Float:
                    case MaterialProperty.PropType.Range:
                        definesSB.Append("#define PROP");
                        definesSB.Append(prop.name.ToUpper());
                        definesSB.Append(' ');
                        definesSB.Append(prop.floatValue.ToString(CultureInfo.InvariantCulture));
                        definesSB.Append(Environment.NewLine);
                        break;
                    case MaterialProperty.PropType.Texture:
                        if (prop.textureValue != null)
                        {
                            definesSB.Append("#define PROP");
                            definesSB.Append(prop.name.ToUpper());
                            definesSB.Append(Environment.NewLine);
                        }
                        break;
                }

                if (
                  prop.name.EndsWith(AnimatedPropertySuffix) ||
                 (material.GetTag(prop.name.ToString() + AnimatedPropertySuffix, false) == String.Empty ? false : true))
                    continue;


                // Check for the convention 'Animated' Property to be true otherwise assume all properties are constant
                // nlogn trash
                MaterialProperty animatedProp = Array.Find(props, x => x.name == prop.name + AnimatedPropertySuffix);
                if (animatedProp != null && animatedProp.floatValue == 1)
                {
                    animatedProps.Add(prop.name);
                    continue;
                }

                PropertyData propData;
                switch(prop.type)
                {
                    case MaterialProperty.PropType.Color:
                        propData = new PropertyData();
                        propData.type = PropertyType.Vector;
                        propData.name = prop.name;
                        if ((prop.flags & MaterialProperty.PropFlags.HDR) != 0)
                        {
                            if ((prop.flags & MaterialProperty.PropFlags.Gamma) != 0)
                                propData.value = prop.colorValue.linear;
                            else propData.value = prop.colorValue;
                        }
                        else if ((prop.flags & MaterialProperty.PropFlags.Gamma) != 0)
                            propData.value = prop.colorValue;
                        else propData.value = prop.colorValue.linear;
                        constantProps.Add(propData);
                        break;
                    case MaterialProperty.PropType.Vector:
                        propData = new PropertyData();
                        propData.type = PropertyType.Vector;
                        propData.name = prop.name;
                        propData.value = prop.vectorValue;
                        constantProps.Add(propData);
                        break;
                    case MaterialProperty.PropType.Float:
                    case MaterialProperty.PropType.Range:
                        propData = new PropertyData();
                        propData.type = PropertyType.Float;
                        propData.name = prop.name;
                        propData.value = new Vector4(prop.floatValue, 0, 0, 0);
                        constantProps.Add(propData);
                        break;
                    case MaterialProperty.PropType.Texture:
                        animatedProp = Array.Find(props, x => x.name == prop.name + "_ST" + AnimatedPropertySuffix);
                        if (!(animatedProp != null && animatedProp.floatValue == 1))
                        {
                            PropertyData ST = new PropertyData();
                            ST.type = PropertyType.Vector;
                            ST.name = prop.name + "_ST";
                            Vector2 offset = material.GetTextureOffset(prop.name);
                            Vector2 scale = material.GetTextureScale(prop.name);
                            ST.value = new Vector4(scale.x, scale.y, offset.x, offset.y);
                            constantProps.Add(ST);
                        }
                        animatedProp = Array.Find(props, x => x.name == prop.name + "_TexelSize" + AnimatedPropertySuffix);
                        if (!(animatedProp != null && animatedProp.floatValue == 1))
                        {
                            PropertyData TexelSize = new PropertyData();
                            TexelSize.type = PropertyType.Vector;
                            TexelSize.name = prop.name + "_TexelSize";
                            Texture t = prop.textureValue;
                            if (t != null)
                                TexelSize.value = new Vector4(1.0f / t.width, 1.0f / t.height, t.width, t.height);
                            else TexelSize.value = new Vector4(1.0f, 1.0f, 1.0f, 1.0f);
                            constantProps.Add(TexelSize);
                        }
                        break;
                }
            }
            string optimizerDefines = definesSB.ToString();
                
            // Parse shader and cginc files, also gets preprocessor macros
            List<ParsedShaderFile> shaderFiles = new List<ParsedShaderFile>();
            List<Macro> macros = new List<Macro>();
            if (!ParseShaderFilesRecursive(shaderFiles, newShaderDirectory, shaderFilePath, macros, material))
                return false;
            

            // Loop back through and do macros, props, and all other things line by line as to save string ops
            // Will still be a massive n2 operation from each line * each property
            foreach (ParsedShaderFile psf in shaderFiles)
            {
                // Shader file specific stuff
                if (psf.filePath.EndsWith(".shader"))
                {
                    for (int i=0; i<psf.lines.Length;i++)
                    {
                        string trimmedLine = psf.lines[i].TrimStart();
                        if (trimmedLine.StartsWith("Shader"))
                        {
                            string originalSgaderName = psf.lines[i].Split('\"')[1];
                            psf.lines[i] = psf.lines[i].Replace(originalSgaderName, newShaderName);
                        }
                        else if (trimmedLine.StartsWith("#pragma multi_compile _ LOD_FADE_CROSSFADE"))
                        {
                            MaterialProperty crossfadeProp = Array.Find(props, x => x.name == LODCrossFadePropertyName);
                            if (crossfadeProp != null && crossfadeProp.floatValue == 0)
                                psf.lines[i] = psf.lines[i].Replace("#pragma", "//#pragma");
                        }
           
                        else if (trimmedLine.StartsWith("CGINCLUDE"))
                        {
                            for (int j=i+1; j<psf.lines.Length;j++)
                                if (psf.lines[j].TrimStart().StartsWith("ENDCG"))
                                {
                                    ReplaceShaderValues(material, psf.lines, i+1, j, constantProps, animatedProps, macros);
                                    break;
                                }
                        }
                        else if (trimmedLine.StartsWith("SubShader"))
                        {
                            psf.lines[i-1] += "CGINCLUDE";
                            psf.lines[i-1] += optimizerDefines;
                            psf.lines[i-1] += "ENDCG";
                        }
                        else if (trimmedLine.StartsWith("CGPROGRAM"))
                        {
                            for (int j=i+1; j<psf.lines.Length;j++)
                                if (psf.lines[j].TrimStart().StartsWith("ENDCG"))
                                {
                                    ReplaceShaderValues(material, psf.lines, i+1, j, constantProps, animatedProps, macros);
                                    break;
                                }
                        }

                        else if (ReplaceAnimatedParameters)
                        {
                            // Check to see if line contains an animated property name with valid left/right characters
                            // then replace the parameter name with prefixtag + parameter name
                            string animatedPropName = animatedProps.Find(x => trimmedLine.Contains(x));
                            if (animatedPropName != null)
                            {
                                int parameterIndex = trimmedLine.IndexOf(animatedPropName);
                                char charLeft = trimmedLine[parameterIndex-1];
                                char charRight = trimmedLine[parameterIndex + animatedPropName.Length];
                                if (Array.Exists(ValidSeparators, x => x == charLeft) && Array.Exists(ValidSeparators, x => x == charRight))
                                    psf.lines[i] = psf.lines[i].Replace(animatedPropName, animatedPropName + material.GetTag("AnimatedParametersSuffix", false, String.Empty));
                            }
                        }
                    }
                }
                else // CGINC file
                    ReplaceShaderValues(material, psf.lines, 0, psf.lines.Length, constantProps, animatedProps, macros);

                // Recombine file lines into a single string
                int totalLen = psf.lines.Length*2; // extra space for newline chars
                foreach (string line in psf.lines)
                    totalLen += line.Length;
                StringBuilder sb = new StringBuilder(totalLen);
                // This appendLine function is incompatible with the '\n's that are being added elsewhere
                foreach (string line in psf.lines)
                    sb.AppendLine(line);
                string output = sb.ToString();

                // Write output to file
                string newDirectory = psf.filePath.Split('/').Last();

                new FileInfo(newShaderDirectory + newDirectory).Directory.Create();
                try
                {
                    StreamWriter sw = new StreamWriter(newShaderDirectory + newDirectory);
                    sw.Write(output);
                    sw.Close();
                }
                catch (IOException e)
                {
                    Debug.LogError("[Kaj Shader Optimizer] Processed shader file " + newShaderDirectory + newDirectory + " could not be written.  " + e.ToString());
                    return false;
                }
            }
            

            applyLater.material = material;
            applyLater.shader = shader;
            applyLater.smallguid = smallguid;
            applyLater.newShaderName = newShaderName;

            if (applyShaderLater)
            {
                applyStructsLater.Add(material, applyLater);
                return true;
            }

            AssetDatabase.Refresh();

            return ReplaceShader(applyLater);
        }

        private static Dictionary<Material, ApplyLater> applyStructsLater = new Dictionary<Material, ApplyLater>();

        private struct ApplyLater
        {
            public Material material;
            public Shader shader;
            public string smallguid;
            public string newShaderName;
        }
        
        private static bool LockApplyShader(Material material)
        {
            if (applyStructsLater.ContainsKey(material) == false) return false;
            ApplyLater applyStruct = applyStructsLater[material];
            applyStructsLater.Remove(material);
            return ReplaceShader(applyStruct);
        }


        private static bool ReplaceShader(ApplyLater applyLater)
        {

            // Write original shader to override tag
            applyLater.material.SetOverrideTag(OriginalShaderTag, applyLater.shader.name);
            // Write the new shader folder name in an override tag so it will be deleted 
            applyLater.material.SetOverrideTag("OptimizedShaderFolder", applyLater.smallguid);

            // For some reason when shaders are swapped on a material the RenderType override tag gets completely deleted and render queue set back to -1
            // So these are saved as temp values and reassigned after switching shaders
            string renderType = applyLater.material.GetTag("RenderType", false, String.Empty);
            int renderQueue = applyLater.material.renderQueue;

            // Actually switch the shader
            Shader newShader = Shader.Find(applyLater.newShaderName);
            
            if (newShader == null)
            {
               // LockMaterial(applyLater.material, false, null);
                Debug.LogError("[Kaj Shader Optimizer] Generated shader " + applyLater.newShaderName + " for " + applyLater.material +" could not be found ");
                return false;
            }
            applyLater.material.shader = newShader;
            applyLater.material.SetOverrideTag("RenderType", renderType);
            applyLater.material.renderQueue = renderQueue;

            // Remove ALL keywords
            foreach (string keyword in applyLater.material.shaderKeywords)
            applyLater.material.DisableKeyword(keyword);

            return true;
        }


        // Preprocess each file for macros and includes
        // Save each file as string[], parse each macro with //KSOEvaluateMacro
        // Only editing done is replacing #include "X" filepaths where necessary
        // most of these args could be private static members of the class
        private static bool ParseShaderFilesRecursive(List<ParsedShaderFile> filesParsed, string newTopLevelDirectory, string filePath, List<Macro> macros, Material mat)
        {
            // Infinite recursion check
            if (filesParsed.Exists(x => x.filePath == filePath)) return true;

            ParsedShaderFile psf = new ParsedShaderFile();
            psf.filePath = filePath;
            filesParsed.Add(psf);

            // Read file
            string fileContents = null;
            try
            {
                StreamReader sr = new StreamReader(filePath);
                fileContents = sr.ReadToEnd();
                sr.Close();
            }
            catch (FileNotFoundException e)
            {
                Debug.LogError("[Kaj Shader Optimizer] Shader file " + filePath + " not found.  " + e.ToString());
                return false;
            }
            catch (IOException e)
            {
                Debug.LogError("[Kaj Shader Optimizer] Error reading shader file.  " + e.ToString());
                return false;
            }

            // Parse file line by line
            List<String> macrosList = new List<string>();
            string[] fileLines = Regex.Split(fileContents, "\r\n|\r|\n");
            for (int i=0; i<fileLines.Length; i++)
            {
                string lineParsed = fileLines[i].TrimStart();

                // Skip the cginc
                if (lineParsed.StartsWith("//#if") && mat != null)
                {
                    string[] materialProperties = Regex.Split(lineParsed.Replace("//#if", ""), ",");
                    try
                    {
                        if(!materialProperties.Any(x => mat.GetFloat(x) != 0))
                        {
                            i++;
                            fileLines[i] = fileLines[i].Insert(0, "//");
                            continue;
                        }
                    }
                    catch
                    {
                        Debug.LogError($"Property at line {i} not found on {mat}");
                    }
                }

                // Specifically requires no whitespace between # and include, as it should be
                else if (lineParsed.StartsWith("#include"))
                {
                    int firstQuotation = lineParsed.IndexOf('\"',0);
                    int lastQuotation = lineParsed.IndexOf('\"',firstQuotation+1);
                    string includeFilename = lineParsed.Substring(firstQuotation+1, lastQuotation-firstQuotation-1);

                    // Skip default includes
                    if (Array.Exists(DefaultUnityShaderIncludes, x => x.Equals(includeFilename, StringComparison.InvariantCultureIgnoreCase)))
                        continue;

                    // cginclude filepath is either absolute or relative
                    if (includeFilename.StartsWith("Assets/"))
                    {
                        if (!ParseShaderFilesRecursive(filesParsed, newTopLevelDirectory, includeFilename, macros, mat))
                            return false;
                        // Only absolute filepaths need to be renampped in-file
                        fileLines[i] = fileLines[i].Replace(includeFilename, newTopLevelDirectory + includeFilename);
                    }
                    else
                    {
                        string includeFullpath = GetFullPath(includeFilename, Path.GetDirectoryName(filePath));
                        if (!ParseShaderFilesRecursive(filesParsed, newTopLevelDirectory, includeFullpath, macros, mat))
                            return false;
                    }
                }
            }

            // Prepare the macros list into pattern matchable structs
            // Revise this later to not do so many string ops
            foreach (string macroString in macrosList)
            {
                string m = macroString;
                Macro macro = new Macro();
                m = m.TrimStart();
                if (m[0] != '#') continue;
                m = m.Remove(0, "#".Length).TrimStart();
                if (!m.StartsWith("define")) continue;
                m = m.Remove(0, "define".Length).TrimStart();
                int firstParenthesis = m.IndexOf('(');
                macro.name = m.Substring(0, firstParenthesis);
                m = m.Remove(0, firstParenthesis + "(".Length);
                int lastParenthesis = m.IndexOf(')');
                string allArgs = m.Substring(0, lastParenthesis).Replace(" ", "").Replace("\t", "");
                macro.args = allArgs.Split(',');
                m = m.Remove(0, lastParenthesis + ")".Length);
                macro.contents = m;
                macros.Add(macro);
            }

            // Save psf lines to list
            psf.lines = fileLines;
            return true;
        }

        // error CS1501: No overload for method 'Path.GetFullPath' takes 2 arguments
        // Thanks Unity
        // Could be made more efficent with stringbuilder
        public static string GetFullPath(string relativePath, string basePath)
        {
            while (relativePath.StartsWith("./"))
                relativePath = relativePath.Remove(0, "./".Length);
            while (relativePath.StartsWith("../"))
            {
                basePath = basePath.Remove(basePath.LastIndexOf(Path.DirectorySeparatorChar), basePath.Length - basePath.LastIndexOf(Path.DirectorySeparatorChar));
                relativePath = relativePath.Remove(0, "../".Length);
            }
            return basePath + '/' + relativePath;
        }
 
        // Replace properties! The meat of the shader optimization process
        // For each constantProp, pattern match and find each instance of the property that isn't a declaration
        // most of these args could be private static members of the class
        private static void ReplaceShaderValues(Material material, string[] lines, int startLine, int endLine, List<PropertyData> constants, List<string> animProps, List<Macro> macros)
        {

            for (int i=startLine;i<endLine;i++)
            {
                string lineTrimmed = lines[i].TrimStart();
                // Remove all shader_feature directives
                if (lineTrimmed.StartsWith("#pragma shader_feature") || lineTrimmed.StartsWith("#pragma shader_feature_local"))
                    lines[i] = "//" + lines[i];
                

                // then replace macros
                foreach (Macro macro in macros)
                {
                    // Expects only one instance of a macro per line!
                    int macroIndex;
                    if ((macroIndex = lines[i].IndexOf(macro.name + "(")) != -1)
                    {
                        // Macro exists on this line, make sure its not the definition
                        string lineParsed = lineTrimmed.Replace(" ", "").Replace("\t", "");
                        if (lineParsed.StartsWith("#define")) continue;

                        // parse args between first '(' and first ')'
                        int firstParenthesis = macroIndex + macro.name.Length;
                        int lastParenthesis = lines[i].IndexOf(')', macroIndex + macro.name.Length+1);
                        string allArgs = lines[i].Substring(firstParenthesis+1, lastParenthesis-firstParenthesis-1);
                        string[] args = allArgs.Split(',');

                        // Replace macro parts
                        string newContents = macro.contents;
                        for (int j=0; j<args.Length;j++)
                        {
                            args[j] = args[j].Trim();
                            int argIndex;
                            int lastIndex = 0;
                            // ERROR: This method of one-by-one argument replacement will infinitely loop
                            // if one of the arguments to paste into the macro definition has the same name
                            // as one of the macro arguments!
                            while ((argIndex = newContents.IndexOf(macro.args[j], lastIndex)) != -1)
                            {
                                lastIndex = argIndex+1;
                                char charLeft = ' ';
                                if (argIndex-1 >= 0)
                                    charLeft = newContents[argIndex-1];
                                char charRight = ' ';
                                if (argIndex+macro.args[j].Length < newContents.Length)
                                    charRight = newContents[argIndex+macro.args[j].Length];
                                if (Array.Exists(ValidSeparators, x => x == charLeft) && Array.Exists(ValidSeparators, x => x == charRight))
                                {
                                    // Replcae the arg!
                                    StringBuilder sbm = new StringBuilder(newContents.Length - macro.args[j].Length + args[j].Length);
                                    sbm.Append(newContents, 0, argIndex);
                                    sbm.Append(args[j]);
                                    sbm.Append(newContents, argIndex + macro.args[j].Length, newContents.Length - argIndex - macro.args[j].Length);
                                    newContents = sbm.ToString();
                                }
                            }
                        }

                        newContents = newContents.Replace("##", ""); // Remove token pasting separators
                        // Replace the line with the evaluated macro
                        StringBuilder sb = new StringBuilder(lines[i].Length + newContents.Length);
                        sb.Append(lines[i], 0, macroIndex);
                        sb.Append(newContents);
                        sb.Append(lines[i], lastParenthesis+1, lines[i].Length - lastParenthesis-1);
                        //lines[i] = sb.ToString();
                    }
                }
                
                // then replace properties
                foreach (PropertyData constant in constants)
                {
                    int constantIndex;
                    int lastIndex = 0;
                    bool declarationFound = false;
                    while ((constantIndex = lines[i].IndexOf(constant.name, lastIndex)) != -1)
                    {
                        lastIndex = constantIndex+1;
                        char charLeft = ' ';
                        if (constantIndex-1 >= 0)
                            charLeft = lines[i][constantIndex-1];
                        char charRight = ' ';
                        if (constantIndex + constant.name.Length < lines[i].Length)
                            charRight = lines[i][constantIndex + constant.name.Length];
                        // Skip invalid matches (probably a subname of another symbol)
                        if (!(Array.Exists(ValidSeparators, x => x == charLeft) && Array.Exists(ValidSeparators, x => x == charRight)))
                            continue;
                        
                        // Skip basic declarations of unity shader properties i.e. "uniform float4 _Color;"
                        if (!declarationFound)
                        {
                            string precedingText = lines[i].Substring(0, constantIndex-1).TrimEnd(); // whitespace removed string immediately to the left should be float or float4
                            string restOftheFile = lines[i].Substring(constantIndex + constant.name.Length).TrimStart(); // whitespace removed character immediately to the right should be ;
                            if (Array.Exists(ValidPropertyDataTypes, x => precedingText.EndsWith(x)) && restOftheFile.StartsWith(";"))
                            {
                                declarationFound = true;
                                continue;
                            }
                        }

                        // Replace with constant!
                        // This could technically be more efficient by being outside the IndexOf loop
                        // int parameters could be pasted here properly, but Unity's scripting API doesn't carry 
                        // over that information from shader parameters
                        StringBuilder sb = new StringBuilder(lines[i].Length * 2);
                        sb.Append(lines[i], 0, constantIndex);
                        switch (constant.type)
                        {
                            case PropertyType.Float:
                                sb.Append("float(" + constant.value.x.ToString(CultureInfo.InvariantCulture) + ")");
                                break;
                            case PropertyType.Vector:
                                sb.Append("float4("+constant.value.x.ToString(CultureInfo.InvariantCulture)+","
                                                   +constant.value.y.ToString(CultureInfo.InvariantCulture)+","
                                                   +constant.value.z.ToString(CultureInfo.InvariantCulture)+","
                                                   +constant.value.w.ToString(CultureInfo.InvariantCulture)+")");
                                break;
                        }
                        sb.Append(lines[i], constantIndex+constant.name.Length, lines[i].Length-constantIndex-constant.name.Length);
                        lines[i] = sb.ToString();

                        // Check for Unity branches on previous line here?
                    }
                }

                // Then remove Unity branches
                if (RemoveUnityBranches)
                    lines[i] = lines[i].Replace("UNITY_BRANCH", "").Replace("[branch]", "");

                // Replace animated properties with their generated unique names
                if (ReplaceAnimatedParameters)
                    foreach (string animPropName in animProps)
                    {
                        int nameIndex;
                        int lastIndex = 0;
                        while ((nameIndex = lines[i].IndexOf(animPropName, lastIndex)) != -1)
                        {
                            lastIndex = nameIndex+1;
                            char charLeft = ' ';
                            if (nameIndex-1 >= 0)
                                charLeft = lines[i][nameIndex-1];
                            char charRight = ' ';
                            if (nameIndex + animPropName.Length < lines[i].Length)
                                charRight = lines[i][nameIndex + animPropName.Length];
                            // Skip invalid matches (probably a subname of another symbol)
                            if (!(Array.Exists(ValidSeparators, x => x == charLeft) && Array.Exists(ValidSeparators, x => x == charRight)))
                                continue;
                            
                            StringBuilder sb = new StringBuilder(lines[i].Length * 2);
                            sb.Append(lines[i], 0, nameIndex);
                            sb.Append(animPropName + "_" + material.GetTag("AnimatedParametersSuffix", false, String.Empty));
                            sb.Append(lines[i], nameIndex+animPropName.Length, lines[i].Length-nameIndex-animPropName.Length);
                            lines[i] = sb.ToString();
                        }
                    }
            }
        }

        public static bool Unlock (Material material)
        {
            string originalShaderName = material.GetTag(OriginalShaderTag, false, String.Empty);
            if (originalShaderName == "")
            {
                Debug.LogError("[Kaj Shader Optimizer] Original shader not saved to material, could not unlock shader");
                return false;
            }
            Shader orignalShader = Shader.Find(originalShaderName);
            if (orignalShader == null)
            {
                Debug.LogError("[Kaj Shader Optimizer] Original shader " + originalShaderName + " could not be found");
                return false;
            }
            // For some reason when shaders are swapped on a material the RenderType override tag gets completely deleted and render queue set back to -1
            // So these are saved as temp values and reassigned after switching shaders
            string renderType = material.GetTag("RenderType", false, String.Empty);
            int renderQueue = material.renderQueue;
            material.shader = orignalShader;
            material.SetOverrideTag("RenderType", renderType);
            material.renderQueue = renderQueue;
            return true;
        }
    }
}
