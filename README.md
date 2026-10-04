# WARSEED

即时战术游戏：玩家决定方向、目标、资源和预备队，将领组织真实部队执行任务，必要时玩家临时接管整张部队卡。

当前包含旧四场卡牌会战与“最终决战”大地图。最终决战为三路、两片野区、五兵团，每方开局 60 名士兵加 5 名将领，双方满编共 610 个战斗实体。

## 当前进度

R5 出口已接受，R6/R7 未开始。大地图五兵团、炮车修订、将领实体与移动随军修复已交付；`WS-MAINT-20260920-001` 的整体性能和对局节奏目标仍为 `REWORK`。固定编制、专属兵种、四态阵型和新的玩家/AI 权限仍是设计提案。

最新记录交付：`build/playable/WARSEED-Movement-Escort-20260921.zip`，见[交付证据](docs/MOVEMENT_AND_ESCORT_FIX_20260921.md)。ZIP SHA256：`B0D00A1914737D203015DB6A04DAC05D48F9F4B738342679D97E9FCA114DCDD6`。2026-09-22 文档复核时，本地该 ZIP 路径不存在；保留历史交付信息，不提供失效下载链接。

该版本完整发布门通过；大地图随军观察仅运行到 6000 tick，不代表完整对局或所有编队问题已解决。性能为无窗口 CPU 数据，不能外推实机帧率。证据为 `SIMULATED`，真人研究可选且未完成。本轮文档整理未重新生成或改写运行包。

## 文档

- [文档入口](docs/README.md)：现行规则、工程契约、待讨论提案和历史归档。
- [当前玩法](docs/CURRENT_GAMEPLAY.md)：地图、数值、经济、控制权和已知限制。
- [开发状态](docs/AI_DEVELOPMENT_STATE.md)：活动任务、证据与下一步。
- [五兵团改进提案](docs/LEGION_GAMEPLAY_PROPOSAL_20260921.md)：围绕原操作目标重新整理的建议，尚未实现。
- [开发约定](AGENTS.md)、[开发流程](docs/AI_DEVELOPMENT_WORKFLOW.md)、[决策记录](docs/DECISIONS.md)。

## 开发与验证

当前源码使用 Godot 4.6.3 .NET 版、typed GDScript 和 .NET 8 C# 表现计算内核。开发需要对应 Godot .NET 编辑器与 .NET 8 SDK；已交付 Windows 包自带运行时，运行包不要求安装开发 SDK。

```powershell
dotnet build WARSEED.csproj
powershell -ExecutionPolicy Bypass -File .\tools\verify_grey_ridge_release.ps1 -GodotConsolePath <godot-mono-console>
```

完整门的适用条件见开发流程。D-028 暂缓性能通过要求，功能、确定性、公平知识、存档、UI 与导出验证仍保留。纯文档变更检查内容、链接与 `git diff --check`。

旧 `build_playable_package.ps1` 仍依赖历史说明模板，不应仅改包名就宣称完成当前 Mono 发行验证；实际运行时依赖与包内验收见[最新交付证据](docs/MOVEMENT_AND_ESCORT_FIX_20260921.md)。
