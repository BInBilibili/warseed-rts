# 固定军团共享经济：实现与验收进展

> 最新排序修复版本legion39已完成A验收：完整门1251.738秒PASS、自然55194退出0，两次18000tick全量事件/物理采样/账目一致，A DONE。下文legion36自然重放FAIL为历史已确认事实，不覆盖旧失败。见[排序修复](LEGION_EVENT_ORDER_FIX_20260924.md)及[A验收](LEGION_FIXED_ROSTER_ACCEPTANCE_20260924.md)。

工作项 `WS-MAINT-20260920-001`，legion36，延续A固定编制与成长。共享经济及边界修复已经接入，专项通过，完整发布门 **PASS（1234.658秒）**；自然长局事件重放失败，A为REWORK，完整A–D目标和父维护未完成。证据为SIMULATED，真实像素/键鼠与HUMAN为NOT_RUN，继续遵守仅无窗口限制。

2026-09-24更新：release01因新增55项边界中1项确认重复预留而主动终止，不计通过。第二轮入队原本覆盖第一槽的承诺记录，现保留首个已承诺身份；boundary-after06全部55项通过，经济/原子成长/自主回归重新通过。当前完整门release02、会话80957已退出0并通过，687运行文件与最终源码冻结清单一致；旧冻结另存runtime-release01-freeze.json。

## 已改变的行为

- 自动补员先分第一轮、第二轮，沿成功购买游标按稳定军团ID轮转，遵守阵营5人/固定秒、每团0–2人和玩家最低储备。
- 全阵营只有一个下一兵员费用预留，至多5补给；按等待时间、稳定ID选择。只留住真实可用余额，扣除既有命令承诺，已入队的同一费用不重复预留。玩家范围支援仍可使用软预留。
- 已选兵员身份在合法等待中保持；其他兵种新战损不使它偷偷变成便宜兵。成功、身份占用或资格失效后重新选择；未经过仲裁选择的旧手动排队仍拒绝过期身份。
- 出生拒绝保留10tick解释且暂不占资金；不安全、失去补给、配额归零、将领回营、玩家接管或低于储备时释放。每次入队后重算承诺，排空队列执行期间不重新分配软预留，整批完成后刷新。
- 玩家已接受的新补员计划/优先级取消未执行自动补员，等设置应用再申请；接管取消目标卡自动补员。取消有拒绝事件，不扣费，不在同tick重新排入。旧四关不套用这些规则。
- 军团卡与补给面板显示等待原因、预留所有者和已留/所需资金。typed状态仅向本阵营提供值快照；不改v4磁盘格式、不新增玩家兵种配比操作。

## 已验证

| 证据 | 范围 | 结果 |
|---|---|---|
| `artifacts/legion36/boundary-before.log`、`boundary-before.json` | 修复前锁槽、拒绝冷却、玩家待执行设置 | 35项中14失败，保留原件 |
| `artifacts/legion36/boundary-after06.log`、`boundary-after06.json` | 修复后上述边界，实际advance_tick批量应用、支援顺序、稳定ID/等待年龄、字典插入顺序、值副本与固定合法知识、双槽不重复预留 | 55项通过 |
| `artifacts/legion36/final_economy_contract02.log`、`economy.json` | 两侧真实五人两轮队列、3/5部分预留、释放、玩家支援、受控连续收入 | 465项通过；100次每秒+1收入重放一致 |
| `artifacts/legion36/final_recruitment_regression02.log`、`recruitment.json` | 冻结legion35原子出生专项在新源码重跑 | 5123项通过；双方480出生，每方702补给、实际610实体；非自然满编时间 |
| `artifacts/legion36/final_live_smoke02.log`、`live.json` | 两次真实自主300tick、人口/资金/逐槽角色/旧快照 | 159427断言通过，事件和最终轨迹一致；非完整局 |
| `artifacts/legion36/ui02.log`、`ui.json` | 实际ArmyBoard/SupportPanel，中英两语言×五档尺寸，17等待原因、预留消失刷新 | 201项headless结构检查通过，无像素验收声明 |
| `artifacts/legion36/content03.log`、`content.json` | 双方五将7参数开局/死亡/真实复活、侦察资格/真实占点/弹丸伤害、0组织/回营禁止占点、非法typed模板、同时损失多兵种后的真实恢复顺序 | 535项通过；恢复不解锁新槽、逐人按角色扣费 |
| `artifacts/legion36/release02.log` | 最终冻结源码完整发布门，会话80957 | PASS，1234.658秒；退出0，无脚本错误 |
| `artifacts/legion36/growth-table-verification.json` | 文档245行与typed资源、双方480条实际出生记录逐项核对 | PASS；每方无战损追加160/156/157/105/124，合计702 |

