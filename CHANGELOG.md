## v1.8
- 修复：修改游戏键位后，按键提示（含手柄图标）变回英文。现在把 `<sprite ...>` 折叠成占位符再查表，键位怎么改都能命中
- 安装器/卸载器重写查找逻辑：只找到一份直接安装（不再弹选择框）；找到多份时 Steam 库里的优先，真正并列才让你选；上次装过的路径优先
- 引号统一：游戏内译文与全部文档改用中文引号 `“ ”`（此前混用日式 `「 」`）
- `缺词报告.txt` 的说明文字改为与实际行为一致，并注明仍可能有少量误报
- `使用说明.txt`：补杀软兼容性实测记录、转载时保留项目链接的要求、盗版不支持的说明
- 版本号 1.8.0

## v1.7
- 过场字幕补译：`Uh-huh.`→嗯哼。、`'course.`→当然。、`Affirmative.`→收到。、`Hmph.`→哼。、`What?`→什么？
- 拾取提示通用规则：`100 LMG ammo picked up` → `捡起 LMG 弹药 ×100`（数字+物品名任意组合）
- 漏翻提示（解锁类）通用规则：`+ bear traps blueprint unlocked!` → `+ 已解锁捕兽夹蓝图！`；`+` 可选，兼容 `morphine blueprint unlocked!`
- 结算/toast：`birthday_girl mask found!` → `生日女孩面具已找到！`（新增“面具已找到”通用规则）
- 多词物品名带计数：`bear trap (x13)`、`morphine (x6)`
- 关卡任务提示：`warehouse job accepted` → `仓库：任务已接受`
- 补 `empty`、`Good.`、`Caesar?`、`Sample came back.`、`Yes sir.` 等词条；`捕熊夹` 统一为 `捕兽夹`
- 译名统一：`Exit` → `艾柯赛特`（主角代号，Steam 商店页译法）、`断路开关/断电阀` → `断路器`、`邦邦/蹦蹦` → `糖果`、组织名统一加“帮”
- 引号：游戏内统一 `“”`，游戏外文档 `“”`；同名专名只在首次出现时加
- 售罄贴图：运行时按原图尺寸自适应缩放，避免更新后错位
- 检查缺词.bat 改为读 miss.log 生成“缺词报告.txt”（零误报），输出到补丁文件夹并打印路径（不自动打开窗口）
- 报告头带补丁版本 / 词库条数 / Steam buildid / 生成时间；游戏路径只记三个是/否（含中文、含空格、在 Program Files），不写完整路径
- 报告修正：分辨率改用 `Win32_VideoController`（不再受 DPI 缩放影响）、杀软按程序文件是否还存在过滤已卸载项
- 免责声明新增：部分译名参考 Steam 商店页面的既有译法

# CHANGELOG

- 20261104-020351  (no note)
- 20261104-005726  dictionaries rebuilt from master (938/131), deployed to working copy + release
- 20261104-005657  v1.3 baseline: 938 dict entries, 131 frag rules, font fallback chain, installer self-check