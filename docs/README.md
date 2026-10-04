# WARSEED 文档入口

更新：2026-09-28。文档分为现行规则、开发契约、未实现提案与历史证据。日期较新的草案不会自动覆盖已接受规则。

## 当前必读

| 需要了解什么 | 入口 |
|---|---|
| 真实进展、活动任务、最新验证和交付 | [AI 开发状态](AI_DEVELOPMENT_STATE.md) |
| 当前大地图、数值、经济、操作与限制 | [现行玩法](CURRENT_GAMEPLAY.md) |
| 玩家负责什么、AI 负责什么 | [产品愿景](PRODUCT_VISION.md) |
| 当前五兵团与真实地图通行规则 | [移动修复与正式接回](LEGION_MOVEMENT_REPAIR_20260928.md)、[固定逐人增长表](LEGION_GROWTH_TABLE_20260923.md)；空间准入按D-038，旧严格阵型结果不覆盖新规则 |
| 本轮可玩版本与验收方法 | [军团移动修复试玩版](PLAYABLE_LEGION_MOVEMENT_20260928.md)，完整发布门23阶段与打包检查通过，自然整局终态见报告 |
| 阶段顺序与已接受决策 | [玩法路线](GAMEPLAY_REWORK_ROADMAP.md)、[决策记录](DECISIONS.md) |
| 当前唯一维护工作项 | [WS-MAINT-20260920-001](work_items/WS-MAINT-20260920-001.md)，整体 REWORK |

## 历史专项与证据

- [同距离成长阶段追击](LEGION_EQUAL_DISTANCE_PURSUIT_20260924.md)：100场、50镜像、20重放通过执行审计；24/48人全部失将，设计部分通过，不能只验开局与满编。

- [阵型权威接入](LEGION_FORMATION_RUNTIME_20260924.md)：legion43护将/队速/身份规划/UI专项通过，完整门及两次6667tick全量重放通过；定位护卫选择跳到8284.81外，B REWORK，士兵四态/物理交通尚未完成。

- [事件顺序正式修复](LEGION_EVENT_ORDER_FIX_20260924.md)：legion39完整门1251.738秒PASS，自然两局55194退出0，全部234717事件/状态/账目一致，A DONE。
- [稳定身份与批次准备](LEGION_STABLE_BATCH_PREPARATION_20260924.md)：两次443154项、490组成长状态通过，修复复活/回营/身份边界4类问题；legion42历史准备；legion43已接线，完整B未验收。
- [三团真实合流补验](LEGION_JUNCTION_VALIDATION_20260924.md)：16场、8镜像、8重放通过；含满编183实体、停止/恢复与出口被占，循环互锁未跑。
- [窄路动态追击补验](LEGION_PURSUIT_VALIDATION_20260924.md)：80场、40对镜像、28项重放，执行审计通过，战术部分通过；保护批次改善陆铮/狄天小团撤离，林墨/白九阳仍有失败。动态包围和正式阵型整局未验收。

- [开发流程](AI_DEVELOPMENT_WORKFLOW.md)、[目标命令](AI_GOAL_COMMANDS.md)、[分工规则](AI_AGENT_PLAYBOOK.md)、[委派模板](AI_DELEGATION_TEMPLATE.md)、[外部文本模型](AI_LOW_COST_PROVIDER.md)。
- [系统设计](SYSTEM_DESIGN.md)、[战术类型契约](R3_TACTICAL_GRAMMAR.md)、[编成与 v4 存档](R3_COMPOSITION_AND_SAVE_COMPATIBILITY.md)、[敌方行动接口](ENEMY_OPERATION_GUIDE.md)。
- [R4 出口](R4_EXIT_EVIDENCE.md)、[R5 出口](R5_EXIT_EVIDENCE.md)：已接受的阶段证据，不能直接外推到大地图。
- [炮车修订](ARTILLERY_REVISION_20260920.md)、[将领修订](COMMANDER_REWORK_20260920.md)、[性能峰值报告](PERFORMANCE_PEAKS_20260920.md)、[移动与随军修复](MOVEMENT_AND_ESCORT_FIX_20260921.md)：不同切片证据，以各自构建与采样窗口为准。
- [地图总览](FINAL_DECISION_MAP_OVERVIEW.png)：地形与连接关系仍可参考；图中旧 48/256 人数标注已过时，当前规模见现行玩法。
- [文档审计](DOCUMENTATION_AUDIT_20260921.md)。本轮候选数值与实际运行结果见[兵团实验](LEGION_BALANCE_LAB_20260922.md)。
- [固定军团原子补员](LEGION_FIXED_ROSTER_PROGRESS_20260923.md)、[共享经济进展](LEGION_ECONOMY_PROGRESS_20260923.md)：正式A已接入并验收DONE；旧legion36自然局事件重放失败保留，最新legion39排序修复通过专项、完整门及自然两局；B/C阵型与协同、D完整整合尚未验收。
- [行军护将补验](LEGION_FORMATION_VERIFICATION_20260924.md)：协调队速30/120秒重放通过，护卫路径最大227.30；后续交汇/追击见本节最新报告，侧袭与低损清点失败保留。
- [自然经济双局](LEGION_NATURAL_ECONOMY_20260924.md)：旧两局事件重放失败；新legion39两局均30分钟平局、各1549出生，全部事件/状态/账目独立核对通过。[A验收表](LEGION_FIXED_ROSTER_ACCEPTANCE_20260924.md)为DONE；[B接入](LEGION_FORMATION_INTEGRATION_20260924.md)已在legion43接入护将/队速及稳定批次规划，完整成阵通行未验收。

