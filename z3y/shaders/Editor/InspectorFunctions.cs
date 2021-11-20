using System.Collections.Generic;
using UnityEditor;
using UnityEngine;
using System.IO;
using System;

namespace z3y
{
    [InitializeOnLoad]
    public static class Func
    {
        public static Texture2D groupTex = (Texture2D)Resources.Load( EditorGUIUtility.isProSkin ? "lit_group" : "lit_group_light", typeof(Texture2D));
        public static Texture2D animatedTex = (Texture2D)Resources.Load( "lit_animated", typeof(Texture2D));
        public static Texture2D xTex = (Texture2D)Resources.Load( "lit_x", typeof(Texture2D));


        public static bool TextureFoldout(bool display)
        {
            //var rect = GUILayoutUtility.GetRect(16f, -4);
            var lastRect = GUILayoutUtility.GetLastRect();
            var e = Event.current;
            var toggleRect = new Rect(lastRect.x, lastRect.y + 2f, 12f, 12f);
            if (e.type == EventType.Repaint)
            {
                EditorStyles.foldout.Draw(toggleRect, false, false, display, false);
            }
            if (e.type == EventType.MouseDown && toggleRect.Contains(e.mousePosition))
            {
                display = !display;
                e.Use();
            }
            return display;
        }

        public static bool Foldout(string title, bool display)
        {
            var rect = DrawFoldout(title, new Vector2(18f, 0f),18);
            var e = Event.current;
            var toggleRect = new Rect(rect.x + 12f, rect.y + 3f, 13f, 13f);
            if (e.type == EventType.Repaint)
            {
                EditorStyles.foldout.Draw(toggleRect, false, false, display, false);
            }
            if (e.type == EventType.MouseDown && rect.Contains(e.mousePosition))
            {
                display = !display;
                e.Use();
            }
            return display;
        }

        public static Rect DrawFoldout(string title, Vector2 contentOffset, int HeaderHeight)
        {
            var style = new GUIStyle("BoldLabel");
            style.font = new GUIStyle(EditorStyles.boldLabel).font;
            //style.font = EditorStyles.boldFont;
            //style.fontSize = GUI.skin.font.fontSize;
            style.fontSize = 12;
            //style.border = new RectOffset(15, 7, 4, 4);
            style.fixedHeight = HeaderHeight;
            style.contentOffset = contentOffset;
            var rect = GUILayoutUtility.GetRect(16f, HeaderHeight, style);
            var rect2 = new Rect(rect.x + -20f, rect.y, rect.width + 30f, rect.height+2);
            var rectText = new Rect(rect.x -8f, rect.y+1, rect.width, rect.height);

            GUI.DrawTexture(rect2, groupTex);
            GUI.Label(rectText, title, style);
            return rect2;
        }

       public static void PropertyGroup(Action action)
       {
            GUILayout.Space(1);
			using (new EditorGUILayout.VerticalScope("box"))
            {
                GUILayout.Space(1);
                action();
                GUILayout.Space(1);
			}
			GUILayout.Space(1);
		}

        // Mimics the normal map import warning - written by Orels1
		static bool TextureImportWarningBox(string message)
        {
			GUILayout.BeginVertical(new GUIStyle(EditorStyles.helpBox));
			EditorGUILayout.LabelField(message, new GUIStyle(EditorStyles.label) {
				fontSize = 11, wordWrap = true
			});
			EditorGUILayout.BeginHorizontal(new GUIStyle() {
				alignment = TextAnchor.MiddleRight
			}, GUILayout.Height(24));
			EditorGUILayout.Space();
			bool buttonPress = GUILayout.Button("Fix Now", new GUIStyle("button") {
				stretchWidth = false,
				margin = new RectOffset(0, 0, 0, 0),
				padding = new RectOffset(8, 8, 0, 0)
			}, GUILayout.Height(22));
			EditorGUILayout.EndHorizontal();
			GUILayout.EndVertical();
			return buttonPress;
		}

		public static void sRGBWarning(MaterialProperty tex){
			if (tex.textureValue){
				string sRGBWarning = "This texture is marked as sRGB, but should not contain color information.";
				string texPath = AssetDatabase.GetAssetPath(tex.textureValue);
				TextureImporter texImporter;
				var importer = TextureImporter.GetAtPath(texPath) as TextureImporter;
				if (importer != null){
					texImporter = (TextureImporter)importer;
					if (texImporter.sRGBTexture){
						if (TextureImportWarningBox(sRGBWarning)){
							texImporter.sRGBTexture = false;
							texImporter.SaveAndReimport();
						}
					}
				}
			}
		}
        private const char hoverSplitSeparator = ':';
        public static void MaterialProp(MaterialProperty property, MaterialProperty extraProperty, MaterialEditor me, bool isLocked, Material material)
        {

            EditorGUI.BeginDisabledGroup(isLocked);

            string animatedPropName = null;

            if( property.type == MaterialProperty.PropType.Range ||
                property.type == MaterialProperty.PropType.Float ||
                property.type == MaterialProperty.PropType.Vector ||
                property.type == MaterialProperty.PropType.Color)
            {
                me.ShaderProperty(property, property.displayName);
                animatedPropName = property.name.ToString();

            }

            if(property.type == MaterialProperty.PropType.Texture) 
            {
                string[] p = property.displayName.Split(hoverSplitSeparator);
                animatedPropName = extraProperty != null ? extraProperty.name.ToString() : null;



                me.TexturePropertySingleLine(new GUIContent(p[0], p.Length == 2 ? p[1] : null), property, extraProperty);
            }

            AnimatedPropertyToggle(animatedPropName, material);

            EditorGUI.EndDisabledGroup();
 
        }
        const string AnimatedPropertySuffix = "Animated";

