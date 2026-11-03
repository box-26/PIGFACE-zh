# 第三方组件与许可

本项目的**源码仓库不包含**下列二进制，但**发行包**里包含，因此在此声明。

## BepInEx 5.4.23.2 (x64)

- 用途：Unity Mono 游戏的插件加载器，提供 `winhttp.dll` 注入与 Harmony 补丁能力。
- 来源：https://github.com/BepInEx/BepInEx
- 许可：LGPL-2.1（部分组件为 MIT）
- 发行包内包含：`winhttp.dll`、`doorstop_config.ini`、`.doorstop_version`、`BepInEx/core/*`
- LGPL 义务：允许再分发，须附许可证并注明来源。原始许可证文本随包提供，
  见 `BepInEx/core` 同目录的说明；完整文本见上游仓库 `LICENSE`。
- 本项目未修改 BepInEx 的任何源文件。

## Noto Sans CJK SC（思源黑体）子集

- 用途：当系统没有中文字体时，作为内置回退字体，避免显示方块。
- 来源：https://github.com/notofonts/noto-cjk
- 许可：SIL Open Font License 1.1
- 发行包内为**子集化后的 `font.ttf`**（仅包含词库实际用到的约 1200 个字符），
  由 `tools/make_font.py` 生成。
- OFL 义务：允许再分发与修改（子集化属于修改），须保留版权声明与许可证文本；
  `OFL.txt` 随包提供，不得删除。

## 未包含的游戏素材

本项目**不包含**任何来自《PIGFACE》的文件（exe、dll、data.unity3d、贴图、音频、字体原件）。
运行时替换所用的文字、字体与界面贴图，均为本项目自行生成或取自系统/开源字体。

`SOLD OUT` 徽标是游戏内的一张 256×128 贴图。本项目在**内存中**用一张自行绘制的
同尺寸图片替换它（`tools/make_sold.py` 可重新生成），不修改、也不再分发原图。
