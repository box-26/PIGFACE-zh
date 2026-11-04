# 开发说明（给接手维护的人）

这个补丁是**运行时替换**：不修改游戏任何文件，只在内存里把英文文本换成中文、把中文画到屏幕上。

如果你要改译文或加功能，只需要看这一页。

---

## 一、环境

- .NET SDK 7.0（`dotnet --version` 能看到 7.x）
- Python 3.11+（只有改词库/字体时才用）
- 游戏本体（Steam AppID `3341650`）

编译只需要引用游戏目录 `Pigface_Data\Managed` 下的 Unity 程序集，`src/PigfaceCN.csproj` 里已经写好了。

---

## 二、两种构建

调试代码全部包在 `#if PIGFACE_DEBUG ... #endif` 里，**发布版编译时整段消失**。

```bash
# 调试版：带 F7 / F8 / F9
dotnet build src/PigfaceCN.csproj -c Release -p:DefineConstants=PIGFACE_DEBUG -o out-debug

# 发布版：不含任何调试代码
dotnet build src/PigfaceCN.csproj -c Release -o out-release
```

**为什么要用 `#if` 而不是一个开关文件？**
开关会被误开、会被玩家改；`#if` 是编译期就不存在的代码。发版前扫一下发布 DLL，搜不到 `CompleteObjectives`、`DumpObjectives` 才算干净：

```powershell
$s = [Text.Encoding]::ASCII.GetString([IO.File]::ReadAllBytes('out-release\PigfaceCN.dll'))
$s.Contains('CompleteObjectives')   # 必须是 False
```

---

## 三、调试键

| 键 | 作用 | 改不改游戏状态 |
|---|---|---|
| `F9` | 导出当前场景所有文本组件（路径 / 文本 / 字体 / 颜色 / 材质参数）+ 截图 | 不改 |
| `F8` | 导出当前关卡任务目标清单 | 不改 |
| `F7` | 调用 `Objective.ObjectiveCompleted()` 完成当前关卡所有目标，再让 `ObjectiveManager.CheckCompletion()` 复核 | **改** |

`F7` 的用途是快速跳到结算、看每关的过场与结算提示，以收集译文。**不要在日常存档上用。**

这三个键依赖反射访问 `Assembly-CSharp` 里的 `Objective` / `ObjectiveManager`，游戏大改后可能失效；失效只是按键没反应，不影响翻译本身。

---

## 四、改译文（最常见）

1. 改 `dict/zh_master.tsv`（两列：英文原文 `\t` 中文译文，值里的换行写成字面量 `\n`）
2. `python tools/build_dict.py` → 生成 `out/zh.tsv`、`out/frag.tsv`
3. `python tools/check.py` → 必须 0 error
4. 把 `out/zh.tsv`、`out/frag.tsv` 拷进游戏 `BepInEx\plugins\PigfaceCN\`
5. 启动游戏，看 `LogOutput.log` 里 `dict loaded: N`

**加了新汉字**时还要重烘字体，否则显示方块：

```bash
python tools/make_font.py --font <思源黑体.otf> --out out/font.ttf
python tools/check_font.py
```

> 字体是**子集**，只包含词库里出现过的字。这是为了让体积从 16 MB 降到 470 KB，代价是词库与字体必须同步更新。

---

## 五、运行时翻译的顺序

`TryLookup()` 依次尝试（命中即返回）：

1. 精确匹配（先过 `Norm`：小写、空白合并、字面量 `\n` 归一）
2. `<br><br>` 拆成"名称 + 描述"两半分别翻
3. 目标行：剥 `»` / `>>` 前缀、剥 `(optional)`、剥 `(n/m)` 计数，翻中间，再把前后拼回
4. 带计数物品：`bear trap (x13)`
5. 解锁提示：`+ xxx blueprint unlocked!`
6. 拾取提示：`100 LMG ammo picked up`
7. 片段替换（`frag.tsv`，只对不含 6 个以上英文单词的长句生效，防止出现"半中半英"）
8. 前缀匹配（`Hammer (x1)` 这类带后缀的物品名）

改规则要动 `src/Plugin.cs`，改词只动 `tsv`。详细原理见 [`architecture.md`](architecture.md)。

---

## 六、发版前自检

1. `check.py` → 0 error
2. `check_font.py` → OK
3. 编译**不带** `PIGFACE_DEBUG` 的发布版
4. 扫发布 DLL，确认无调试符号
5. `tools/pack_release.ps1` 打包（自动剔除 `miss.log`、`seen.txt`、`game_path.txt`、`缺词报告.txt`、`*.pdb`、`dump_*`）
6. 解压到干净副本 → 安装 → 启动 → 日志 `dict loaded` 数字正确、`harmony patched ok`
7. 卸载 → 确认 `BepInEx` 被移走
8. 才上传

---

## 七、想更快定位问题？

玩家侧只需要 `缺词报告.txt`（`检查缺词.bat` 生成，读的是 `miss.log`，零误报）。

开发侧可以自己做一个"本地调试工具包"，里面有：

- `PigfaceCN-dev.dll`（调试版）
- 全解锁存档（快速跳到任意关卡验收集中的文案）
- `switch_build.ps1`（在调试版/发布版之间切换）

**这些东西只留本地，不要提交到仓库、不要放进 Release。** 一个"按 F7 就能跳关"的 DLL 出现在公开仓库里，会被当成外挂。

---

## 八、授权

- 代码：MIT
- 译文与文档：CC BY-NC-SA 4.0

也就是说：代码随便用、可以商用；译文可以改、可以再发布，但不能拿去卖。
