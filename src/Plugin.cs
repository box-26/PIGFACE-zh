using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Text;
using BepInEx;
using HarmonyLib;
using TMPro;
using UnityEngine;
using UnityEngine.TextCore;
using UnityEngine.TextCore.LowLevel;
using UGlyph = UnityEngine.TextCore.Glyph;
using UGlyphRect = UnityEngine.TextCore.GlyphRect;

namespace PigfaceCN
{
    [BepInPlugin("pigface.cn.font", "PigfaceCN", "1.8.0")]
    public class Plugin : BaseUnityPlugin
    {
        internal static BepInEx.Logging.ManualLogSource Log;
        internal static TMP_FontAsset CnFont;
        internal static Dictionary<string, string> Dict;
        internal static List<KeyValuePair<string, string>> Frag;
        internal static string OutDir;

        static readonly HashSet<string> Seen = new HashSet<string>();
        static StreamWriter Writer;

        void Awake()
        {
            Log = Logger;
            OutDir = Path.Combine(Paths.BepInExRootPath, "PigfaceCN");
            Directory.CreateDirectory(OutDir);
            Writer = new StreamWriter(Path.Combine(OutDir, "seen.txt"), true, new UTF8Encoding(false));
            Writer.AutoFlush = true;
            Log.LogInfo("PigfaceCN v1.8 starting");
            Log.LogInfo("repo: https://github.com/box-26/PIGFACE-zh");

            try { LoadDict(); } catch (Exception e) { Log.LogError("load dict: " + e); }
            try { LoadAllow(); } catch (Exception e) { Log.LogError("load allow: " + e); }

            if (Dict != null && Dict.Count > 0)
            {
                try
                {
                    string chars = CollectChars();
                    Log.LogInfo("charset size = " + chars.Length);
                    CnFont = BuildCnFont(chars);
                }
                catch (Exception e) { Log.LogError("build font: " + e); }

                // No usable CJK font means every Chinese glyph would render as a box.
                // Better to show the original English than a screen full of tofu.
                if (CnFont == null)
                {
                    Dict.Clear();
                    if (Frag != null) Frag.Clear();
                    Log.LogWarning("font: NONE -> translation disabled (English UI kept)");
                }
            }

            try { InstallFallback(); } catch (Exception e) { Log.LogError("fallback: " + e); }

            try
            {
                string[] probes = new string[]
                {
                    "this is your crafting station\n\nfind <b>blueprints and components during jobs</b> to up your supply of meds and unlock special pieces of equipment",
                    "hospital bills -$13",
                    "\u00bb (optional) kill all the gang members (7/25)",
                    "Cash: $15105<br> <br>Mask: no_mask<br> <br>Armour: None",
                    "r870<br><br>spd pnlty: 10%<br>dmg: 27x16<br>rnds: 7<br>rpm: 60<br>innac: 5.62<br>loud: 11.25m",
                    "CLOSE <sprite name=\"controller/keyboard/tab\"> ",
                    "Cash: $427329<br> <br>Mask: jack_rabbit<br> <br>Armour: Medium",
                    "+4 adhesive",
                    "+2 adhesive, +2 hospital junk",
                    "- electrical scrap x10",
                    "no_mask",
                    "mask not found",
                    "no_mask<br><br>",
                    "+ bear traps blueprint unlocked!",
                    "+ landmine schematics unlocked!",
                    "bear trap (x13)",
                    "morphine (x6)",
                    "Good.",
                    "empty",
                    "warehouse job accepted",
                    "birthday_girl mask found!",
                    "morphine blueprint unlocked!",
                    "Caesar?",
                    "Sample came back. ",
                    "Yes sir.",
                    "Uh-huh.",
                    "'course.",
                    "Affirmative.",
                    "Hmph.",
                    "What?",
                    "100 LMG ammo picked up"
                };
                for (int i = 0; i < probes.Length; i++)
                {
                    string z;
                    bool ok = TryLookup(probes[i], out z);
                    Log.LogInfo("probe" + i + " " + (ok ? "HIT: " + Trunc(z, 60) : "MISS"));
                }
            }
            catch (Exception e) { Log.LogError("probe: " + e); }

            try
            {
                var h = new Harmony("pigface.cn.font");
                h.PatchAll(typeof(Plugin).Assembly);
                Log.LogInfo("harmony patched ok");
            }
            catch (Exception e) { Log.LogError("patch failed: " + e); }

            if (File.Exists(Path.Combine(OutDir, "debug.flag"))) StartCoroutine(Shot());
            StartCoroutine(ScanLoop());
        }

        void Update()
        {
            try
            {
#if PIGFACE_DEBUG
                if (Input.GetKeyDown(KeyCode.F9)) StartCoroutine(DumpScreen());
                if (Input.GetKeyDown(KeyCode.F10)) StartCoroutine(TestRender());
                if (Input.GetKeyDown(KeyCode.F8)) DumpObjectives();
                if (Input.GetKeyDown(KeyCode.F7)) CompleteObjectives();
#endif
            }
            catch { }
        }

#if PIGFACE_DEBUG
        // Dev-only helpers (never compiled into the release build).
        static Type GameType(string name)
        {
            foreach (var a in AppDomain.CurrentDomain.GetAssemblies())
            {
                if (a.GetName().Name != "Assembly-CSharp") continue;
                var t = a.GetType(name, false);
                if (t != null) return t;
            }
            return null;
        }