连续小额收入测试从12储备开始、100秒共收入100，真实出生34人、支出96、结余16，五团均获得成长；两次摘要 `e4cc08f2363b060d6e0da2620e862f2f358c27123db15e1171c9bde8b14ad77a`。这是受控安全与收入测试，不能称自然局消除饥饿。

自主30秒两次均138实体、双方26补给，事件/轨迹摘要 `6c8e87f2d10e2a81229d1d807b3204a7d256febc4c5f60c99a9b3cdcd27630dd`。仲裁购买顺序已改变，不要求沿用legion35的23补给和旧指纹；新两次必须一致，不能据短局宣称健康节奏。

## 失败与复测的解释

economy01–07为前轮支援夹具迭代，08为修复前仲裁版本的465项通过；08 JSON另存 `economy08.json`。本轮 import02/ boundary-after01 因GDScript布尔类型推断失败，不计通过，即使引擎退出0也拒收；明确bool后boundary-after02的原35项通过。boundary-after03的2项失败来自测试直接排序StringName使用内部次序，改用明确字典序后52项通过，生产排序未为此改变。

ui01的夹具被真实场景每帧快照发布覆盖，冻结该发布者并绑定独立合法快照后ui02通过。content01用混合int/float数组整体相等导致22项失败，改为逐字段数值检查（绝对误差小于0.00001且记录实际值）后237项通过；再补多兵种死亡恢复得到535项。没有因此调整英雄/兵种数值或降低战术验收线。

boundary-after05确认的重复预留失败保留，release01终止记录为 `release01-termination.json`。最新一次生产修复只改变同一军团多命令时的承诺身份保留；UI布局/翻译、英雄/武器/占点/模板/恢复系统未变，复用ui02与content03对应证据。经济、成长、真实自主tick受仲裁变化影响，已全部复测为02日志，不复用01代替。

## 验收边界与后续

运行源码冻结清单为 `artifacts/legion36/runtime-final-freeze.json`。legion35完整门1090.66秒PASS仅属于上一冻结版本，不替代本轮门；不重跑旧生成器覆盖旧回执。发布门运行期间只新增测试和文档，不改受验生产源码。

A验收需汇总既有固定编制/战前交换/只读配比、当前原子补员/仲裁/专属资格、快照/UI和最终源码完整门的适用证据。正式大地图完整经济对局、各阶段前线可用时刻/重复补亡成本、B阵型/通行以及C职责/接替仍未验收。legion34通用转向压紧拒收、白九阳54.2%保留未达60%继续约束B/C；不把本轮成长验证写成新版阵型平衡通过。

2026-09-24补充：[阵型因素实验](LEGION_FORMATION_FACTORS_20260924.md)独立验证转向/补位与白九阳损失预算，未修改本轮正式源码。自然经济使用 `tests/tools/legion36_natural_economy.gd` 两次默认大地图观察，逐次终局后写 `natural0.json` / `natural1.json`，结束后写 `natural.json`；会话22908已退出1，两次均到18000tick；账目/出生一致但事件指纹不同，不计完整局确定性通过。完整门终态、EXE/PCK哈希与687文件冻结核对回执为 `artifacts/legion36/release02-terminal.json`，不是更新对外发行包。

最新[自然经济首局](LEGION_NATURAL_ECONOMY_20260924.md)已到18000tick权威平局，1549次出生账本通过；双方首次成长各702，蓝/红补亡实际支出1554/1346。十将都曾达到60人，时刻见报告；不代表同时满编或新阵型战备。第二次终局的相同账目/成长已独立复核，但事件指纹不同，A进入REWORK；600tick隔离诊断已复现战术事件次序差异。详见[补验结论](LEGION_FORMATION_VERIFICATION_20260924.md)，严格自然重放门仍失败。

复测使用Godot4.6.3 mono console `--headless --path . --script res://tests/tools/legion36_<入口>.gd`，入口依次为 `boundary_contract`、`economy_contract`、`recruitment_regression`、`live_smoke`、`ui_contract`、`content_contract`。边界测试可用 `-- --output=res://artifacts/legion36/<新文件>.json` 保留独立结果。日志须同时检查终态和SCRIPT ERROR/ERROR，不能只读完成标记。

完整门命令：

```powershell
powershell -ExecutionPolicy Bypass -File tools/verify_grey_ridge_release.ps1 -GodotConsolePath $engine -ExportPath artifacts/legion36/release02/WARSEED.exe -SessionId legion36-release02
```

该命令已正常结束；终态与导出文件哈希见 `artifacts/legion36/release02-terminal.json`。自然经济观察会话22908仍在运行，不能重启或提前宣称两次完整局通过。发行包未更新，不提交、推送、建分支或进入R6/R7。
