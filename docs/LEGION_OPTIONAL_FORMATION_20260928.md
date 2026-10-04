# 玩家自选阵型与自由行军

工作项：WS-MAINT-20260920-001 / legion63。父项 REWORK；本切片已完成 CONTRACT → IMPLEMENTING → VERIFYING，已通过最终REVIEWING并完成本切片。

来源：2026-09-28 用户要求撤销常态保持兵团阵型，四种形态作为将领卡主动配置状态；修复动态文本撑高卡片。此授权进一步替代 D-038 的常态阵型偏好，不改变数值。

行为契约：最终决战默认自由行军，不执行全军团阵位、护卫距离、整队等待或最慢兵种统一限速。整卡各自执行合法目标，将领按真实可达的主力成员位置跟随。地形与敌军实体碰撞、实际重叠承伤×1.5、速度预算、成长编制、炮组已有战斗权限保留。

将领卡提供自由行军、行军阵型、进攻阵型、防守阵型、撤退阵型。通过既有统一命令管线配置；仅所属玩家可以修改，AI 不可自动启用或改变所选阵型。四态是阵型选择，不自动生成进攻/撤退战略命令。选定后持续有效，切回自由行军立即释放阵位和旧路径；阵亡重组回到自由态。单独手控/停止的部队不被编入阵型。狭窄地形仍允许让路和压缩，不把成阵当移动准入。

卡片显示当前存活成员及将领的标准阵型宽×深（世界单位，含64实体包络），为平地尺寸参考，地形可能阻止标准展开。自由态显示不要求阵型空间。固定显示行数和控件高度，长说明放悬浮提示，炮兵行预留空间，不随状态增加/消失。

快照值拷贝新增阵型枚举；无战中存档，v4会战档案不变，新局自由态。旧四关操作不变。数值资源以 artifacts/legion63/baseline-hashes.json 比较；覆盖前源码保存在 baseline。

验收：默认不产生全团槽位；四态命令/拒绝/快照隔离/退出/停止；真实行军和将领跟随；中英五档布局高度稳定；完整发布门（命令/公平知识/存档/UI/导出）。所有自动证据 SIMULATED，真人体验及实际FPS为 NOT_RUN。范围外：其他父维护缺口、经济平衡、R6/R7、提交推送。

## 实现与当前证据

- 默认自由态绕开兵团阵位执行和全员等候；单位保留各自途经点进度，地形更新与局部炮组调整只重新连接剩余路径。终点使用就近空位，途中不保持队列；空间不足时继续沿用D-038拥挤规则。
- 新增 `LegionFormationCommand`：验证所属阵营、玩家来源、枚举和重组状态；队列值拷贝，模式变化不接管手控卡、不取消战略任务图。模式在CommanderSnapshot中值拷贝。阵亡召回回到FREE。
- 将领卡增加五项模式和当前兵力宽深说明。提示内容保留，按钮最多三行、状态固定两行、炮兵预留一行；旧四关重复刷新不累积tooltip。
- 只读审查修复：预览/手控部署传递所选形态；完成MOVE后的原地成阵锚点不漂移；自由路径保存已完成途经点；炮组临时接管后路径从实际位置重新连接。
- `optional06.log`：1284项PASS，包含模式切换、外阵营/AI/非法枚举拒绝、入队拷贝、旧快照隔离、退出、原地成阵与路线中断、两语言×五尺寸×两面板文本高度。仅headless布局几何，不冒充屏幕真人验收。
- `numeric-audit.json`：126个data文件与本轮开始SHA256相同；没有调整数值资源。
- `movement01`保留为失败反例：自由态仍沿用旧分散目标/中心600距离提前交给AI。修复后 `movement02`354295项PASS；加入独立终点避让后 `movement03`289138项PASS。最终剩余途经点改动后的冻结验证以 `movement-final`/`movement-replay`为准。
- 首次`optional01.log`4项失败来自开局已排队的AI目标变更混入配置断言；测试先完成开局命令tick后重测，不屏蔽AI命令。最初import01因旧Transit引用_stop缺失报解析错误，保留兼容辅助后通过后续脚本加载。
- 全部自动证据均SIMULATED；HUMAN复验、实际FPS、自然完整局均NOT_RUN。旧legion62完整门和自然局不认证本轮新源码。


