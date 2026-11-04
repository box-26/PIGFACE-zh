## v1.7
- 漏翻提示（解锁类）通用规则：`+ bear traps blueprint unlocked!` → `+ 已解锁捕兽夹蓝图！`；`+` 可选，兼容 `morphine blueprint unlocked!`
- 结算/toast：`birthday_girl mask found!` → `生日女孩面具已找到！`（新增「面具已找到」通用规则）
- 多词物品名带计数：`bear trap (x13)`、`morphine (x6)`
- 关卡任务提示：`warehouse job accepted` → `仓库：任务已接受`
- 补 `empty`、`Good.`、`Caesar?`、`Sample came back.`、`Yes sir.` 等词条；`捕熊夹` 统一为 `捕兽夹`
- 译名统一：`Exit` → `艾柯赛特`（主角代号，Steam 商店页译法）、`断路开关/断电阀` → `断路器`、`邦邦/蹦蹦` → `糖果`、组织名统一加「帮」
- 引号：游戏内统一 `「」`，游戏外文档 `“”`；同名专名只在首次出现时加
- 售罄贴图：运行时按原图尺寸自适应缩放，避免更新后错位
- 检查缺词.bat 改为读 miss.log 生成「缺词报告.txt」（零误报），输出到补丁文件夹并打印路径（不自动打开窗口）
- 报告头带补丁版本 / 词库条数 / Steam buildid / 生成时间；游戏路径只记三个是/否（含中文、含空格、在 Program Files），不写完整路径
- 报告修正：分辨率改用 `Win32_VideoController`（不再受 DPI 缩放影响）、杀软按程序文件是否还存在过滤已卸载项
- 免责声明新增：部分译名参考 Steam 商店页面的既有译法

# CHANGELOG

- 20261104-020351  (no note)
- 20261104-005726  dictionaries rebuilt from master (938/131), deployed to working copy + release
- 20261104-005657  v1.3 baseline: 938 dict entries, 131 frag rules, font fallback chain, installer self-check