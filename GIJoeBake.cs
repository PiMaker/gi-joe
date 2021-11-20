#if UNITY_EDITOR

using UnityEngine;
using UnityEditor;
using UnityEngine.SceneManagement;
using UnityEditor.SceneManagement;
using System.IO;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Linq;

public class GIJoeBake : ScriptableWizard
{
    public bool renderGIjoe = true;
    public bool render = true;
    public bool renderLightProbes = true;
    public bool renderReflectionProbes = true;

    public Material[] emissiveDisable;

    static bool _renderGIjoe, _render, _renderLightProbes, _renderReflectionProbes;
    public static Material[] _emissiveDisable;
    static IEnumerator progressFunc;

    static void FixBakeryOutputPath(string dir, string suffix)
    {
        Debug.LogWarning(AssetDatabase.RenameAsset("Assets/" + dir, dir + suffix));
        foreach (var file in Directory.EnumerateFiles("Assets"))
        {
            var fname = Path.GetFileName(file);
            if (fname.StartsWith("LMGroup_") &&
                (fname.EndsWith(".hdr") || fname.EndsWith(".tga")))
                Debug.LogWarning(AssetDatabase.MoveAsset("Assets/" + fname, $"Assets/{dir}{suffix}/{fname}"));
        }
    }

    static IEnumerator BatchBakeFunc()
    {
        var bakery = ftRenderLightmap.instance;
        if (bakery == null)
        {
            throw new System.Exception("Bakery not found? :/");
        }
        bakery.LoadRenderSettings();

        var dir = bakery.renderSettingsStorage.renderSettingsOutPath;
        Debug.Log("GI Joe: Bakery output dir = " + dir);

        if (!Directory.Exists("Assets\\" + dir))
            AssetDatabase.CreateFolder("Assets", dir);

        if (_renderGIjoe)
        {
            var lightStates = new List<string>();
            foreach (var g in
                GameObject.FindObjectsOfType<BakeryPointLight>().Cast<Behaviour>().Concat(
                    GameObject.FindObjectsOfType<BakeryDirectLight>().Cast<Behaviour>().Concat(
                        GameObject.FindObjectsOfType<BakerySkyLight>().Cast<Behaviour>().Concat(
                            GameObject.FindObjectsOfType<BakeryLightMesh>().Cast<Behaviour>()
                        )
                    )
                )
            ) {
                if (!g.gameObject.activeSelf) continue;
                Debug.Log($"GI Joe: disabling regular light {g.gameObject.name} (en: {g.enabled})");
                lightStates.Add(g.gameObject.name);
                g.enabled = false;
                //g.gameObject.SetActive(false); // otherwise can't be found with GO.Find again!
            }

            var matdisdict = new List<(Material, string)>();
            if (_emissiveDisable != null) {
                foreach (var g in _emissiveDisable)
                {
                    Debug.Log($"GI Joe: disabling emissive material {g.name}");
                    matdisdict.Add((g, g.shader.name));
                    g.shader = Shader.Find("Unlit/Color");
                }
            }

            var namesDone = new HashSet<string>();

            retry: // here the magic happens
            foreach (var joe in GameObject.FindGameObjectsWithTag("GIJoe"))
            {
                var squares = new GameObject[2];
                foreach (Transform square in joe.transform)
                {
                    var sq = square.gameObject;
                    int nr;
                    if (sq == null || !int.TryParse(sq.name, out nr)) continue;
                    squares[nr] = sq;
                }

                for (int i = 0; i < squares.Length; i++)
                {
                    var name = $"{joe.name}_{i}";
                    if (namesDone.Contains(name))
                    {
                        continue;
                    }
                    namesDone.Add(name);

                    Debug.Log($"GI Joe: baking square {name}");

                    var sq = squares[i];
                    foreach (var s in squares)
                    {
                        s.SetActive(s == sq);
                    }

                    if (!Directory.Exists("Assets\\" + dir))
                        AssetDatabase.CreateFolder("Assets", dir);
                    EditorSceneManager.MarkAllScenesDirty();
                    EditorSceneManager.SaveOpenScenes();

                    bakery.RenderButton(false);
                    while(ftRenderLightmap.bakeInProgress)
                    {
                        yield return null;
                    }
                    FixBakeryOutputPath(dir, "_" + name);

                    goto retry;
                }

                foreach (var s in squares)
                {
                    s.SetActive(false);
                }
            }

            foreach (var key in lightStates)
            {
                var go = GameObject.Find(key);
                if (go != null)
                {
                    Debug.Log("GI Joe: Resetting Bakery light: " + go.name);
                    Behaviour b;

                    b = go.GetComponent<BakeryPointLight>();
                    if (b != null) b.enabled = true;
                    b = go.GetComponent<BakeryDirectLight>();
                    if (b != null) b.enabled = true;
                    b = go.GetComponent<BakerySkyLight>();
                    if (b != null) b.enabled = true;
                    b = go.GetComponent<BakeryLightMesh>();
                    if (b != null) b.enabled = true;
                } else {
                    Debug.Log("GI Joe: FAILED resetting Bakery light (not found): " + key);
                }
            }

            foreach (var item in matdisdict)
            {
                Debug.Log($"GI Joe: re-enabling emissive material (by saved): {item.Item1.name}");
                item.Item1.shader = Shader.Find(item.Item2);
            }

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh();
            EditorSceneManager.MarkAllScenesDirty();
            EditorSceneManager.SaveOpenScenes();

            Debug.Log("GI Joe: special bake done");
        }

        if (_render)
        {
            Debug.Log("GI Joe: running normal Bakery bake");

            bakery.RenderButton(false);
            while(ftRenderLightmap.bakeInProgress)
            {
                yield return null;
            }

            FixBakeryOutputPath(dir, "");
        }

        if (_renderLightProbes)
        {
            Debug.Log("GI Joe: running light probe bake");

            foreach (var joe in GameObject.FindGameObjectsWithTag("GIJoe"))
            {
                foreach (Transform square in joe.transform)
                {
                    var sq = square.gameObject;
                    int nr;
                    if (sq == null || !int.TryParse(sq.name, out nr)) continue;
                    if (nr != 5 && nr != 6) continue;
                    sq.SetActive(true);
                }
            }

            bakery.RenderLightProbesButton(false);
            while(ftRenderLightmap.bakeInProgress)
            {
                yield return null;
            }

            foreach (var joe in GameObject.FindGameObjectsWithTag("GIJoe"))
            {
                foreach (Transform square in joe.transform)
                {
                    var sq = square.gameObject;
                    int nr;
                    if (sq == null || !int.TryParse(sq.name, out nr)) continue;
                    sq.SetActive(false);
                }
            }
        }

        if (_renderReflectionProbes)
        {
            Debug.Log("GI Joe: running reflection probe bake");

            bakery.RenderReflectionProbesButton(false);
            while(ftRenderLightmap.bakeInProgress)
            {
                yield return null;
            }
        }

        EditorSceneManager.MarkAllScenesDirty();
        EditorSceneManager.SaveOpenScenes();
        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        yield return null;

        Debug.Log("GI Joe: bake finished");
    }

    static void BatchBakeUpdate()
    {
        if (progressFunc.MoveNext()) return;
        EditorApplication.update -= BatchBakeUpdate;
    }

	void OnWizardCreate()
	{
        _renderGIjoe = renderGIjoe;
        _render = render;
        _renderLightProbes = renderLightProbes;
        _renderReflectionProbes = renderReflectionProbes;
        _emissiveDisable = emissiveDisable;
        progressFunc = BatchBakeFunc();
        EditorApplication.update += BatchBakeUpdate;
	}

	[MenuItem ("Bakery/GI Joe bake")]
	public static void RenderCubemap () {
		ScriptableWizard.DisplayWizard("GI Joe bake", typeof(GIJoeBake), "GI Joe bake");
	}
}

#endif