## 最终复核补充

- `optional09`：1291项PASS。新增停止卡不能作为显式阵型行军来源、全部停止时将领停住，以及新MOVE必须重置已完成路线游标；临时炮组接管与地图更新保留剩余途经点。
- `hud-geometry`：实际FinalDecision场景、中英×五视口120项PASS，确认整个将领卡面板不超出屏幕底部，五个阵型菜单及宽深标签在面板内；无窗口、不声称像素截图验收。
- `movement-final`和`movement-replay`：900tick、双方10将、288966项各PASS，结果JSON逐字节一致。`control-final`49项PASS；`artillery-final`66项PASS，真实参谋批准后实际发射，MOVE/撤退首tick抢占。后续明确source筛选、重复MOVE缓存和HUD预算小修不改变默认行军数值，但发布包仍需重新验收。
- `release01`因补修重复MOVE游标主动中断，`release02`因补修实际HUD高度预算主动中断，均NOT_PASS；保留中断JSON和原日志。最终源码以 `release-source-hashes.json` 为准，最终完整门使用 `release03`。
- `optional-final.log`的中间5项失败证明第一次缓存修复命中了同名成员代码段，尚未覆盖新MOVE分支；已把重置同时补入真实命令执行，`optional08/09`复验通过。失败原件保留，不算通过。

验收命令（在工程根目录，全部headless）：

```powershell
& <godot-console> --headless --path . --script res://tests/tools/legion63_optional_formation.gd
& <godot-console> --headless --path . --script artifacts/legion63/hud_geometry.gd
& <godot-console> --headless --path . --script res://tests/tools/legion58_movement_contract.gd -- --manual --ticks=900 --output=res://artifacts/legion63/movement-final.json
& <godot-console> --headless --path . --script res://tests/tools/legion58_control_contract.gd -- --output=res://artifacts/legion63/control-final.json
& <godot-console> --headless --path . --script artifacts/legion62/artillery_graph_inrange.gd -- --output=res://artifacts/legion63/artillery-final.json
powershell -ExecutionPolicy Bypass -File .\tools\verify_grey_ridge_release.ps1 -GodotConsolePath <godot-console> -SessionId legion63-release03
```


## 发布门结果

最终 `release03` 完整门23/23阶段PASS，耗时1247.61秒，无脚本错误；覆盖常规及隔离18套测试、四关决策/整局矩阵、跨关平衡、UI、反馈、Windows导出、隔离启动与打包烟测。机器审计：`artifacts/legion63/release-audit.json`。性能通过要求仍按D-028暂缓。

正式包核验直接启动EXE外部脚本的首尝试120秒超时，只认证此前EXE隔离启动，不把超时算作玩法PASS。改用仓库既有Engine --main-pack方法运行实际导出PCK：阵型/路径/布局1291项PASS；包内900tick行军另记最终package-audit。包源码冻结哈希不含本交接文档，不代表数据变化。


最终包：`build/playtest-kits/WARSEED-Free-Movement-20260928.zip`，SHA256 `f3cd18ab7c8c5304ddf75eb23b8108e6438164a788d3cb780266b2f717f367c0`。204文件逐项哈希通过、解压EXE隔离启动通过；Engine加载该实际PCK运行1291项模式/UI/路径与288966项900tick行军均通过，行军结果与源码两次重放逐字节一致。`package-audit.json`源码漂移为空。旧Movement/Artillery ZIP保留。

本轮范围已完成，父001继续REWORK。未解决/未认证：历史炮组old-intent终态问题、其余侦察/接替/ETA维护缺口；本轮自然完整局、真人操纵与GPU/FPS均NOT_RUN。性能政策按D-028。未提交/推送，用户原编辑器未关闭。
