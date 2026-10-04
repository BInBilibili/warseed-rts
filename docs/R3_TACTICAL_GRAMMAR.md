# R3 战术效果契约准备

初始日期：2026-09-10；范围复核：2026-09-21。R3 已完成并接受，D-021/D-022 均已接受。本文保留 typed 战术语法与执行器契约；历史任务和验收保存在 `archive/work_items/`，后文实现步骤是历史说明，不再授权领取 R3 任务。实时任务见[开发状态](AI_DEVELOPMENT_STATE.md)。

## 首条路径

R3-001 先交付加载时可校验的受限语法，R3-002 再把现有“交替掩护”的分批出发接入执行器。首条路径保持既有行为：将领下达任务后，按已部署下属卡的稳定顺序，每后一张延迟 20 tick；首卡不额外等待。玩家接管、任务取消及重新下令仍使用已有任务生命周期和统一命令管线。

迁移前的三处 `alternating_cover` 名称分支位于 `SimulationWorld._assign_unit_card_task`、`_apply_task_feedback_to_commander`、`_commander_doctrine_reason_key`。R3-002 已将其替换为 `DoctrineEffectRegistry` 返回的任务参数和原因；`StrategicTaskSystem` 继续按 activation tick 处理等待。世界类只保留旧静态资源映射，不再按该战法 ID 执行动作。

## 数据形状

`DoctrineDefinition.effects` 使用 `Array[DoctrineEffectDefinition]`。每项必须有稳定 `effect_id`，以及以下七个非空 typed Resource；内容不得携带脚本路径、表达式或任意参数字典。

| 子资源 | 首条受支持语义 | 验证边界 |
|---|---|---|
| Trigger | 将领整卡任务建立 | 枚举必须已支持；不允许任意事件名 |
| Selector | 该将领已部署、允许接受此次任务的整卡 | 不选敌军、不读取隐藏信息；玩家接管/归队中的卡不重建任务 |
| Effect | 分批出发 | 按 kind 分发到代码注册器，不按战法名称分发 |
| Cost | 后续卡延迟到达 | 代价由 Timing 决定，不虚构 Supply 消耗 |
| Timing | 基础延迟加部署顺序乘间隔 | 整数 tick、非负基础延迟、正间隔、有限上界；不支持重复触发 |
| Counterplay | 利用先后出发造成的局部兵力空窗 | 必需解释 key；玩家接管或任务替换按已有生命周期终止执行 |
| Reason | 等待原因和动作/代价说明 | 非空本地化稳定 key，不能执行表达式；首条复用既有中英文说明 |

尚无执行器的 kind 必须拒绝，不能仅靠枚举占位宣称可用。后续每个新动词在同一工作项扩展语法、校验、执行、观测与对照测试。旧扩充规格 4.5 中 `parameters: Dictionary` 是历史提案，当前以 D-027 玩法路线的七类 typed Resource 要求为准。

## 加载、兼容和失败

旧战法的空 effects 数组保持兼容。非空数组中的空项、重复 effect ID、未知 kind、缺子资源、非法时序、空说明 key 和不支持的组合均生成有字段路径的 `DataValidationResult`，经 `BattleDefinition.validate` 和 `BattleContentLoader` 阻止无效内容启动。校验不修改原 Resource。

R3-001 仅验证语法，正式十二张战法保持原行为；测试 fixture 覆盖 `.tres` 往返加载和无效内容。R3-002 单独迁移交替掩护，证明更改战法稳定 ID 不改变效果分发，更改 timing 会改变实际 activation tick；未迁移战法保留原兼容路径。

首条执行器只返回类型化任务参数和值拷贝原因信息。权威世界负责应用，UI 和 Agent 不直接写世界。出发序号仍按将领全部已部署卡的稳定 ID 顺序计算，即使其中一张被玩家接管也不压缩其他卡的序号。应用顺序固定，现有“交替掩护优先于火力准备”的组合优先级须由黄金测试约束。新效果元数据不参与旧 gameplay fingerprint 的组成，等价迁移不应改变战斗结果。

## 验证准备

R3-001：有效/无效语法、重复 ID、空引用、枚举越界、时序边界、说明 key、typed Resource 序列化、四关加载、完整回归。没有权威行为或存档变化时不要求为纯语法再运行完整发布门。

R3-002 历史验收：旧交替掩护的任务时间、单卡/多卡、玩家接管、同 tick 改令、装备顺序、等待原因、值拷贝和隐藏知识污染对照；完整回归、四关 smoke、完整策略矩阵、80 实体及完整发布门。后续 R3 工作项也已完成。

D-021 编制与存档决定已于 2026-09-10 接受，D-022 战斗维度决定已于 2026-09-11 接受；原入口审查见[历史记录](archive/reports/R3_ENTRY_REVIEW.md)。
