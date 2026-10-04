# 野区河道连通版验证 · 2026-09-19

> 历史归档：正文只描述当时版本，旧“当前/下一步/待验证”不再授权执行。现行规则与进展从[文档入口](../../README.md)读取。

工作项：WS-MAINT-20260919-002。证据类型为 **SIMULATED**；真人研究 **OPTIONAL_NOT_RUN**，性能门 **DEFERRED_D028**。

本轮新增北侧 S → L → 河道 → S、南侧 S → 河道 → L → S 两条道路，宽320；南侧由北侧精确旋转180°生成，沿用512宽河道。地图保持32768×24576、26个据点和双方256人口上限。六个野区点的双向战略邻接同步更新。

| 验证 | 结果 | 证据 |
|---|---|---|
| 地图全格旋转对称、节点可达与两侧距离 | PASS | `artifacts/jungle-links-map01.log` |
| 两条道路逐段直通、道路宽度采样、双向据点邻接与上下河道转场 | PASS | `artifacts/jungle-links-focused01.log` |
| 从实际资源生成地图总览 | PASS | `artifacts/jungle-links-render01.log` |
| 实际会战南北交汇渲染及小地图 | PASS | `artifacts/jungle-links-visual02.log`，`jungle-links-north-game.png`、`jungle-links-south-game.png` |
| 完整发布门 | PASS，1058.904秒、退出0 | `artifacts/jungle-links-release01.log` |
| 实际EXE菜单、编成、会战、暂停、缩放、南北小地图定位 | PASS | `artifacts/jungle-links-package-visible.log`，`jungle-links-package-north.png`、`jungle-links-package-south.png` |
| ZIP独立解压与逐文件SHA-256 | 以交付回执为准 | `artifacts/jungle-links-delivery-package.json` |

总览用金色强调本轮新路、蓝色强调河道；实战沿用当前道路纹理。初次导入退出0但有Android EditorSettings关闭期错误，不用作干净导入证据。第一轮视觉夹具因相机属性错误中止，修正夹具后第二轮通过；未修改运行时代码。

本版保留前一版军团告警、战区医院、导弹反馈、性格招募偏好、临时微操、新兵10秒绿圈和每秒补员方案。其行为专项证据见WS-MAINT-20260919-001。本轮地图变更后的总体胜率、完整自然局时长和真人体验尚未测定，不沿用旧地图自然对局结果作为新路线的平衡结论。存档仍为v4；旧交付包保留。

完整门包括两轮18套测试、四关策略矩阵、30场确定性重复整局、72案例汇总、五档反馈UI、反馈工具、Windows导出与包检查。无SCRIPT ERROR/ERROR；历史截图UID重复警告仍保留，不宣称无警告。669个运行文件与验证冻结清单完全一致。PCK SHA-256：`5A781414DF7198C39DC94F5CB60CD5797683939648571538FB22AF2F467950B7`。
