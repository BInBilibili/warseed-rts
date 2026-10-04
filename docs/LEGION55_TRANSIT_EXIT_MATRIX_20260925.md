# legion55 新版阵型窄路出口模拟复验

日期：2026-09-25。工作范围：仅复验新版五将固定阵型在最终大地图窄路出口的实际通行、清尾、展开与原目标到达，不验证战斗胜负、成长经济或完整局。

## 结论

结果为 `SIMULATED_CANDIDATE / REWORK`。五将各取 12、24、36、48、60 人，并对每个场景执行原向和镜像，共 50 场；全部场景运行到终态，但全流程通过为 0/50。实际清尾为 48/50，未清尾的两场均为 spear 24 人（原向与镜像）。所有场景都未进入角色阵型展开，未形成连续 20 tick 的就绪状态，未产生出口完成回执，也没有士兵抵达原任务目标。

| 兵团 | 12 人清尾 | 24 人清尾 | 36 人清尾 | 48 人清尾 | 60 人清尾 | 全流程通过 |
|---|---:|---:|---:|---:|---:|---:|
| spear | 2/2 | 0/2 | 2/2 | 2/2 | 2/2 | 0/10 |
| guardian | 2/2 | 2/2 | 2/2 | 2/2 | 2/2 | 0/10 |
| gunner | 2/2 | 2/2 | 2/2 | 2/2 | 2/2 | 0/10 |
| sentinel | 2/2 | 2/2 | 2/2 | 2/2 | 2/2 | 0/10 |
| ranger | 2/2 | 2/2 | 2/2 | 2/2 | 2/2 | 0/10 |

按人数档汇总，12、36、48、60 人均 10/10 清尾，24 人为 8/10。spear 24 人两向均在清尾前停止（`TRANSIT_EXIT_CAPACITY`）；gunner 60 人虽清尾，出口规划仍报告容量不足。其余 48 场均清尾，但因角色阵位容量不足（`TRANSIT_EXIT_ROLE_CAPACITY`）停在 phase 3。所有场景 `first_expand=-1`、`wide_ready=0`、`at_destination=0`。因此，清尾只能证明尾队通过采样窄口，不能证明出口部署或任务完成。

五将每个兵力档均做了镜像比较，共 25 对。可配对清尾 tick 差最大为 3 tick；spear 24 人未清尾，不能据此推断镜像阵型完整等效。路径哈希在原向与镜像间不同，分别保留在逐场结果中。

## 方法与证据

驱动为 `python -u artifacts/legion55/run_exit_matrix.py`，每场使用 1800 tick 上限及 `tests/tools/legion55_exit_execution.gd`。候选来自 `artifacts/legion50/candidate/`。每场生成独立源码冻结、终态、原始 JSON 和控制台日志。50/50 场无脚本错误、无超时、无冻结后运行源码漂移；每场场景退出码均为 1，表示验收条件失败，不是驱动或脚本异常。合计约 90,705,204 项断言调用，包含逐 tick 重复检查，不代表同等数量的独立场景。

汇总：[matrix-summary.json](../artifacts/legion55/matrix-summary.json)；进度副本：[matrix-progress.json](../artifacts/legion55/matrix-progress.json)；驱动：[run_exit_matrix.py](../artifacts/legion55/run_exit_matrix.py)。每个 `matrix-<兵团>-<人数>-<方向>/` 目录保存 `freeze.json`、`terminal.json`、`result.json` 与 `console.log`。

## 后续

保留本候选证据，不将其接入正式主工程。后续修订应解决出口后角色阵位与通道容量冲突，同时保留中间 96 单位通行净空、24 单位实体间距与原任务目标语义；先复现 spear 24 和 gunner 60，再重跑五将五档双向矩阵。修复后仍需单独验证窄路撤退、交汇交通、战斗经济和完整局。正式整合、完整发布门及真人研究均不由本轮结果证明；`HUMAN/原生像素` 为 `NOT_RUN`，性能按 D-028。
