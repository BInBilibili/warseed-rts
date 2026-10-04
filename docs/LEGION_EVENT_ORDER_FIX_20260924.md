# 军团事件顺序修复与复验

> 终态更新：55194已实际退出0，两次18000tick自然终局450262项零失败，独立全量事件/采样/账目审计通过。完整门与全部适用专项核对后A DONE，新回执[verification-final.json](../artifacts/legion39/verification-final.json)。下文运行过程和前缀记录保留，不能覆盖本终态；B/C/D与完整目标仍未完成。

工作项`WS-MAINT-20260920-001`，legion39，A固定编制/成长的确定性返工。完整A–D范围保留，B正式接入仍依赖A验收。上一轮为有效进展：行军候选验证通过、自然长局失败定位到战术卡顺序，本轮开始正式修复，不重新启动已终止的22908。

## 契约

目标：同一输入在同进程多次开局时，战术完成、中断、识别处理使用稳定卡ID的文本顺序，不受StringName分配顺序影响。现有两次18000tick账目与成长相同但事件指纹不同；600tick诊断复现361/441/541tick双侧侦察卡事件交换，原始失败保留在legion36/38。

输入、命令校验、费用、组织、权限和合法知识保持原规则；只修复`TacticalAbilitySystem.advance/cancel_for_order/update_identification`中卡ID排序，不排序最终日志来掩盖执行差异。整数阵营ID排序保持整数语义。没有磁盘格式变化，v4无迁移；UI继续消费原快照，事件类型及原因键不变。未知敌情不得进入战术处理。

验收：正式系统同输入600tick事件逐条相同；顺序相关中断与识别检查；原18套、旧四关、知识/v4/UI/导出完整门；新冻结版本两次自然终局的完整事件、资金/出生、里程碑和采样一致。日志与实际退出码都要检查。HUMAN和像素仍NOT_RUN，性能按D-028。原legion36/38冻结和回执只证明历史版本，不覆写。

范围外：队速/四态/通行正式接线、武器/角色/地图数值、收入、控制权、R6/R7及对外发行包。模拟准备可以继续，但不能将未通过A的正式B功能混入受验版本。

状态路径：REWORK→IMPLEMENTING→VERIFYING→REVIEWING；只有完整要求有证据才DONE。新原始日志、冻结及审计统一写`artifacts/legion39/`。命令使用现有Godot4.6.3 mono console的`--headless --path . --script`，完整门使用`tools/verify_grey_ridge_release.ps1`并指定隔离导出路径；进程未结束不标通过，超时不重启。

## 当前实测证据

- 修复前600tick正式世界两次各1311事件，361tick完成事件、441tick完成事件和541tick中断事件交换；`event-before.json/log`，会话86612退出1。只改变三处处理排序后，同脚本同输入1311事件逐项一致，`event-after.json/log`，67771退出0。
- `tests/unit/test_tactical_cards.gd`新增多卡同tick完成、重叠光学观察唯一归属、将领命令同时取消的稳定文本序检查，并分别使用正反插入顺序。原战术套件及新增用例`tests/tools/legion39_tactical_contract.gd`通过，`tactical01.log`无脚本错误、退出0；完整门再次运行该测试。
- 新版本完整门13016已退出0，**1251.738秒PASS**，日志`artifacts/legion39/release01.log`，终态`release-terminal.json`。包含两轮18套、四关/完整局矩阵、知识/v4、UI、工具、导出及隔离包运行。隔离导出在`build/verification-legion39/`，未替换对外发行包。PCK SHA256为`33f0b0fafecac9090b5a54ef9c70218af749f2866fac20d57c4123b57e7b7217`。
- `runtime-freeze.json`冻结687运行文件；与legion36只差`tactical_ability_system.gd`，本轮生产补丁单独保存在`production.patch`。旧A编制/成长/UI证据只复用未变部分，不据旧自然长局宣布确定性已修复。
- 自然观察会话55194继续运行同一进程，`natural01.log`逐1000tick记录进度。观察器保留原出生/账目/里程碑断言，并新增每次advance_tick的事件摘要、每100tick单位位置/HP/弹药/目标/路径等物理状态摘要和原始`events0/1.jsonl`。同tick事件不能按最终日志排序；严格逐条和逐次advance_tick比较。全部终局前A保持VERIFYING。

独立审计`python artifacts/legion39/verify_natural.py`要求两次终局及全部事件/状态/账目一致，`--first-only`只审计首局。世界在current_tick递增前后都会产生事件，因此审计按记录的advance_tick分块摘要还原事件流，不误用事件自身tick作为唯一分块边界。HUMAN与原生像素NOT_RUN，B/C/D完整实现和战术缺口未取消。

2026-09-24首局进展：18000tick/30分钟平局，1549出生（480首次成长、1069补亡）、每方首次成长702，十团分别曾达到60人，非同时满员。234717条事件、180个物理状态采样；`verify_natural.py --first-only`已通过，`natural0-audit.json`保存独立账目与分块核对。首局事件SHA256为`0c0859367dec0696e9ba7bab8f19cd971412b755b6e72694fb72ed68a9481da6`。第二局55194继续；`audit_event_prefix.py`只比较完整落盘行，已见134710条事件至10838tick一致，不能把运行前缀当作终局重放通过。生命周期归队标志也不证明B/C战术已就绪，A继续VERIFYING。

最终两局：各18000tick权威平局、1549出生、234717事件、180个物理状态采样；完整事件SHA256、每tick分块、账本、成长/补亡、里程碑和经济采样一致。蓝方开局24+入账2764−招募2256−其他净流出232=期末300；红方24+3717−2048−支援1260−其他净流出213=220，每方首次成长仍为702。自然进程结束后记录`natural-terminal.json`，严格自然审计与`verify_final.py`均退出0。旧完整门回执中的`natural_status=RUNNING`仅是该门结束时的历史状态，不修改旧回执；最终状态由新A回执决定。父维护及完整目标继续REWORK/active，默认30分钟平局的节奏风险仍保留。