        public static void AnimatedPropertyToggle (string k, Material material)
        {
            if(k == null) return;
            string animatedName = k + AnimatedPropertySuffix;
            bool isAnimated = material.GetTag(animatedName, false) == "" ? false : true;
            var e = Event.current;

            if (e.type == EventType.MouseDown && GUILayoutUtility.GetLastRect().Contains(e.mousePosition) && e.button == 2)
            {
                e.Use();
                material.SetOverrideTag(animatedName, isAnimated ? "" : "1");
            }
            if(isAnimated)
            {
                Rect lastRect = GUILayoutUtility.GetLastRect();
                Rect stopWatch = new Rect(lastRect.x - 16f, lastRect.y + 4f, 11f, 11f);

                GUI.DrawTexture(stopWatch, Func.animatedTex);

            }
        }

        public static void ListAnimatedProps(bool isLocked, MaterialProperty[] allProps, Material material)
        {
            EditorGUI.indentLevel--;
            EditorGUILayout.HelpBox("Middle click a property to keep it unlocked", MessageType.Info);
            EditorGUI.indentLevel++;

            EditorGUI.BeginDisabledGroup(isLocked);
            foreach(MaterialProperty property in allProps){
                string animatedName = property.name + AnimatedPropertySuffix;
                bool isAnimated = material.GetTag(animatedName, false) == "" ? false : true;
                if (isAnimated)
                { 
                    EditorGUILayout.LabelField(property.displayName);
                    Rect lastRect = GUILayoutUtility.GetLastRect();
                    Rect x = new Rect(lastRect.x, lastRect.y + 4f, 15f, 12f);
                    GUI.DrawTexture(x, Func.xTex);

                    var e = Event.current;
                    if (e.type == EventType.MouseDown && x.Contains(e.mousePosition) && e.button == 0)
                    {
                        e.Use();
                        material.SetOverrideTag(animatedName, "");
                    }
                }
            }
            EditorGUI.EndDisabledGroup();
        }

        public static void propTileOffset(MaterialProperty property, bool isLocked, MaterialEditor me, Material material)
        {
            EditorGUI.BeginDisabledGroup(isLocked);
            me.TextureScaleOffsetProperty(property);
            AnimatedPropertyToggle(property.name.ToString(), material);
            EditorGUI.EndDisabledGroup();
        }

        public static bool Foldout(string foldoutText, bool foldoutName, Action action)
        {
            foldoutName = Func.Foldout(foldoutText, foldoutName);
            if(foldoutName)
            {
                EditorGUILayout.Space();
			    action();
                EditorGUILayout.Space();
            }
            return foldoutName;
        }

        public static bool TriangleFoldout(bool foldoutName, Action action)
        {
            foldoutName = Func.TextureFoldout(foldoutName);
            if(foldoutName)
            {
                Func.PropertyGroup(() => {
                    action();
                });
            }
            return foldoutName;
        }

        public static void ShaderOptimizerButton(MaterialProperty shaderOptimizer, MaterialEditor materialEditor)
        {
            if (materialEditor.targets.Length == 1)
            {
               
                EditorGUI.BeginChangeCheck();
                if (shaderOptimizer.floatValue == 0)
                {
                    GUILayout.Button("Lock");
                }
                else GUILayout.Button("Unlock");
                if (EditorGUI.EndChangeCheck())
                {
                    shaderOptimizer.floatValue = shaderOptimizer.floatValue == 1 ? 0 : 1;
                    if (shaderOptimizer.floatValue == 1)
                    {
                        foreach (Material m in materialEditor.targets)
                        {
                            MaterialProperty[] props = MaterialEditor.GetMaterialProperties(new UnityEngine.Object[] { m });
                            if (!ShaderOptimizer.Lock(m, props))
                                m.SetFloat(shaderOptimizer.name, 0);
                        }
                    }
                    else
                    {
                        #if BAKERY_INCLUDED
                            ShaderOptimizer.RevertHandleBakeryPropertyBlocks();
                        #endif
                        foreach (Material m in materialEditor.targets)
                            if (!ShaderOptimizer.Unlock(m))
                                m.SetFloat(shaderOptimizer.name, 1);
                    }
                }
                EditorGUILayout.Space(4);
            }
        }

        public static void SetupMaterialWithBlendMode(Material material, float type)
        {
            switch (type)
            {
                case 0:
                    material.SetOverrideTag("RenderType", "");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                    material.SetInt("_ZWrite", 1);
                    material.SetInt("_AlphaToMask", 0);
                    material.renderQueue = -1;
                    break;
                case 1:
                    material.SetOverrideTag("RenderType", "TransparentCutout");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                    material.SetInt("_ZWrite", 1);
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.AlphaTest;
                    break;
                case 2:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.SetInt("_ZWrite", 0);
                    material.SetInt("_AlphaToMask", 0);
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    break;
                case 3:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.SetInt("_ZWrite", 0);
                    material.SetInt("_AlphaToMask", 0);
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    break;
            }
        }

        public static void SetupGIFlags(float emissionEnabled, Material material)
        {
            MaterialGlobalIlluminationFlags flags = material.globalIlluminationFlags;
            if ((flags & (MaterialGlobalIlluminationFlags.BakedEmissive | MaterialGlobalIlluminationFlags.RealtimeEmissive)) != 0)
            {
                flags &= ~MaterialGlobalIlluminationFlags.EmissiveIsBlack;
                if (emissionEnabled != 1)
                    flags |= MaterialGlobalIlluminationFlags.EmissiveIsBlack;

                material.globalIlluminationFlags = flags;
            }
        }

        

        

        


    }
}