## 待讨论与未来参考

- [快速重整、空间压缩与移动部署预览](LEGION_RAPID_REFORMATION_20260927.md)：2026-09-27用户新原则的设计增补；局部友军移动穿透、承伤×1.5、48/40/32分档间距和玩家目标部署轮廓。明确状态/退出/停止重叠/伤害时序、五团差异与新验收矩阵；本轮仅文档，新游戏行为与模拟NOT_RUN，B仍REWORK。

- [新版阵型因素分离与损失预算](LEGION_FORMATION_FACTORS_20260924.md)：新增430场、13对重放及20组隐藏污染；白九阳转向、云岚全局压紧与组合退化已分离验证，低损清点仍不达标。实验完成，设计REWORK，正式代码未改。

- [新版阵型最终模拟报告](LEGION_FORMATION_VALIDATION_20260923.md)：[720场局部对战](LEGION_SECOND_SIMULATION_RESULTS_20260923.md)、200防守A/B、240地图组、300收列/撤退流程、36主路接替、16窄路相向。旧镜像差异已修复；通用转向压紧策略拒收，白九阳满编战损仍未达标。原契约及失败见[首轮新版模拟](LEGION_SECOND_SIMULATION_20260923.md)，不代表正式整合或完整局通过。
- [第二版兵团设计](LEGION_FORMATION_REVISION_20260923.md)、[第二版245行成长表](LEGION_GROWTH_TABLE_20260923.md)：2026-09-23候选入口，已明确保护/展开/脱离/窄路/接替与逐人成本。文档完成，后续legion34部分验证见上；下列首版对战结果不能充当本版验证。
- 文档补订明确分批后的队列长度、长窄路换向、出口容量、战备交接和成长经济用时。[legion33实现记录](LEGION_IMPLEMENTATION_20260923.md)保留A–D完整范围；A已验收，B/C战术未通过项仍须修订，不代表新版正式功能全部交付。
- [兵团玩法提案](LEGION_GAMEPLAY_PROPOSAL_20260921.md)：历史讨论入口，固定编制和专属资格已有A切片实现，最新进度以上述正式实现记录为准。
- [四态阵型初稿](COMMANDER_FORMATIONS_DRAFT_20260921.md)：保留二十种展开示例，配额和时序不是已接受参数。
- [玩家与 AI 权限草案](PLAYER_AI_CONTROL_RULES_DRAFT_20260921.md)：强攻和持续接管尚未实现；当前仍是 D-036 自动交还。
- [第一版增长表](LEGION_GROWTH_TABLE_20260922.md)、[第一版实验与结论](LEGION_BALANCE_LAB_20260922.md)、[564场逐项结果](LEGION_SIMULATION_RESULTS_20260922.md)：保留原模拟输入和失败证据。增长与行为候选已由第二版修订，原始费用704不改写为新表702；完整经济、控制权和大地图整合未验证。
- [扩充系统规格](EXPANSION_SYSTEMS_AND_CONTENT_SPEC.md)、[战役地图与叙事](CAMPAIGN_MAP_AND_NARRATIVE_BIBLE.md)：未来内容参考，不代表 R6/R7 已启动。

## 历史与工具保留

[归档入口](archive/README.md)保存旧设计、旧发布报告、45 份已完成工作项及完整 v109 状态。归档正文中的“当前”“下一项”“尚未实现”只描述当时版本。旧四关的兵种 ID、名字与存档契约不能因大地图采用新名字而删除。

以下原路径因工具引用或可选研究保留，不是当前发行或阶段门：`PLAYABLE_20260914.md`、`PLAYTEST_PACKAGE_README.md`、`PLAYTEST_PROTOCOL.md`、`P6_7_PLAYTEST_COHORT_PLAN.md`、`P6_7_FIELD_EXECUTION_CHECKLIST.md`、`FEEDBACK_SERVER_GUIDE.md`、`CURRENT_PLAYTEST_FEEDBACK_FOCUS.md`、`HUMAN_VALIDATION_TEST_PLAN.md`、`GREY_RIDGE_OPERATION_TEST_GUIDE.md`、`performance/WINDOWS_RENDER_BASELINE.md`。HUMAN 研究可选；不能把旧研究清单恢复成工程阻塞项。