        static System.Collections.IList ObjectiveList()
        {
            var mt = GameType("ObjectiveManager");
            if (mt == null) { Log.LogWarning("obj: ObjectiveManager type missing"); return null; }
            var inst = mt.GetField("Instance", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
            object mgr = inst != null ? inst.GetValue(null) : null;
            if (mgr == null) { Log.LogWarning("obj: no ObjectiveManager instance (not in a level?)"); return null; }
            var lf = mt.GetField("objectives", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            return lf != null ? lf.GetValue(mgr) as System.Collections.IList : null;
        }

        static void DumpObjectives()
        {
            try
            {
                var list = ObjectiveList();
                if (list == null) return;
                Log.LogInfo("obj: dump count=" + list.Count);
                var ot = GameType("Objective");
                for (int i = 0; i < list.Count; i++)
                {
                    object o = list[i];
                    string desc = "-", done = "?", main = "?";
                    try
                    {
                        var fd = ot.GetField("_objectiveDescription", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                        var fc = ot.GetField("_completed", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                        var fm = ot.GetField("_mainObjective", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                        desc = (fd != null ? fd.GetValue(o) : null) as string ?? "-";
                        done = fc != null ? fc.GetValue(o).ToString() : "?";
                        main = fm != null ? fm.GetValue(o).ToString() : "?";
                    }
                    catch (Exception e) { desc = "ERR " + e.Message; }
                    Log.LogInfo("obj[" + i + "] main=" + main + " done=" + done + " | " + Trunc(desc, 80));
                }
            }
            catch (Exception e) { Log.LogWarning("obj: dump failed " + e.Message); }
        }

        static void CompleteObjectives()
        {
            try
            {
                var list = ObjectiveList();
                if (list == null) return;
                var ot = GameType("Objective");
                var done = ot.GetMethod("ObjectiveCompleted", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                var fc = ot.GetField("_completed", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                int n = 0;
                for (int i = 0; i < list.Count; i++)
                {
                    object o = list[i];
                    try
                    {
                        if (fc != null && (bool)fc.GetValue(o)) continue;
                        if (done != null) { done.Invoke(o, null); n++; }
                    }
                    catch (Exception e) { Log.LogWarning("obj: complete[" + i + "] failed " + e.Message); }
                }
                var mt = GameType("ObjectiveManager");
                var inst = mt.GetField("Instance", System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Static);
                object mgr = inst != null ? inst.GetValue(null) : null;
                if (mgr != null)
                {
                    foreach (var name in new string[] { "CheckCompletion", "CheckObjectiveProgress" })
                    {
                        var m = mt.GetMethod(name, System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
                        try { if (m != null) m.Invoke(mgr, null); } catch (Exception e) { Log.LogWarning("obj: " + name + " failed " + e.Message); }
                    }
                }
                Log.LogInfo("obj: completed " + n + " objectives (of " + list.Count + ")");
            }
            catch (Exception e) { Log.LogWarning("obj: complete failed " + e.Message); }
        }
#endif

#if PIGFACE_DEBUG
        IEnumerator DumpScreen()
        {
            string stamp = DateTime.Now.ToString("HHmmss");
            yield return StartCoroutine(Cap("dump_" + stamp + ".png"));
            var sb = new StringBuilder();
            var left = new StringBuilder();
            sb.AppendLine("=== F9 DUMP " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " ===");
            var tt = Resources.FindObjectsOfTypeAll<TMP_Text>();
            sb.AppendLine("TMP_Text count=" + tt.Length);
            for (int i = 0; i < tt.Length; i++)
            {
                var t = tt[i];
                if (t == null) continue;
                string s = t.text;
                if (string.IsNullOrEmpty(s)) continue;
                sb.AppendLine("--- " + P(t.transform));
                sb.AppendLine("  text: " + Esc(s));
                if (Unl(s)) left.AppendLine(P(t.transform) + " | " + Esc(s));
                sb.AppendLine("  active=" + t.gameObject.activeInHierarchy + " enabled=" + t.enabled + " fontSize=" + t.fontSize + " color=" + ColorUtility.ToHtmlStringRGB(t.color));
                var f = t.font;
                if (f != null)
                {
                    string mn = (f.material != null) ? f.material.name : "-";
                    string sn = (f.material != null && f.material.shader != null) ? f.material.shader.name : "-";
                    int fb = (f.fallbackFontAssetTable == null) ? 0 : f.fallbackFontAssetTable.Count;
                    sb.AppendLine("  font=" + f.name + " mat=" + mn + " shader=" + sn + " pop=" + f.atlasPopulationMode + " fb=" + fb + " atlas=" + f.atlasWidth + "x" + f.atlasHeight);
                    var m = f.material;
                    if (m != null)
                        sb.AppendLine("  m: gs=" + m.GetFloat("_GradientScale") + " tw=" + m.GetFloat("_TextureWidth") + " th=" + m.GetFloat("_TextureHeight") + " ow=" + m.GetFloat("_OutlineWidth") + " under=" + m.GetFloat("_UnderlayOffsetX") + "," + m.GetFloat("_UnderlayDilate"));
                }
            }
            var ut = Resources.FindObjectsOfTypeAll<UnityEngine.UI.Text>();
            sb.AppendLine("UI.Text count=" + ut.Length);
            for (int i = 0; i < ut.Length; i++)
            {
                var t = ut[i];
                if (t == null || string.IsNullOrEmpty(t.text)) continue;
                sb.AppendLine("--- " + P(t.transform) + " | " + Esc(t.text) + " | font=" + (t.font != null ? t.font.name : "-") + " size=" + t.fontSize);
                if (Unl(t.text)) left.AppendLine(P(t.transform) + " | " + Esc(t.text));
            }
            var tm = Resources.FindObjectsOfTypeAll<TextMesh>();
            sb.AppendLine("TextMesh count=" + tm.Length);
            for (int i = 0; i < tm.Length; i++)
            {
                var t = tm[i];
                if (t == null || string.IsNullOrEmpty(t.text)) continue;
                sb.AppendLine("--- " + P(t.transform) + " | " + Esc(t.text) + " | font=" + (t.font != null ? t.font.name : "-") + " size=" + t.fontSize);
                if (Unl(t.text)) left.AppendLine(P(t.transform) + " | " + Esc(t.text));
            }
            File.WriteAllText(Path.Combine(OutDir, "dump_" + stamp + ".txt"), sb.ToString(), new UTF8Encoding(true));
            File.WriteAllText(Path.Combine(OutDir, "dump_" + stamp + "_left.txt"), left.ToString(), new UTF8Encoding(true));
            Log.LogInfo("F9 dump written: dump_" + stamp);
        }

        IEnumerator TestRender()
        {
            TMP_FontAsset courier = null, sans = null;
            foreach (var f in Resources.FindObjectsOfTypeAll<TMP_FontAsset>())
            {
                if (f == null) continue;
                if (f.name.StartsWith("Courier New")) courier = f;
                else if (f.name.StartsWith("just-sans")) sans = f;
            }
            var root = new GameObject("cn_test_canvas");
            var canvas = root.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 30000;
            root.AddComponent<UnityEngine.UI.CanvasScaler>();
            string sample = "测试文本：普普通通的锤子，很适合把人的脑浆敲出来。";
            var sb = new StringBuilder();
            sb.AppendLine("=== TEST RENDER ===");
            var bases = new TMP_FontAsset[] { courier, sans, courier };
            var swap = new bool[] { false, false, true };
            var names = new string[] { "A_courier_fb", "B_sans_fb", "C_courier_swap" };
            for (int i = 0; i < 3; i++)
            {
                var go = new GameObject(names[i]);
                go.transform.SetParent(root.transform, false);
                var t = go.AddComponent<TextMeshProUGUI>();
                var rt = t.rectTransform;
                rt.anchorMin = new Vector2(0, 1); rt.anchorMax = new Vector2(0, 1); rt.pivot = new Vector2(0, 1);
                rt.anchoredPosition = new Vector2(40, -40 - i * 70);
                rt.sizeDelta = new Vector2(1800, 60);
                t.fontSize = 28; t.color = Color.white; t.alignment = TextAlignmentOptions.Left;
                if (bases[i] != null) t.font = bases[i];
                if (swap[i] && CnFont != null) t.font = CnFont;
                t.text = sample;
                yield return null;
                var mat = t.fontSharedMaterial;
                sb.AppendLine(names[i] + " base=" + (bases[i] != null ? bases[i].name : "-") + " font=" + (t.font != null ? t.font.name : "-")
                    + " mat=" + (mat != null ? mat.name : "-")
                    + " tw=" + (mat != null ? mat.GetFloat("_TextureWidth") : -1)
                    + " gs=" + (mat != null ? mat.GetFloat("_GradientScale") : -1)
                    + " face=" + (mat != null ? mat.GetColor("_FaceColor").ToString() : "-")
                    + " under=" + (mat != null ? mat.GetColor("_UnderlayColor").ToString() : "-"));
            }
            var cam = Camera.main;
            if (cam == null) { var cs = Camera.allCameras; if (cs != null && cs.Length > 0) cam = cs[0]; }
            if (cam != null && courier != null)
            {
                for (int k = 0; k < 2; k++)
                {
                    var wgo = new GameObject("W" + k);
                    wgo.transform.SetParent(cam.transform, false);
                    wgo.transform.localPosition = new Vector3(0.10f, 0.10f - k * 0.055f, 0.30f);
                    var w = wgo.AddComponent<TextMeshPro>();
                    w.fontSize = 0.045f;
                    w.alignment = TextAlignmentOptions.Left;
                    w.rectTransform.sizeDelta = new Vector2(0.5f, 0.08f);
                    w.color = Color.white;
                    w.font = (k == 0) ? courier : CnFont;
                    w.text = "普普通通的锤子。";
                    yield return null;
                    var wm = w.fontSharedMaterial;
                    sb.AppendLine("W" + k + " font=" + (w.font != null ? w.font.name : "-") + " mat=" + (wm != null ? wm.name : "-")
                        + " tw=" + (wm != null ? wm.GetFloat("_TextureWidth") : -1) + " gs=" + (wm != null ? wm.GetFloat("_GradientScale") : -1)
                        + " under=" + (wm != null ? wm.GetColor("_UnderlayColor").ToString() : "-"));
                }
            }
            yield return new WaitForSecondsRealtime(0.4f);
            yield return StartCoroutine(Cap("test_render.png"));
            File.WriteAllText(Path.Combine(OutDir, "test_render.txt"), sb.ToString(), new UTF8Encoding(true));
            Log.LogInfo("test render done");
            yield return new WaitForSecondsRealtime(6f);
            UnityEngine.Object.Destroy(root);
        }

#endif

        IEnumerator ScanLoop()
        {
            int round = 0;
            float wait = 0.6f;
            while (true)
            {
                yield return new WaitForSecondsRealtime(wait);
                round++;
                int n = 0;
                try { n = TranslateAll(); } catch (Exception e) { Log.LogError("scan: " + e.Message); }
                // Freshly opened panels get filled within a frame or two; hunt them
                // quickly right after a hit, then back off so idle scenes stay cheap.
                wait = n > 0 ? 0.35f : (round < 30 ? 1f : 2.5f);
            }
        }

        static readonly Dictionary<int, string> Last = new Dictionary<int, string>();

        static bool HasCjk(string s)
        {
            for (int i = 0; i < s.Length; i++) if (s[i] >= 0x4E00 && s[i] <= 0x9FFF) return true;
            return false;
        }

        static readonly HashSet<string> MissSeen = new HashSet<string>();
        static StreamWriter MissWriter;

        // Strings that are meant to stay English: proper nouns, brand-ish tokens.
        // Maintained in BepInEx/PigfaceCN/allow.txt (one per line, # starts a comment).
        static readonly HashSet<string> Allow = new HashSet<string>();

        static void LoadAllow()
        {
            Allow.Clear();
            string[] candidates =
            {
                Path.Combine(OutDir, "allow.txt"),
                Path.Combine(Paths.BepInExRootPath, "plugins", "PigfaceCN", "allow.txt"),
            };
            foreach (string f in candidates)
            {
                if (!File.Exists(f)) continue;
                foreach (string raw in File.ReadAllLines(f, Encoding.UTF8))
                {
                    string line = raw.Trim();
                    if (line.Length == 0 || line[0] == '#') continue;
                    Allow.Add(Norm(line));
                }
                Log.LogInfo("allow list loaded: " + Allow.Count + " entries");
                return;
            }
            Log.LogInfo("allow list: none");
        }

        // Version strings, resolutions and technical acronyms are never translated,
        // so logging them every session only buries the real gaps.
        static bool LooksTechnical(string s)
        {
            string t = s.Trim();
            if (t.Length == 0) return true;
            if (System.Text.RegularExpressions.Regex.IsMatch(t, @"^\d+(\.\d+)?\s+\d+\s*bit$")) return true;
            if (System.Text.RegularExpressions.Regex.IsMatch(t, @"^\d+\s*[x\u00d7]\s*\d+\s*\d+\s*Hz$")) return true;
            int letters = 0;
            bool allUpper = true;
            for (int i = 0; i < t.Length; i++)
            {
                char c = t[i];
                if (!char.IsLetter(c)) continue;
                letters++;
                if (char.IsLower(c)) { allUpper = false; break; }
            }
            return letters >= 2 && allUpper && t.Length <= 12;
        }

        static void Miss(string path, string s)
        {
            if (string.IsNullOrEmpty(s) || s.Length < 3) return;
            bool letter = false;
            for (int i = 0; i < s.Length; i++) { char c = s[i]; if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) { letter = true; break; } }
            if (!letter) return;
            if (Allow.Count > 0 && Allow.Contains(Norm(s))) return;
            if (LooksTechnical(s)) return;
            lock (MissSeen)
            {
                if (!MissSeen.Add(s)) return;
                try
                {
                    if (MissWriter == null)
                    {
                        string d = Path.Combine(Paths.BepInExRootPath, "PigfaceCN");
                        Directory.CreateDirectory(d);
                        MissWriter = new StreamWriter(Path.Combine(d, "miss.log"), true, Encoding.UTF8);
                        MissWriter.AutoFlush = true;
                    }
                    MissWriter.WriteLine(path + "\t" + s.Replace("\r", "\\r").Replace("\n", "\\n"));
                }
                catch { }
            }
        }

        // Strings we produced ourselves through a Harmony patch. The scan loop must not
        // re-translate (and re-write) these, otherwise a component that the game refreshes
        // every frame (the cellphone cash/mask/armour panel) flips between two outputs.
        internal static readonly HashSet<string> Written = new HashSet<string>();

        internal static void MarkWritten(string zh)
        {
            if (string.IsNullOrEmpty(zh)) return;
            if (Written.Count > 6000) Written.Clear();
            Written.Add(zh);
        }

        static int TranslateAll()
        {
            if (Dict == null || Dict.Count == 0) return 0;
            int n = 0;
            var tt = Resources.FindObjectsOfTypeAll<TMP_Text>();
            for (int i = 0; i < tt.Length; i++)
            {
                var t = tt[i];
                if (t == null) continue;
                int id = t.GetInstanceID();
                EnsureFont(t.font);
                string s = t.text;
                if (string.IsNullOrEmpty(s)) continue;
                string prev;
                if (Last.TryGetValue(id, out prev) && prev == s) continue;
                Last[id] = s;
                if (!HasLatin(s)) continue;
                if (Written.Contains(s)) continue;
                Note(s);
                string zh;
                if (!TryLookup(s, out zh)) { Miss(P(t.transform), s); continue; }
                if (CnFont != null) EnsureFont(t.font);
                t.text = zh;
                MarkWritten(zh);
                Last[id] = zh;
                n++;
            }
            var ut = Resources.FindObjectsOfTypeAll<UnityEngine.UI.Text>();
            for (int i = 0; i < ut.Length; i++)
            {
                var t = ut[i];
                if (t == null) continue;
                string s = t.text;
                if (string.IsNullOrEmpty(s)) continue;
                Note(s);
                string zh;
                if (!TryLookup(s, out zh)) { Miss(P(t.transform), s); continue; }
                t.text = zh;
                n++;
            }
            if (n > 0) Log.LogInfo("scanned + translated " + n);
            try { SwapSoldOut(); } catch (Exception e) { Log.LogError("sold: " + e.Message); }
            return n;
        }

        static Texture2D SoldTex;
        static Sprite SoldSprite;
        static bool SoldTried;
        static readonly HashSet<int> SoldDone = new HashSet<int>();

        static void SwapSoldOut()
        {
            if (!SoldTried)
            {
                SoldTried = true;
                string f = FindData("sold.png");
                if (f != null && File.Exists(f))
                {
                    byte[] bytes = File.ReadAllBytes(f);
                    var tex = new Texture2D(2, 2, TextureFormat.RGBA32, false);
                    if (tex.LoadImage(bytes))
                    {
                        SoldTex = tex;
                        SoldSprite = Sprite.Create(tex, new Rect(0, 0, tex.width, tex.height), new Vector2(0.5f, 0.5f));
                        Log.LogInfo("sold.png loaded " + tex.width + "x" + tex.height);
                    }
                }
                else Log.LogWarning("sold.png missing, skip");
            }
            if (SoldTex == null) return;

            var raws = Resources.FindObjectsOfTypeAll<UnityEngine.UI.RawImage>();
            for (int i = 0; i < raws.Length; i++)
            {
                var r = raws[i];
                if (r == null || r.texture == null) continue;
                if (r.texture.name.IndexOf("sold_out", StringComparison.OrdinalIgnoreCase) < 0) continue;
                if (!SoldDone.Add(r.GetInstanceID())) continue;
                r.texture = FitSold(r.texture.width, r.texture.height);
            }
            var imgs = Resources.FindObjectsOfTypeAll<UnityEngine.UI.Image>();
            for (int i = 0; i < imgs.Length; i++)
            {
                var im = imgs[i];
                if (im == null || im.sprite == null) continue;
                var st = im.sprite.texture;
                if (st == null || st.name.IndexOf("sold_out", StringComparison.OrdinalIgnoreCase) < 0) continue;
                if (!SoldDone.Add(im.GetInstanceID())) continue;
                var os = im.sprite;
                Vector2 nPivot = new Vector2(os.pivot.x / os.rect.width, os.pivot.y / os.rect.height);
                { var ft = FitSold(st.width, st.height); im.sprite = Sprite.Create(ft, new Rect(0f, 0f, ft.width, ft.height),
                    nPivot, os.pixelsPerUnit, 0, SpriteMeshType.FullRect, os.border); }
            }
            var rr = Resources.FindObjectsOfTypeAll<Renderer>();
            for (int i = 0; i < rr.Length; i++)
            {
                var rd = rr[i];
                if (rd == null) continue;
                var mats = rd.sharedMaterials;
                for (int m = 0; m < mats.Length; m++)
                {
                    var mat = mats[m];
                    if (mat == null || !mat.HasProperty("_MainTex")) continue;
                    var tx = mat.GetTexture("_MainTex");
                    if (tx == null || tx.name.IndexOf("sold_out", StringComparison.OrdinalIgnoreCase) < 0) continue;
                    if (!SoldDone.Add(rd.GetInstanceID() * 31 + m)) continue;
                    mat.SetTexture("_MainTex", FitSold(tx.width, tx.height));
                }
            }
        }

        static readonly System.Collections.Generic.Dictionary<string, Texture2D> FitCache =
            new System.Collections.Generic.Dictionary<string, Texture2D>();

        // The badge ships at 256x128, the size the original texture had when we measured it.
        // If a game update changes that size, scaling keeps the art aligned instead of stretched.
        static Texture2D FitSold(int w, int h)
        {
            if (SoldTex == null) return null;
            if (w <= 0 || h <= 0) return SoldTex;
            if (w == SoldTex.width && h == SoldTex.height) return SoldTex;
            string key = w + "x" + h;
            Texture2D cached;
            if (FitCache.TryGetValue(key, out cached) && cached != null) return cached;

            var t = new Texture2D(w, h, TextureFormat.RGBA32, false);
            var src = SoldTex.GetPixels32();
            var dst = new Color32[w * h];
            float sx = (float)SoldTex.width / w, sy = (float)SoldTex.height / h;
            for (int y = 0; y < h; y++)
            {
                int syi = Mathf.Min(SoldTex.height - 1, (int)(y * sy)) * SoldTex.width;
                for (int x = 0; x < w; x++)
                {
                    int sxi = Mathf.Min(SoldTex.width - 1, (int)(x * sx));
                    dst[y * w + x] = src[syi + sxi];
                }
            }
            t.SetPixels32(dst);
            t.Apply(false, false);
            t.name = "PF_SOLD";
            FitCache[key] = t;
            Log.LogInfo("sold: scaled to " + w + "x" + h);
            return t;
        }
        static string FindData(string name)
        {
            var cands = new List<string>();
            cands.Add(Path.Combine(Paths.BepInExRootPath, "PigfaceCN", name));
            try
            {
                string d = Path.GetDirectoryName(typeof(Plugin).Assembly.Location);
                if (!string.IsNullOrEmpty(d)) cands.Add(Path.Combine(d, name));
            }
            catch { }
            cands.Add(Path.Combine(Paths.PluginPath, "PigfaceCN", name));
            for (int i = 0; i < cands.Count; i++)
                if (File.Exists(cands[i])) return cands[i];
            return cands[0];
        }

        static void LoadDict()
        {
            string p = FindData("zh.tsv");
            if (!File.Exists(p)) { Log.LogWarning("no zh.tsv at " + p); return; }
            Dict = new Dictionary<string, string>(StringComparer.Ordinal);
            int n = 0;
            foreach (var raw in File.ReadAllLines(p, Encoding.UTF8))
            {
                if (string.IsNullOrEmpty(raw)) continue;
                int t = raw.IndexOf('\t');
                if (t <= 0) continue;
                string en = Norm(Spriteize(raw.Substring(0, t).Replace("\\n", "\n").Replace("\\r", "\r")));
                string zh = Spriteize(raw.Substring(t + 1).Replace("\\n", "\n").Replace("\\r", "\r"));
                if (en.Length == 0) continue;
                Dict[en] = zh;
                n++;
            }
            Log.LogInfo("dict loaded: " + n + " entries");

            string fp = FindData("frag.tsv");
            Frag = new List<KeyValuePair<string, string>>();
            if (File.Exists(fp))
            {
                foreach (var raw in File.ReadAllLines(fp, Encoding.UTF8))
                {
                    if (string.IsNullOrEmpty(raw)) continue;
                    int t = raw.IndexOf('\t');
                    if (t <= 0) continue;
                    string src = Spriteize(raw.Substring(0, t).Replace("\\n", "\n"));
                    string dst = Spriteize(raw.Substring(t + 1).Replace("\\n", "\n"));
                    if (src.Length == 0) continue;
                    Frag.Add(new KeyValuePair<string, string>(src, dst));
                }
            }
            Log.LogInfo("frag loaded: " + Frag.Count + " entries");
            // Longest rule first so "female smilers" wins over "smilers".
            Frag.Sort((a, b) => b.Key.Length.CompareTo(a.Key.Length));
        }

        // "面具：jack_rabbit" / "护甲：Medium": the fragment rules translate the label but
        // leave the raw id behind, so translate the value on its own as well.
        static readonly System.Text.RegularExpressions.Regex PanelValue =
            new System.Text.RegularExpressions.Regex(@"(面具|护甲|药品)\s*([：:])\s*([A-Za-z0-9_\- ]+?)(?=<|$)",
                System.Text.RegularExpressions.RegexOptions.Compiled);

        internal static string FixPanelValues(string r)
        {
            if (r == null) return r;
            return PanelValue.Replace(r, delegate (System.Text.RegularExpressions.Match m)
            {
                string val = m.Groups[3].Value.Trim();
                if (val.Length == 0) return m.Value;
                string zhVal;
                if (Dict != null && Dict.TryGetValue(Norm(val), out zhVal))
                    return m.Groups[1].Value + m.Groups[2].Value + zhVal;
                if (Dict != null && val.IndexOf(' ') >= 0 && Dict.TryGetValue(Norm(val.Replace(' ', '_')), out zhVal))
                    return m.Groups[1].Value + m.Groups[2].Value + zhVal;
                return m.Value;
            });
        }
        // Keybinding prompts embed a live sprite tag ("press <sprite name="controller/keyboard/tab"> ...").
        // Rebinding the key replaces the sprite name, so the stored key would never match again.
        // Collapse every sprite tag to one placeholder before lookup, then put the real tags back.
        static readonly System.Text.RegularExpressions.Regex SpriteTag =
            new System.Text.RegularExpressions.Regex("<sprite\\s+[^>]*>",
                System.Text.RegularExpressions.RegexOptions.IgnoreCase);
        static readonly System.Text.RegularExpressions.Regex SpriteHole =
            new System.Text.RegularExpressions.Regex("<sprite>",
                System.Text.RegularExpressions.RegexOptions.IgnoreCase);

        internal static string Spriteize(string s)
        {
            if (string.IsNullOrEmpty(s)) return s;
            if (s.IndexOf("<sprite", StringComparison.OrdinalIgnoreCase) < 0) return s;
            return SpriteTag.Replace(s, "<sprite>");
        }

        static string RestoreSprites(string zh, string raw)
        {
            if (zh == null || zh.IndexOf("<sprite>", StringComparison.OrdinalIgnoreCase) < 0) return zh;
            var tags = new List<string>();
            if (!string.IsNullOrEmpty(raw))
                foreach (System.Text.RegularExpressions.Match m in SpriteTag.Matches(raw)) tags.Add(m.Value);
            int i = 0;
            return SpriteHole.Replace(zh, delegate (System.Text.RegularExpressions.Match m)
            {
                string t = i < tags.Count ? tags[i] : "";
                i++;
                return t;
            });
        }

        internal static bool TryLookup(string s, out string zh)
        {
            zh = null;
            if (string.IsNullOrEmpty(s)) return false;
            string folded = Spriteize(s);
            if (!ReferenceEquals(folded, s))
            {
                if (!TryLookupCore(folded, out zh)) return false;
                zh = RestoreSprites(zh, s);
                return true;
            }
            return TryLookupCore(s, out zh);
        }

        static bool TryLookupCore(string s, out string zh)
        {
            zh = null;
            if (s == null) return false;
            if (Dict.TryGetValue(Norm(s), out zh))
            {
                if (string.Equals(zh, s, StringComparison.Ordinal)) { zh = null; return false; }
                return true;
            }

            // Item info panels compose "<name><br><br><description>" at runtime, so the
            // whole string is never a dictionary key. Translate the two halves apart.
            {
                var bm = System.Text.RegularExpressions.Regex.Match(s, @"<br>\s*<br>");
                if (bm.Success && bm.Index > 0)
                {
                    string head = s.Substring(0, bm.Index);
                    string tail = s.Substring(bm.Index + bm.Length);
                    string zhHead, zhTail;
                    bool okH = TryLookup(head, out zhHead);
                    bool okT = TryLookup(tail, out zhTail);
                    if (okH || okT)
                    {
                        zh = (okH ? zhHead : head) + bm.Value + (okT ? zhTail : tail);
                        return true;
                    }
                }
            }

            // Unlock toasts are composed at runtime: "+ bear traps blueprint unlocked!" or
            // without the leading "+" ("morphine blueprint unlocked!"). Translate the item
            // name and rebuild the sentence around it.
            {
                var um = System.Text.RegularExpressions.Regex.Match(s.Trim(),
                    @"^(?<plus>\+\s*)?(?<item>.+?)\s+(blueprints?|schematics?)\s+unlocked!$",
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                if (um.Success)
                {
                    string itemZh;
                    if (TryLookup(um.Groups["item"].Value, out itemZh))
                    {
                        string kind = um.Groups[3].Value.ToLowerInvariant().StartsWith("schematic") ? "图纸" : "蓝图";
                        string lead = um.Groups["plus"].Success ? "+ " : "";
                        zh = lead + "已解锁" + itemZh + kind + "！";
                        return true;
                    }
                }
            }

            // Payout toasts: "birthday_girl mask found!" -> "<mask> 已找到！".
            {
                var fm = System.Text.RegularExpressions.Regex.Match(s.Trim(),
                    @"^(?<item>.+?)\s+mask found!$",
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                if (fm.Success)
                {
                    string itemZh;
                    if (TryLookup(fm.Groups["item"].Value, out itemZh))
                    {
                        zh = itemZh.EndsWith("面具") ? itemZh + "已找到！" : itemZh + "面具已找到！";
                        return true;
                    }
                }
            }

            // Item labels carry a count: "bear trap (x13)". PrefixKeys only knows single
            // words, so strip the counter, translate the name, then put the counter back.
            {
                var xm = System.Text.RegularExpressions.Regex.Match(s.Trim(), @"^(?<name>.+?)\s*\(x(?<n>\d+)\)$",
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                if (xm.Success)
                {
                    string nameZh;
                    if (TryLookup(xm.Groups["name"].Value, out nameZh))
                    {
                        zh = nameZh + " (x" + xm.Groups["n"].Value + ")";
                        return true;
                    }
                }
            }

            // Pickup toasts: "100 LMG ammo picked up" -> "捡起 LMG 弹药 ×100".
            {
                var pm = System.Text.RegularExpressions.Regex.Match(s.Trim(),
                    @"^(?<n>\d[\d,]*)\s+(?<item>.+?)\s+picked up$",
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                if (pm.Success)
                {
                    string itemZh;
                    if (TryLookup(pm.Groups["item"].Value, out itemZh))
                    {
                        zh = "捡起 " + itemZh + " ×" + pm.Groups["n"].Value;
                        return true;
                    }
                }
            }

            // Job toasts read "<level> job accepted"; the level name alone is translated.
            {
                var jm = System.Text.RegularExpressions.Regex.Match(s.Trim(), @"^(?<lvl>.+?)\s+job accepted$",
                    System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                if (jm.Success)
                {
                    string lvlZh;
                    if (TryLookup(jm.Groups["lvl"].Value, out lvlZh))
                    {
                        zh = lvlZh + "：任务已接受";
                        return true;
                    }
                }
            }
            // Phone panel rows: "面具：SMILER", "护甲：BANDOLIER". The label is already
            // Chinese but the value is still a raw id, so translate the value alone.
            {
                var pm = System.Text.RegularExpressions.Regex.Match(s, @"^(现金|面具|护甲|药品)\s*[：:]\s*(.+)$");
                if (pm.Success)
                {
                    string val = pm.Groups[2].Value.Trim();
                    string zhv;
                    if (TryLookup(val, out zhv))
                    {
                        zh = pm.Groups[1].Value + "：" + zhv;
                        return true;
                    }
                }
            }

            // Objective rows arrive as "» (OPTIONAL) kill the target (0/3)". Strip the
            // bullet, the optional marker and the "(n/m)" counter, translate the core,
            // then put the pieces back. Runs BEFORE the fragment rules: those used to
            // swallow "(OPTIONAL) " and hand back "（可选） kill the target".
            {
                string src = s.Trim();
                string pre = "";
                bool bullet = false;
                if (src.StartsWith("\u00bb", StringComparison.Ordinal)) { pre = "\u00bb "; src = src.Substring(1).TrimStart(); bullet = true; }
                else if (src.StartsWith(">>", StringComparison.Ordinal)) { pre = ">> "; src = src.Substring(2).TrimStart(); bullet = true; }

                bool opt = false;
                var om = System.Text.RegularExpressions.Regex.Match(src, @"^(\(optional\)|（可选）)\s*", System.Text.RegularExpressions.RegexOptions.IgnoreCase);
                if (om.Success) { src = src.Substring(om.Length); opt = true; }

                string suf = "";
                var cm = System.Text.RegularExpressions.Regex.Match(src, @"\s*\(\d+\s*/\s*\d+\)\s*$");
                if (cm.Success) { suf = cm.Value; src = src.Substring(0, cm.Index).TrimEnd(); }

                if ((bullet || opt) && src.Length > 0)
                {
                    string zhc;
                    if (TryLookup(src, out zhc)) { zh = pre + (opt ? "（可选）" : "") + zhc + suf; return true; }
                }
            }

            // Reward / cost lines: "+4 adhesive", "+2 adhesive, +2 hospital junk",
            // "- electrical scrap x10". The count is added by the game, so only the
            // item names can be looked up.
            {
                string rw;
                if (TryReward(s, out rw)) { zh = rw; return true; }
            }

            // Long untranslated sentences used to get shredded into half-English
            // by the fragment rules below. If a sentence is clearly prose and has no
            // dictionary entry, leave it alone so it shows up in miss.log verbatim.
            {
                int enWords = 0;
                foreach (System.Text.RegularExpressions.Match m in System.Text.RegularExpressions.Regex.Matches(s, "[A-Za-z][A-Za-z']+")) enWords++;
                string trimmed = s.TrimStart();
                bool isObjective = trimmed.StartsWith("\u00bb", StringComparison.Ordinal) || trimmed.StartsWith(">>", StringComparison.Ordinal);
                bool isLabelled = s.IndexOf("<br>", StringComparison.Ordinal) >= 0;
                bool isMarkup = s.IndexOf("<b>", StringComparison.Ordinal) >= 0
                             || s.IndexOf("<color=", StringComparison.Ordinal) >= 0
                             || s.IndexOf("<i>", StringComparison.Ordinal) >= 0;
                if (enWords >= 6 && !isObjective && !isLabelled && !isMarkup) { zh = null; return false; }
            }

            if (Frag != null && Frag.Count > 0)
            {
                string r = s;
                bool any = false;
                for (int i = 0; i < Frag.Count; i++)
                {
                    var kv = Frag[i];
                    if (r.IndexOf(kv.Key, StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        r = ReplaceCI(r, kv.Key, kv.Value);
                        any = true;
                    }
                }
                if (any) { if (string.Equals(r, s, StringComparison.Ordinal)) { zh = null; return false; } zh = FixPanelValues(r); return true; }
            }

            // Objective rows arrive as "» kill the target (0/3)" or ">> (optional) ...".
            // (Handled earlier, before the fragment rules.)

            // Item labels carry suffixes the dictionary cannot know about:
            // "Hammer (x1)", "hammer - $10", "machete (x3)".
            if (PrefixKeys == null) BuildPrefixKeys();
            string nn = Norm(s);
            // "SKS 半自动步枪" still starts with "sks", so re-running this branch would
            // append the translation again on every scan. Labels that already carry
            // Chinese are finished; only untouched English labels get here.
            if (HasCjk(s)) return false;
            for (int i = 0; i < PrefixKeys.Count; i++)
            {
                var kv = PrefixKeys[i];
                if (nn.Length > kv.Key.Length && nn.StartsWith(kv.Key, StringComparison.Ordinal))
                {
                    char nxt = nn[kv.Key.Length];
                    // "metal_armour" must not become "金属_armour": an underscore or a
                    // letter means this is a compound id, not a suffix like " (x1)".
                    if (char.IsLetterOrDigit(nxt) || nxt == '_') continue;
                    // "good work." must not become "好 work.": a suffix made of more words
                    // is a phrase we do not have a rule for, so leave the label alone.
                    string rest = nn.Substring(kv.Key.Length).TrimStart();
                    if (rest.Length > 0 && char.IsLetter(rest[0])) continue;
                    string tail = s.Length > kv.Key.Length ? s.Substring(kv.Key.Length) : "";
                    zh = kv.Value + tail;
                    return true;
                }
            }
            return false;
        }

        // "+4 adhesive" / "+2 adhesive, +2 hospital junk" / "- electrical scrap x10".
        // The quantity and the sign are generated by the game; only the item names are ours.
        static bool TryReward(string s, out string zh)
        {
            zh = null;
            string t = s.Trim();
            if (t.Length < 3) return false;

            string sign = "";
            if (t[0] == '+' || t[0] == '-') { sign = t[0] + " "; t = t.Substring(1).TrimStart(); }

            string qty = "";
            var qm = System.Text.RegularExpressions.Regex.Match(t, @"^(\d[\d,]*)\s+(.+)$");
            if (qm.Success) { qty = qm.Groups[1].Value + " "; t = qm.Groups[2].Value; }

            if (sign.Length == 0 && qty.Length == 0) return false;

            string[] parts = t.Split(new[] { ", " }, StringSplitOptions.None);
            var outParts = new List<string>(parts.Length);
            bool any = false;
            foreach (string raw in parts)
            {
                string item = raw.Trim();
                string xsuf = "";
                var xm = System.Text.RegularExpressions.Regex.Match(item, @"\s+x\d+$");
                if (xm.Success) { xsuf = xm.Value; item = item.Substring(0, xm.Index).TrimEnd(); }
                string zhItem;
                if (item.Length > 0 && TryLookup(item, out zhItem)) { outParts.Add(zhItem + xsuf); any = true; }
                else outParts.Add(raw.Trim());
            }
            if (!any) return false;
            string prefix = (sign.Length > 0 && qty.Length > 0) ? sign.TrimEnd() + qty : sign + qty;
            zh = prefix + string.Join("，", outParts);
            return true;
        }

        static List<KeyValuePair<string, string>> PrefixKeys;

        static void BuildPrefixKeys()
        {
            PrefixKeys = new List<KeyValuePair<string, string>>();
            if (Dict == null) return;
            foreach (var kv in Dict)
            {
                if (kv.Key.Length < 3) continue;
                if (kv.Key.IndexOf(' ') >= 0) continue;
                bool cjk = false;
                foreach (char c in kv.Value) if (c > 127) { cjk = true; break; }
                if (!cjk) continue;
                PrefixKeys.Add(kv);
            }
            PrefixKeys.Sort((a, b) => b.Key.Length.CompareTo(a.Key.Length));
            Plugin.Log.LogInfo("prefix keys: " + PrefixKeys.Count);
        }

        static string CollectChars()
        {
            var set = new HashSet<char>();
            var sb = new StringBuilder();
            foreach (var v in Dict.Values)
                foreach (char c in v)
                {
                    if (c < 32 || c == 127) continue;
                    if (c == '\u3000') { }
                    if (set.Add(c)) sb.Append(c);
                }
            if (Frag != null)
                foreach (var kv in Frag)
                    foreach (char c in kv.Value)
                    {
                        if (c < 128) continue;
                        if (set.Add(c)) sb.Append(c);
                    }
            return sb.ToString();
        }

        static void InstallFallback()
        {
            var all = Resources.FindObjectsOfTypeAll<TMP_FontAsset>();
            if (all == null || all.Length == 0) { Log.LogWarning("no font assets"); return; }
            int n = 0;
            foreach (var fa in all)
            {
                if (fa == null || fa == CnFont) continue;
                var f = typeof(TMP_FontAsset).GetField("m_FallbackFontAssetTable", BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Instance);
                if (f == null) { Log.LogWarning("no fallback field"); return; }
                var list = f.GetValue(fa) as List<TMP_FontAsset>;
                if (list == null) { list = new List<TMP_FontAsset>(); f.SetValue(fa, list); }
                if (!list.Contains(CnFont)) list.Add(CnFont);
                Log.LogInfo("fallback added to '" + fa.name + "' total=" + list.Count);
                n++;
            }
            Log.LogInfo("fallback install done, fonts touched=" + n);
        }

        IEnumerator Shot()
        {
            yield return new WaitForSecondsRealtime(4f);
            try { Dump(); } catch (Exception e) { Log.LogError("dump: " + e.Message); }
            for (int k = 0; k < 3; k++)
            {
                yield return new WaitForSecondsRealtime(2f);
                yield return StartCoroutine(Cap(k == 0 ? "shot_menu.png" : "shot_menu" + k + ".png"));
            }
            yield return new WaitForSecondsRealtime(1f);
            Log.LogInfo("shot: panels");
            yield return StartCoroutine(Panel("menu_canvas/options", "shot_options.png"));
            yield return StartCoroutine(Panel("menu_canvas/credits", "shot_credits.png"));
            Log.LogInfo("shot: done");
        }

        IEnumerator Panel(string suffix, string file)
        {
            Log.LogInfo("panel look: " + suffix);
            Transform found = null;
            try
            {
                var all = Resources.FindObjectsOfTypeAll<Transform>();
                for (int i = 0; i < all.Length; i++)
                {
                    var t = all[i];
                    if (t == null) continue;
                    string pth = P(t);
                    if (pth.EndsWith("/" + suffix, StringComparison.Ordinal) || pth == suffix) { found = t; break; }
                }
            }
            catch (Exception e) { Log.LogError("find " + suffix + ": " + e.Message); }
            if (found == null) { Log.LogWarning("not found: " + suffix); yield break; }
            Log.LogInfo("panel found: " + P(found));
            found.gameObject.SetActive(true);
            yield return new WaitForSecondsRealtime(1.5f);
            yield return StartCoroutine(Cap(file));
        }

        IEnumerator Cap(string file)
        {
            yield return new WaitForEndOfFrame();
            try
            {
                var tex = new Texture2D(Screen.width, Screen.height, TextureFormat.RGB24, false);
                tex.ReadPixels(new Rect(0, 0, Screen.width, Screen.height), 0, 0);
                tex.Apply();
                var b = tex.EncodeToPNG();
                File.WriteAllBytes(Path.Combine(OutDir, file), b);
                Log.LogInfo("cap " + file + " " + Screen.width + "x" + Screen.height + " bytes=" + b.Length);
                UnityEngine.Object.Destroy(tex);
            }
            catch (Exception e) { Log.LogError("cap: " + e); }
        }

        static string P(Transform t)
        {
            var sb = new StringBuilder(t.name);
            var p = t.parent;
            int guard = 0;
            while (p != null && guard++ < 32) { sb.Insert(0, p.name + "/"); p = p.parent; }
            return sb.ToString();
        }

        static string ReplaceCI(string src, string key, string val)
        {
            if (string.IsNullOrEmpty(src) || string.IsNullOrEmpty(key)) return src;
            var sb = new StringBuilder(src.Length);
            int i = 0;
            while (i < src.Length)
            {
                int k = src.IndexOf(key, i, StringComparison.OrdinalIgnoreCase);
                if (k < 0) { sb.Append(src, i, src.Length - i); break; }
                sb.Append(src, i, k - i);
                sb.Append(val);
                i = k + key.Length;
            }
            return sb.ToString();
        }

        static string Esc(string s)
        {
            if (s == null) return "<null>";
            return s.Replace("\r", "\\r").Replace("\n", "\\n");
        }

        // Any ASCII letter means the string may still need work ("NO", "x3", "OK").
        // Unl() is stricter and only used for reporting leftovers.
        static bool HasLatin(string s)
        {
            if (string.IsNullOrEmpty(s)) return false;
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')) return true;
            }
            return false;
        }

        // True when the string still holds English prose that should have become Chinese.
        static bool Unl(string s)
        {
            if (string.IsNullOrEmpty(s)) return false;
            if (s == "SSAO" || s == "FPS") return false;
            if (s.IndexOf("165Hz", StringComparison.Ordinal) >= 0) return false;
            var m = System.Text.RegularExpressions.Regex.Matches(s, "[A-Za-z]{3,}");
            for (int i = 0; i < m.Count; i++)
            {
                string w = m[i].Value.ToLowerInvariant();
                if (w == "exe" || w == "sdf" || w == "vhs") continue;
                return true;
            }
            return false;
        }

        static void Dump()
        {
            var sb = new StringBuilder();
            var scene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            sb.AppendLine("# scene=" + scene.name + " roots=" + scene.GetRootGameObjects().Length);
            int nTmp = 0, nUi = 0, nOther = 0;
            foreach (var root in scene.GetRootGameObjects())
                Walk(root.transform, sb, ref nTmp, ref nUi, ref nOther);
            sb.AppendLine("# totals TMP=" + nTmp + " UI=" + nUi + " OTHER=" + nOther);
            string p = Path.Combine(OutDir, "textdump.txt");
            File.WriteAllText(p, sb.ToString(), new UTF8Encoding(false));
            Log.LogInfo("textdump -> " + p + " TMP=" + nTmp + " UI=" + nUi + " OTHER=" + nOther);

            var all = Resources.FindObjectsOfTypeAll<TMP_Text>();
            var sb2 = new StringBuilder();
            foreach (var t in all) sb2.AppendLine((t == null ? "null" : Esc(t.text)));
            File.WriteAllText(Path.Combine(OutDir, "alltmp.txt"), sb2.ToString(), new UTF8Encoding(false));
            Log.LogInfo("alltmp count=" + all.Length);
        }

        static void Walk(Transform t, StringBuilder sb, ref int nTmp, ref int nUi, ref int nOther)
        {
            var tt = t.GetComponent<TMP_Text>();
            if (tt != null)
            {
                nTmp++;
                sb.AppendLine("TMP|" + P(t) + "|act=" + tt.gameObject.activeInHierarchy + "|en=" + tt.enabled + "|font=" + (tt.font == null ? "-" : tt.font.name) + "|txt=" + Esc(tt.text));
            }
            var ut = t.GetComponent<UnityEngine.UI.Text>();
            if (ut != null)
            {
                nUi++;
                sb.AppendLine("UI|" + P(t) + "|act=" + ut.gameObject.activeInHierarchy + "|font=" + (ut.font == null ? "-" : ut.font.name) + "|txt=" + Esc(ut.text));
            }
            if (tt == null && ut == null)
            {
                foreach (var c in t.GetComponents<Component>())
                {
                    if (c == null) continue;
                    string n = c.GetType().Name;
                    if (n.Contains("Text") || n.Contains("Label") || n.Contains("Font") || n.Contains("Letter"))
                    {
                        nOther++;
                        sb.AppendLine("OTH|" + P(t) + "|" + n + "|act=" + t.gameObject.activeInHierarchy);
                    }
                }
            }
            for (int i = 0; i < t.childCount; i++) Walk(t.GetChild(i), sb, ref nTmp, ref nUi, ref nOther);
        }

        internal static string Trunc(string s, int n)
        {
            if (string.IsNullOrEmpty(s)) return "";
            s = s.Replace("\n", " ").Replace("\r", " ");
            return s.Length <= n ? s : s.Substring(0, n);
        }

        internal static string Norm(string s)
        {
            if (string.IsNullOrEmpty(s)) return "";
            var sb = new StringBuilder(s.Length);
            bool sp = false;
            for (int i = 0; i < s.Length; i++)
            {
                char c = s[i];
                if (c == '\n' || c == '\r' || c == '\t' || c == ' ') { sp = true; continue; }
                // Some assets store a literal backslash-n rather than a newline; both
                // spellings must collapse to the same space so one key serves both.
                if (c == '\\' && i + 1 < s.Length && (s[i + 1] == 'n' || s[i + 1] == 'r'))
                {
                    sp = true; i++; continue;
                }
                if (sp && sb.Length > 0) sb.Append(' ');
                sp = false;
                sb.Append(char.ToLowerInvariant(c));
            }
            return sb.ToString();
        }

        static readonly BindingFlags InstFlags = BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Instance;
        static HashSet<object> Touched;

        internal static void EnsureFont(TMP_FontAsset fa)
        {
            if (fa == null || fa == CnFont) return;
            if (Touched == null) Touched = new HashSet<object>();
            if (Touched.Contains(fa)) return;
            var f = typeof(TMP_FontAsset).GetField("m_FallbackFontAssetTable", InstFlags);
            if (f == null) return;
            var list = f.GetValue(fa) as List<TMP_FontAsset>;
            if (list == null) { list = new List<TMP_FontAsset>(); f.SetValue(fa, list); }
            if (!list.Contains(CnFont)) list.Add(CnFont);
            Touched.Add(fa);
        }

        internal static void Note(string s)
        {
            if (string.IsNullOrEmpty(s)) return;
            lock (Seen)
            {
                if (!Seen.Add(s)) return;
                try { Writer.WriteLine(s.Replace("\r", "\\r").Replace("\n", "\\n")); } catch { }
            }
        }
    // Fonts differ between Windows editions: a Simplified-Chinese install always has
    // SimHei, while an English install may only have Microsoft YaHei / SimSun, and a
    // stripped image may have none at all. Try them in order, then a font shipped next
    // to this dll (font.ttf), and only then give up.
    static TMP_FontAsset BuildCnFont(string chars)
    {
        string winDir = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
        if (string.IsNullOrEmpty(winDir)) winDir = "C:\\Windows";
        string fonts = Path.Combine(winDir, "Fonts");

        string[] names = new string[]
        {
            "simhei.ttf", "msyh.ttc", "msyhl.ttc", "simsun.ttc",
            "Deng.ttf", "NotoSansSC-Regular.otf", "SourceHanSansSC-Regular.otf"
        };
        var candidates = new List<string>();
        for (int i = 0; i < names.Length; i++) candidates.Add(Path.Combine(fonts, names[i]));
        string bundled = Path.Combine(Paths.BepInExRootPath, "PigfaceCN", "font.ttf");
        if (File.Exists(Path.Combine(Paths.BepInExRootPath, "PigfaceCN", "use_bundled.flag")))
            candidates.Insert(0, bundled);
        else
            candidates.Add(bundled);

        for (int i = 0; i < candidates.Count; i++)
        {
            string path = candidates[i];
            if (!File.Exists(path)) continue;
            try
            {
                TMP_FontAsset f = FontBuilder.Build(path, 90, 9, 4096, chars);
                if (f != null)
                {
                    Log.LogInfo("font: " + Path.GetFileName(path));
                    return f;
                }
                Log.LogWarning("font rejected: " + Path.GetFileName(path));
            }
            catch (Exception e)
            {
                Log.LogWarning("font failed " + Path.GetFileName(path) + ": " + e.Message);
            }
        }
        return null;
    }

    }

    internal static class FontBuilder
    {
        static readonly BindingFlags Inst = BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Instance;

        static void SetF(object o, string name, object v)
        {
            var f = typeof(TMP_FontAsset).GetField(name, Inst);
            if (f == null) { Plugin.Log.LogError("field not found: " + name); return; }
            try { f.SetValue(o, v); } catch (Exception e) { Plugin.Log.LogError("set " + name + ": " + e.Message); }
        }

        public static TMP_FontAsset Build(string ttfPath, int pointSize, int padding, int atlasSize, string chars)
        {
            Plugin.Log.LogInfo("[FB] init = " + FontEngine.InitializeFontEngine());
            var err = FontEngine.LoadFontFace(ttfPath, pointSize, 0);
            if (err != FontEngineError.Success) { Plugin.Log.LogError("[FB] load face = " + err); return null; }
            FaceInfo fi = FontEngine.GetFaceInfo();

            var unicodes = new List<uint>();
            var seen = new HashSet<uint>();
            foreach (char c in chars) { if (seen.Add(c)) unicodes.Add(c); }

            var pairs = new List<KeyValuePair<uint, UGlyph>>();
            int maxW = 0, maxH = 0;
            foreach (var u in unicodes)
            {
                uint gi;
                if (!FontEngine.TryGetGlyphIndex(u, out gi)) continue;
                UGlyph g;
                if (!FontEngine.TryGetGlyphWithIndexValue(gi, GlyphLoadFlags.LOAD_DEFAULT, out g)) continue;
                if (g.metrics.width > maxW) maxW = (int)g.metrics.width;
                if (g.metrics.height > maxH) maxH = (int)g.metrics.height;
                pairs.Add(new KeyValuePair<uint, UGlyph>(u, g));
            }
            Plugin.Log.LogInfo("[FB] resolved " + pairs.Count + " glyphs, max bitmap " + maxW + "x" + maxH);
            if (pairs.Count == 0) return null;

            int cellW = maxW + padding * 2, cellH = maxH + padding * 2;
            int perRow = atlasSize / cellW;
            int capacity = perRow * (atlasSize / cellH);
            Plugin.Log.LogInfo("[FB] cell=" + cellW + "x" + cellH + " perRow=" + perRow + " capacity=" + capacity);
            if (pairs.Count > capacity) { Plugin.Log.LogError("[FB] OVERFLOW " + pairs.Count + " > " + capacity); }

            var tex = new Texture2D(atlasSize, atlasSize, TextureFormat.Alpha8, false);
            tex.name = "PF_CN_Atlas";
            tex.filterMode = FilterMode.Bilinear;
            tex.wrapMode = TextureWrapMode.Clamp;

            var glyphs = new List<UGlyph>();
            int idx = 0;
            foreach (var kv in pairs)
            {
                if (idx >= capacity) break;
                int cx = (idx % perRow) * cellW;
                int cy = (idx / perRow) * cellH;
                var g = kv.Value;
                g.glyphRect = new UGlyphRect(cx + padding, cy + padding, (int)g.metrics.width, (int)g.metrics.height);
                g.atlasIndex = 0;
                glyphs.Add(g);
                idx++;
            }

            var render = typeof(FontEngine).GetMethod("RenderGlyphsToTexture", BindingFlags.NonPublic | BindingFlags.Public | BindingFlags.Static,
                null, new[] { typeof(List<UGlyph>), typeof(int), typeof(GlyphRenderMode), typeof(Texture2D) }, null);
            if (render == null) { Plugin.Log.LogError("[FB] render method missing"); return null; }
            var r = render.Invoke(null, new object[] { glyphs, padding, GlyphRenderMode.SDFAA, tex });
            Plugin.Log.LogInfo("[FB] render = " + r);

            // RenderGlyphsToTexture fills the padding ring with mid-gray (128), which TMP
            // samples at the quad edge and turns into a visible frame around every glyph.
            // Clear the ring so the quad edge stays fully transparent.
            try
            {
                var raw = tex.GetRawTextureData();
                int W = atlasSize;
                int cleared = 0;
                for (int i = 0; i < glyphs.Count; i++)
                {
                    int cx = (i % perRow) * cellW, cy = (i / perRow) * cellH;
                    int gx = cx + padding, gy = cy + padding;
                    int gw = (int)glyphs[i].metrics.width, gh = (int)glyphs[i].metrics.height;
                    for (int y = cy; y < cy + cellH; y++)
                    {
                        int row = y * W;
                        bool inGlyphRow = y >= gy && y < gy + gh;
                        for (int x = cx; x < cx + cellW; x++)
                        {
                            if (inGlyphRow && x >= gx && x < gx + gw) continue;
                            if (raw[row + x] != 0) { raw[row + x] = 0; cleared++; }
                        }
                    }
                }
                tex.LoadRawTextureData(raw);
                tex.Apply(false, false);
                Plugin.Log.LogInfo("[FB] padding cleared: " + cleared + " px");
                if (File.Exists(Path.Combine(Plugin.OutDir, "debug.flag")))
                    File.WriteAllBytes(Path.Combine(Plugin.OutDir, "atlas.raw"), raw);
            }
            catch (Exception e) { Plugin.Log.LogWarning("[FB] padding clear failed: " + e.Message); }

            var fa = ScriptableObject.CreateInstance<TMP_FontAsset>();
            fa.name = "PF_CN";
            var mat = new Material(Shader.Find("TextMeshPro/Distance Field"));
            mat.name = "PF_CN Material";
            mat.SetTexture(ShaderUtilities.ID_MainTex, tex);
            mat.SetFloat(ShaderUtilities.ID_TextureWidth, atlasSize);
            mat.SetFloat(ShaderUtilities.ID_TextureHeight, atlasSize);
            mat.SetFloat(ShaderUtilities.ID_GradientScale, padding + 1);
            mat.SetColor(ShaderUtilities.ID_FaceColor, Color.white);
            mat.SetColor(ShaderUtilities.ID_OutlineColor, Color.clear);
            mat.SetFloat(ShaderUtilities.ID_OutlineWidth, 0f);
            mat.SetColor(ShaderUtilities.ID_UnderlayColor, new Color(0f, 0f, 0f, 0f));
            mat.SetFloat(ShaderUtilities.ID_ScaleRatio_A, 1f);
            mat.SetFloat(ShaderUtilities.ID_ScaleRatio_B, 1f);
            mat.SetFloat(ShaderUtilities.ID_ScaleRatio_C, 1f);
            fa.material = mat;

            SetF(fa, "m_Version", "1.1.0");
            SetF(fa, "m_FaceInfo", fi);
            SetF(fa, "m_AtlasTextures", new Texture2D[] { tex });
            SetF(fa, "m_AtlasTexture", tex);
            SetF(fa, "m_AtlasTextureIndex", 0);
            SetF(fa, "m_AtlasWidth", atlasSize);
            SetF(fa, "m_AtlasHeight", atlasSize);
            SetF(fa, "m_AtlasPadding", padding);
            SetF(fa, "m_AtlasRenderMode", GlyphRenderMode.SDFAA);
            SetF(fa, "m_AtlasPopulationMode", AtlasPopulationMode.Static);

            var ctor = typeof(TMP_Character).GetConstructor(new[] { typeof(uint), typeof(UGlyph) });
            if (ctor == null) { Plugin.Log.LogError("[FB] TMP_Character ctor missing"); return null; }
            var charTable = new List<TMP_Character>();
            for (int i = 0; i < glyphs.Count; i++)
                charTable.Add((TMP_Character)ctor.Invoke(new object[] { pairs[i].Key, glyphs[i] }));

            SetF(fa, "m_GlyphTable", glyphs);
            SetF(fa, "m_CharacterTable", charTable);
            SetF(fa, "m_FontFeatureTable", new TMP_FontFeatureTable());
            SetF(fa, "m_KerningTable", new KerningTable());

            try { fa.ReadFontAssetDefinition(); }
            catch (Exception e) { Plugin.Log.LogError("[FB] read def: " + e.Message); }

            Plugin.Log.LogInfo("[FB] built: chars=" + (fa.characterTable == null ? -1 : fa.characterTable.Count) + " has(zhu)=" + fa.HasCharacter('\u732a'));
            return fa;
        }
    }

    [HarmonyPatch(typeof(TMP_Text), "set_text")]
    internal static class PatchTmpSetText
    {
        static void Prefix(ref string value, TMP_Text __instance)
        {
            if (string.IsNullOrEmpty(value)) return;
            Plugin.Note(value);
            if (Plugin.Dict == null) return;
            string zh;
            if (Plugin.TryLookup(value, out zh))
            {
                value = zh;
                Plugin.MarkWritten(zh);
            }
        }
    }

    [HarmonyPatch(typeof(UnityEngine.UI.Text), "set_text")]
    internal static class PatchUiSetText
    {
        static void Prefix(ref string value)
        {
            if (string.IsNullOrEmpty(value)) return;
            Plugin.Note(value);
            if (Plugin.Dict == null) return;
            string zh;
            if (Plugin.TryLookup(value, out zh)) { value = zh; Plugin.MarkWritten(zh); }
        }
    }

    // Pooled prefabs (shop icons, loadout slots, objective rows) are filled through
    // TMP_Text.SetText(), which does not go through the text property setter.
    [HarmonyPatch(typeof(TMP_Text), "SetText", new Type[] { typeof(string), typeof(bool) })]
    internal static class PatchTmpSetTextB
    {
        static void Prefix(ref string sourceText)
        {
            if (string.IsNullOrEmpty(sourceText)) return;
            if (Plugin.Dict == null) return;
            string zh;
            if (Plugin.TryLookup(sourceText, out zh)) { sourceText = zh; Plugin.MarkWritten(zh); }
        }
    }
}

