# 发版流程

## 0. 日常维护：补漏词（不需要会编程）

玩的时候看到英文，**不用截图、不用记位置**——插件会自动把没翻成功的句子写进
`BepInEx\PigfaceCN\miss.log`。

玩完（或者攒几次）之后：

1. 双击 `1-收集漏词.bat`
   → 读 `miss.log`，剔除已翻译的、人名（`dict/allow.txt`）、版本号/分辨率/`SSAO` 这类技术串，
   生成 `待翻译.tsv`（`编号 / 英文原文 / 出现位置 / 译文`，可用 Excel 或记事本打开）。
2. 在 `待翻译.tsv` 第 4 列填中文，保存。
3. 双击 `2-应用译文.bat`
   → 把填好的行写回 `dict/zh_master.tsv`，重建 `out/zh.tsv`、`out/frag.tsv`，
   跑词库检查与**字体覆盖检查**。

如果字体检查报 `MISSING ...`，说明新译文里有字体中没有的字，按提示重建字体（第 3 步）。

`1-收集漏词.bat` 可以重复跑：已有的行、你已经填过的译文都会保留，只追加新的。

## 1. 准备词库

```
python tools/check.py            # 0 error 才继续
python tools/build_dict.py       # 生成 out/zh.tsv、out/frag.tsv
```

## 2. 编译插件

```
dotnet build src/PigfaceCN.csproj -c Release
```

产物：`src/bin/Release/PigfaceCN.dll`。

## 3. 生成内置字体（可选，词库字符变了才需要）

```
python tools/make_font.py --font "path/to/NotoSansCJKsc-Regular.otf" --out font.ttf
```

脚本会扫 `out/zh.tsv` + `out/frag.tsv` 里出现的所有字符，用 fontTools 子集化，
输出约 470 KB 的 `font.ttf`。需要 `pip install fonttools`。

## 4. 生成 `SOLD OUT` 替换图（一般不用重做）

```
python tools/make_sold.py --out sold.png
```

红条位置、字高按原图量出来的（x 21–231、y 34–91，字高 30px）。

## 5. 组装发行包

```
packaging/
  安装汉化.bat  卸载汉化.bat  检查缺词.bat
  install.ps1  uninstall.ps1  check_missing.ps1
  使用说明.txt
  winhttp.dll  doorstop_config.ini  .doorstop_version   (BepInEx 5.4.23.2 x64)
  BepInEx/core/*                                         (同上)
  BepInEx/plugins/PigfaceCN/
      PigfaceCN.dll  zh.tsv  frag.tsv  sold.png  font.ttf  OFL.txt
```

压缩成 `PIGFACE-汉化-vX.Y.zip`，解压后目录里直接是 `安装汉化.bat`（不要多一层文件夹）。

## 6. 自检清单

- [ ] 解压到干净目录，跑 `install.ps1 -TargetPath <测试副本>`，日志出现
      `dict loaded` / `frag loaded` / `font:` / `harmony patched ok`
- [ ] 跑 `uninstall.ps1`，`BepInEx` 被移走，游戏能正常启动
- [ ] `zh.tsv` 行数与 `check.py` 统计一致
- [ ] 包里没有 `seen.txt` / `miss.log` / `dump_*` / `*.pdb` / 个人路径
- [ ] DLL 里搜不到 `AI-Workspace`、`.pdb`、`C:\Users\`
- [ ] 起游戏看一眼主菜单、选项、商店、世界地图

## 7. 发布

- GitHub Release 上传 zip，标题写 `vX.Y`，正文写“改了什么 / 已知问题”。
- 同步更新 `CHANGELOG.md`。
