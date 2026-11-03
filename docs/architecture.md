# 工作原理

## 为什么选运行时替换，而不是改包

静态改包（把 `data.unity3d` 解出来、改文本、再打回去）的问题：

1. 这个游戏的 MonoBehaviour 类型树被剥离了大半（22991 个里 22894 个读不出字段），
   要改文本得先现生成类型树再回写，容易崩。
2. `data.unity3d` 有 133 MB，改一次就是重新分发整个包，Steam 一更新全部失效。
3. 字体图集是烘焙好的，静态改就得重制图集，需要 Unity 编辑器。

运行时替换的代价是“中文晚 0.2–1 秒出现”，收益是：不动任何游戏文件、可随时卸载、
只发 1 MB 左右的包。

## 三个组成部分

### 1. 文本替换

Harmony 在 `TMP_Text.set_text` / `TMP_Text.SetText` / `UI.Text.set_text` 上打 Prefix，
把英文换中文；同时有一个定时扫描兜底，处理“直接改字段、不调用 setter”的情况。

`TryLookup()` 的顺序（改动顺序会引发连锁问题）：

1. 精确匹配词库（`Norm` 之后）
2. `<br><br>` 拆分：道具面板是“名称 + 空行 + 描述”运行时拼的，两半分别查
3. 手机面板：`面具：SMILER` 这种，标签已是中文，只翻冒号后面的值
4. 目标行：剥 `»` / `>>` / `(optional)` / `(0/3)`，翻核心句，再把标记接回去
5. 奖励行：`+4 adhesive`、`- electrical scrap x10`，游戏加的数量，只翻物品名
6. 长句保护：≥6 个英文单词、无标记、非目标行时**放弃片段替换**，整句留英文
   （否则会拼出 “the 郊区” 这种四不像），同时写进 `miss.log`
7. 片段替换：`dmg: ` → `伤害： ` 这类
8. 前缀匹配：`Hammer (x1)`、`hammer - $10`

`Norm()` 做的归一化：转小写、空白折叠成一个空格、字面量 `\n` 与真换行等价。

### 2. 中文字体

Unity 的 `TMP_FontAsset.CreateFontAsset()` 在这个项目里**一定失败**：
它内部调用 `FontEngine.LoadFontFace(Font)`，而游戏运行时传入的 `Font` 对象一律返回
`Invalid_File`。

可行的路是用**字体文件路径**加载：

```
FontEngine.InitializeFontEngine()
FontEngine.LoadFontFace(@"C:\Windows\Fonts\simhei.ttf", 90, 0)   // 成功
FontEngine.GetFaceInfo()
逐字 TryGetGlyphIndex → TryGetGlyphWithIndexValue
自己按格子排版 glyphRect
反射调用 internal FontEngine.RenderGlyphsToTexture(...)
ScriptableObject.CreateInstance<TMP_FontAsset>()，反射塞私有字段
ReadFontAssetDefinition()
```

**关键坑**：`RenderGlyphsToTexture` 会把每个格子四周的 padding 填成 **128（中灰）**，
不是 0。TMP 在 quad 边缘做双线性过滤时采到 0 与 128 的混合值 ≈ 0.5，
就会在每个汉字外画出一个半透明方框（表现为绿框/白框）。

修法：渲染完取出 raw 字节，把每格“字形矩形之外”的像素清零，再
`LoadRawTextureData` + `Apply(false, false)`。

### 3. 界面贴图

只有一处：商店的 `SOLD OUT` 是他的贴图（`sold_out_DONOTUSE`，256×128，DXT5，
不可读）。运行时按名字找到 `RawImage.texture` / `Image.sprite.texture` /
`Renderer` 材质的 `_MainTex` 换成同尺寸的自绘图片，并沿用原 sprite 的
pivot / pixelsPerUnit / border，避免缩放错位。

## 为什么有两个写入方（闪烁问题）

手机面板的 `Cellphone.Update` 每帧重写原文。如果补丁的 setter 钩子和定时扫描
同时写同一个组件，两边输出略有差异就会“跳”。用 `Written` 集合记录“已翻译过的
译文”，扫描时跳过，保证同一组件只有一个写入方。

## 已知边界

- 过场字幕、成就提示等**运行时拼接**的文本可能漏；漏的会进 `miss.log`。
- 游戏大更新（换引擎、转 IL2CPP）会整体失效，需要重新适配。
- 与其它 BepInEx 插件共存未验证；安装脚本检测到别人的 Mod 会中止。
