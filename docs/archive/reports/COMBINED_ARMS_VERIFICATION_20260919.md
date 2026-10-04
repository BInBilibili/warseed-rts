# 双武器与军团协同验证

> 历史归档：正文只描述当时版本，旧“当前/下一步/待验证”不再授权执行。现行规则与进展从[文档入口](../../README.md)读取。

工作项 WS-MAINT-20260919-004，D-035；证据 SIMULATED。状态：全部必需功能、完整发布门及独立EXE实机通过；交付包按manifest与独立解压哈希核对。

## 功能证据

- `artifacts/combined21-rules07.log`：PASS。已通过双方新数值、实际招募/覆灭重建、旧兵伤势与导弹保留、导弹实际HP杀伤、随机区间与两次确定性、固定300普通炮、360距离追近开炮、补弹切回、快照值拷贝、全体展开依赖、手控与撤退、目标合法性。07追加最后路段长度为0时保留途经点，PASS。
- `artifacts/combined21-operation03.log`：PASS。实际8张卡均于tick157开始联合接敌；据点互援完成防守和驻守，tick259完成。两名将领实际经命令验证提交共享集火；目标隐藏后不再下达该集火；整体撤退身份进入局部战斗保护。
- `artifacts/combined21-regression-combat.log`：PASS。无将领自主射击、侦察随队、移动中集火、追击回位，以及补员窗口回归。固定秒桶0/1/2各5人；tick9和10可合计10人，这是相邻两个固定模拟秒，不是单秒越额。
- `artifacts/combined21-ui05.log`：PASS。中文/英文×1280×720、1920×1080、2560×1600、640×800、480×800，协同与阵型传入方案、审批按钮回调生成权威图。图像为combined21-ui-*。
- `artifacts/combined21-native-source02.log`：实际Windows输入PASS。滚动至批准按钮→鼠标点击→“方案已入队”→权威图数量1→“方案已批准”。截图`combined21-native-approved.jpg`。此项补足UI脚本的回调验证；不把回调称为真实鼠标输入。

- `artifacts/combined21-edges01.log`：PASS。同卡混合弹药分别发射两种武器；两卡实际接管/归还后图级时钟只计21tick，旧图快照保持不变。
- `artifacts/combined21-generator-check.log`：PASS，Godot `--check-only --script res://tools/generate_final_decision_battle.gd`，不覆盖现有资源。

- `artifacts/combined21-contested02.log`：PASS。在展开路线布置能攻击的250生命敌军，断言实际受到伤害后，8卡仍于tick157开始联合接敌。仅覆盖这一可控拦截场景，不外推任意敌情。

## 完整门、确定性与交付

最终门日志：`artifacts/combined21-release02.log`，PASS，1390.611秒，Godot4.6.3 stable mono。含两轮18套回归、四关smoke与策略矩阵、灰脊30场完整对局确定性、跨关审计、公平知识/存档、五档UI、工具smoke、Windows导出和导出包smoke。01主动停止：后续发现并修复零长度终末路线边界及初始化防御检查，01不计最终通过证据。

自然完整对局：第一轮`artifacts/combined21-natural01.log` PASS，tick8604（860.4模拟秒）蓝方失败，峰值人口248/235，首战tick1460，补员上限5/固定秒。侦察实际射击921/1930次，火炮1342/1171次，总射击11252次。哈希`80385d61bea76dfa67dd71b150558d29717050300939bc44ebf6f458aa6cdf75`。第二轮`combined21-natural02.log` PASS：同tick结局、峰值、射击和补员统计一致，完整事件SHA-256完全相同；独立核对收据`combined21-natural-comparison.json`。两轮墙钟耗时1147.55/1007.54秒，此值受并行测试负载影响，不作为性能通过依据。

参数仅启用原自然将领，蓝方未购买区域支援，不注入资金、敌情或强制战斗结果。日志有4512次UNIT_STUCK与526次COMMAND_REJECTED；它们是检测/拒绝事件次数，不是4512个永久挂机单位。本轮不能据此声称拥堵已全部消除；蓝方被动策略的一场失败也不证明阵营胜率失衡。

源代码冻结清单：`artifacts/combined21-runtime-freeze.json`；交付脚本需确认所有条目无漂移，并核对独立解压包每个文件SHA-256。EXE SHA-256：`679DF06F7F9F2D2293768747AA9AD71FB996869249960179ADA8180445FC0A7A`；PCK：`3130E15168A9E57ED481EEF374FD0F437AAAE8BB70918F5D45CD1886030F09F9`。最终EXE实机PASS：从独立目录正常入口进入最终决战，实际点击选择联合进攻、生成、批准，HUD显示展开0/4军团、4卡执行及协同全体撤退。截图`combined21-export-plans.jpg`、`combined21-export-approved.jpg`；日志`combined21-native-export.log`无脚本错误。导出模板不接受命令行场景路径，首次快捷启动被拒绝后改为正常主菜单流程，未修改模板或运行代码。

## 已知边界

- 火炮随机系数表示伤害波动，不含几何散布/独立脱靶；模式显示可滞后1tick。
- 有弹时不因敌人进入140内改用普通炮；需弹尽才切换。混合弹药成员分别选武器但整卡仍共同行军。
- 展开遭遇敌军可能停步自卫，联合进攻会等待；玩家可改路线或全体撤退。不是任意敌情下自动包围解围。
- 互援为已占据点防守，结束后驻守；没有临时援助后恢复旧任务。红方仍用原行动与支援AI，未宣称红方也生成玩家参谋方案。
- v4跨局存档格式未变，新增战中武器和协同状态每局重建。旧关基础资源不改。
- HUMAN：OPTIONAL_NOT_RUN；性能硬门：DEFERRED_D028。真实玩家理解、长期乐趣、双方胜率平衡均未被工程测试证明。
