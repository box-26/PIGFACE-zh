# 发版流程

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
