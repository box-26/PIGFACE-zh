## v1.7
- 漏翻提示（解锁类）通用规则：`+ bear traps blueprint unlocked!` → `+ 已解锁捕兽夹蓝图！`
- 多词物品名带计数：`bear trap (x13)`、`morphine (x6)`
- 关卡任务提示：`warehouse job accepted` → `仓库：任务已接受`
- 补 `empty`、`Good.` 词条；`捕熊夹` 统一为 `捕兽夹`
- 售罄贴图：运行时按原图尺寸自适应缩放，避免更新后错位
- 检查缺词.bat 改为读 miss.log 生成报告（零误报），输出到补丁文件夹并自动打开
- 报告头带补丁版本 / 词库条数 / Steam buildid / 生成时间 / 游戏路径
# CHANGELOG

- 20261104-020351  (no note)
- 20261104-005726  dictionaries rebuilt from master (938/131), deployed to working copy + release
- 20261104-005657  v1.3 baseline: 938 dict entries, 131 frag rules, font fallback chain, installer self-check
