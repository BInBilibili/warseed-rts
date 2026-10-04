# 固定军团与原子补员：实现进展

> legion35历史版本报告。后续legion36已实现共享经济与边界修复，专项通过、完整门1234.658秒PASS，自然经济观察尚在运行，A为VERIFYING；最新见[共享经济进展](LEGION_ECONOMY_PROGRESS_20260923.md)，下文“未实现”与后续校正均按版本读取。

工作项 `WS-MAINT-20260920-001`，legion35，A切片仍 **IMPLEMENTING**，完整A–D目标未完成。证据为SIMULATED，原生实渲与HUMAN为NOT_RUN；遵守无窗口限制。本文描述工作区实现，不把旧发行包或legion34隔离模拟改记为正式验收。

进度校正：legion35冻结版本的完整发布门已于1090.66秒通过，终态回执 `artifacts/legion35/verification-final.json`。之后legion36已接入共享经济仲裁，`economy08.log` 465项专项通过（受控收入，非完整局）；UI文案又有后续变更，尚未重新导入、验证双语五档或运行新完整门。下文经济失败描述保留legion35版本含义，不能用旧发布门认证legion36。

## 已接入的行为

- 战前将领交换携带其固定开局/满编组成；四种兵员数为只读。红方仍取公共将领预设，不复制玩家换位。
- typed军团模板允许明确缺席的炮兵卡保持稳定ID并出生0人，普通非法空卡仍拒绝。双方各60兵加5将开局。
- 将领面板按各自血量上限和参数展示，白九阳武装侦察使用专属数值与占点资格；旧四关维持原路径。
- 补员入队值副本锁定身份槽，应用时复验，不能因战损变化偷偷改买另一个槽。活着且归队中的新兵继续占原槽，阵亡后再次付费补回。
- 先寻找实际安全、在补给区、有局部可行连接且不与活体重叠的出生位置，再提交编号、编队、任务、成员和人口。找不到位置时拒绝，不收费、不占每秒额度、不改组织或编队，不发伪成功事件。整卡覆灭仍等200tick。

出生搜索以本卡存活中心为起点（覆灭用现有营地补员点），48间距、半径384、最多197候选；要求与本卡活体或重建点之间有不穿障的局部直连接段。中心均值按地图公共中心的双精度标量计算并对齐1/8距离网格；这是新兵位置选择，不移动既有单位。中心最小距离24沿用正式移动硬间距，不把设计中的32阵位余量宣称为碰撞半径。安全判断读取合法阵营知识，物理占位由权威世界检查。

## 验证与失败修复

| 证据 | 已证明的范围 | 结果 |
|---|---|---|
| `artifacts/legion35/roster03.log` | 模板加载、固定/交换组成、零卡、资源隔离、240槽名义成本、130实体开局 | 343项通过；总部修复前，相关配置代码未改变 |
| `artifacts/legion35/ui02.log` | 中英五档尺寸、只读编制、界面换将、将领帮助 | 254项headless结构检查通过，无像素/键鼠体验结论 |
| `artifacts/legion35/recruitment07.log` | 双方480次真实命令出生、费用、镜像、槽恢复、无空位/失去资格拒绝、控制任务继承 | 5123项通过，移除临时诊断后重跑 |
| `artifacts/legion35/navigation01.log` | 实际总部占地镜像、单双数建筑尺寸、摧毁释放、导航值快照、旧规则与大地图验证 | 204项通过 |
| `artifacts/legion35/live01.log` | 两次300tick正常自主推进、自动补员、槽身份、资金/配额界限及旧快照 | 160903次断言通过，两次事件与最终实体轨迹哈希一致 |
| `artifacts/legion35/regression01.log` | 18套常规回归 | 通过；总部修复后的同套检查以发布门为准 |
| `artifacts/legion35/release01.log` | legion35冻结源码完整发布门 | PASS，1090.66秒；不覆盖后续legion36 |
| `artifacts/legion35/economy_probe01.log` | 优先补给下的双轮顺序 | REWORK，见下文 |

480次成长使用正式 `submit_command`、队列值副本和应用校验，在受控固定秒、合成充足资金下执行；每人费用有 `recruitment.json` 逐条记录。陆铮/狄天/林墨/白九阳/云岚每方新增费用160/156/157/105/124，合计702；满编双方610实体。这不证明自然收入下的满编时间、共享资金预留或完整经济局。

两次30秒自主运行均从130增至138实体，双方余23补给，哈希 `c35bcdd90705f9f37a993766e21d440abea02a5e3359009269bcba19063d0f0a`；这是短时冒烟，不是完整局、阵型通过或健康对局节奏结论。

补员镜像检查曾发现林墨第53身份槽（从0编号）的出生位置相差96。原始失败日志02–05及 `recruitment-mirror-failure.json` 保留。定位发现双方4×3总部占地沿同向取整，中心镜像而阻挡格不镜像；修正中心对称地图上的建筑占地反射后通过。总部数值、位置、面积未改，旧地图占地分支不变。修复会改变大地图导航，不能沿用legion34地图轨迹或历史自然对局指纹作为该正式版本的验收；专项与完整门独立记录。

## 下一项及保留范围

经济探针实际队列是“陆铮第1人、陆铮第2人、狄天第1人、林墨第1人、白九阳第1人”，不符合“每轮各团至多1人”的两轮契约。当前按配额限制5/秒、每团0–2仍有效，但排序和防止高价下一兵饥饿的共享预留尚未实现。A不能据上述通过项标DONE。

下一步在同一A切片完成确定性双轮/轮转、等待时间与稳定ID、全阵营仅一个最高5补给的下一兵费用预留，以及失去安全/配额归零/取消/储备变化时释放；玩家支援不得被预留拦截。新增状态须通过值快照、合法知识、UI原因展示和实际经济争用验证。模板非法输入、专属武器与占点、旧档兼容仍需汇总适用证据。随后才可验收A并继续B成阵通行、C职责协同及D完整局与导出；B/C通用旋转压紧的拒收和白九阳损失超标保持有效。

## 复现

在仓库根目录用Godot4.6.3 mono console无窗口运行：

```powershell
& $engine --headless --path . --script res://tests/tools/legion35_roster_contract.gd
& $engine --headless --path . --script res://tests/tools/legion35_ui_contract.gd
& $engine --headless --path . --script res://tests/tools/legion35_recruitment_contract.gd
& $engine --headless --path . --script res://tests/tools/legion35_navigation_contract.gd
& $engine --headless --path . --script res://tests/tools/legion35_live_smoke.gd
& $engine --headless --path . --script res://tests/tools/legion35_economy_probe.gd
powershell -ExecutionPolicy Bypass -File tools/verify_grey_ridge_release.ps1 -GodotConsolePath $engine -ExportPath artifacts/legion35/release/WARSEED.exe -SessionId legion35-release01
```

经济探针的失败是待实现行为，不是允许降低验收线；发布门通过也不能覆盖此显式缺口。原生渲染未运行；发布门导出为隔离工程验证产物，不替换已交付包。

发布门会话42551已结束，`release01.log` 终态为passed，耗时1090.66秒。受验源码快照 `artifacts/legion35/runtime-atomic-freeze.json`，最终复核回执 `artifacts/legion35/verification-final.json`；源码随后已因legion36改变，不重跑旧 `verify_progress.py` 覆盖回执。EXE SHA256为 `679DF06F7F9F2D2293768747AA9AD71FB996869249960179ADA8180445FC0A7A`，PCK为 `23EA8B794780C8428D206B7E1DB2435632CC6064030F7FCADAB89A5A58654700`；仅隔离工程产物，未替换交付包。
