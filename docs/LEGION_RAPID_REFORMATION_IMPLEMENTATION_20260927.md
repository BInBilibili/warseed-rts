# 快速重整实现进展

工作项 `WS-MAINT-20260920-001`，实现切片 `legion57`。用户已授权按[新设计](LEGION_RAPID_REFORMATION_20260927.md)实现并自主验收；该授权替代上一轮仅文档范围。B/父维护仍REWORK，当前DISCOVERY→CONTRACT→IMPLEMENTING。

目标：在同一隔离候选中接入有界友军移动穿透、命中时1.5倍承伤、角色间距压缩和玩家部署预览，并验证状态、空间、控制和确定性。依赖新设计、第二版阵型、出口部署和完整B接入契约；保留10Hz、稳定身份、合法知识、整卡控制、伤亡/补给与原目标语义。范围外：改变成长表、普通武器、地图拓扑、v4军团档案、R6/R7及发布旧证据。

工作目录 `artifacts/legion50/candidate`；本轮基线备份 `artifacts/legion57/baseline/candidate`、正式工程哈希 `artifacts/legion57/baseline/main.json`。正式接回须根据新候选验收与差异审查，不覆盖工作区其他修改。所有新测试分别冻结输入与源码，旧原件不改写。

验收顺序：状态/碰撞/伤害边界 → 压缩与命令/预览 → spear24与gunner60双向 → 新版局部与出口矩阵/重放 → 控制、归队、知识污染、快照和UI回归 → 交通/受火对照/适用完整门与完整局。验收标准沿用设计第9节；未执行项明确NOT_RUN。新驱动 `python -X utf8 artifacts/legion57/run_case.py --name <独立运行名> --script <测试文件名> --profile spear --count 24` 以结构化参数拼装子进程命令，并核验结果身份；缺结果、脚本错误、超时或源码漂移都失败。

成本约束：用户确认每百万token 50美元、上限300美元，较简单的工作使用gpt-6-sol。按本次目标更新时17,295,945 tokens起算，额度6,000,000增量token；预留100,000，在5,900,000前停止新增工作并交接。账本见 artifacts/legion57/cost-ledger.json。该金额是用户指定费率估算，不是供应商账单；外部503未返回usage，保留余量。

当前证据：本轮预检diff检查通过；候选备份完成；新版安全驱动已创建。新游戏机制、模拟、完整门、正式整合均NOT_RUN；HUMAN可选NOT_RUN。后续按实际输出补充，不能用此进度文件作为通过回执。


## 2026-09-27 候选进展与证据

实现范围保持隔离候选：typed重整配置已落为data/legions/rapid_reformation.tres；状态、滚动预算、取消、命中伤害、压缩、动态路线/落脚复核、停止重叠与死亡清理已接入。炮车真实间距不足48或仍在重整/分离时不能完成驻停开火。新增回退行为保留原目标意图与截止tick，不续租。

部署规划为少数受阻槽做不超过96的局部修正，按距离及局部坐标稳定排序，保留原目标和其它身份；炮位保持48，护将排斥不整体缩放。gunner60原失败仅最后炮位位于不可走地形，normal02/mirror01均已完成清尾、成阵及原目标到达；之后增加动态复核的normal03也通过。旧失败原件完整保留。

手控整卡使用与预览相同的部署规划，新增许可压缩选项已实际接入。多卡预览分配不同落点并由真实输入提交；诊断单兵不显示整卡阵型。仅通行标签必须有可放且可达的真实纵列，文案不保证未知出口。将领目标携带所示朝向，权威重新评估全团目标，验证过程不改将领状态。整团窄点若无最终可部署空间仍拒绝：完整纵列到达/继续找出口的将领命令行为尚待补齐，不能用单卡纵列证明它已完成。

| 回执 | 范围 | 结果 |
|---|---|---|
| contract03 | 机制与五将四态三档布局 | 142项PASS，仅原冻结 |
| spear24-normal02 / mirror01 | 新规则定向物理出口 | 双向PASS，仅各自冻结 |
| gunner60-normal01 | 最后炮位地形失败 | FAIL保留 |
| gunner60-normal02 / mirror01 | 有界局部槽修正后出口 | 双向PASS，约358万检查/场 |
| gunner60-normal03 | 增加路线/落脚复核 | PASS，3,591,927检查 |
| contract04 /05 /06 | 增补HOLD、死亡、炮位开火等 | 各149项PASS，各自冻结 |
| preview01 | gpt-6-sol测试草稿初跑 | 类型推断解析失败，根代理修复后再验 |
| preview02 | 真实游戏输入、人数/阵位、双卡、隐藏污染 | 18项PASS |
| preview03 | 加入真实应用、全团目标/朝向、只读校验 | 26项PASS |
| unit01.log | 初次18组回归 | 解析失败后主动终止，不计通过；候选缺失的68项基线素材/导入文件已从正式只读复制 |
| suite02 | 全套18组回归 | PASS，141.06秒，无脚本错误/漂移；后续修改仍需最终门 |
| exit-matrix01 | 五将×五档×双向，计划50场物理出口 | STOPPED_FOR_REWORK；40场完整终态36 PASS/4 FAIL，2中止、8未运行 |

所有回执位于artifacts/legion57；run_case.py冻结包括src/data/tests/tools/scenes/locale/assets/project.godot及引擎。首次素材补齐记录candidate-assets-added.json，不覆盖已有文件。资产此前未纳入驱动冻结，旧回执不据此宣称完整UI资产验证。正式源代码未接回。

exit-matrix01在白九阳48/60人原向及镜像四场失败后主动停止进程树；失败场清尾，但后排纵深超出可部署地形，标准48、轻压缩40、紧凑32三档局部适配均无解，未进入完整展开、稳定20tick、出口回执或原目标到达。证据 `artifacts/legion57/exit-matrix01-summary.json` 仅认证40场完整终态；2场中止、8场未运行不能计通过。候选转REWORK，下一步修同角色空间适配并重新冻结复测。

仍需：400局部转换矩阵、受火四组对照、动态出口/交汇/撤退、重放、自动交还目标/预算、完整局和适用完整发布门。正式接回/完整门NOT_RUN；当前部分定向与UI通过不能标完整B/父维护DONE。HUMAN仍可选NOT_RUN。

## 2026-09-27 纵深适配修复与交还缺口

新增同角色纵深压缩后备形态：按各角色前沿缩短自己的后排，保持横向中心、炮位和将领保护口袋；默认横向压缩/局部槽修正优先，后备形态无合法容量时回到原形态并由地形验证拒绝。身份0–59和将领60保留，原目标不移动。EXPAND重整许可同步采用对应档位到位容差（32档为4）；安全退回原位单列REFORMATION_RETURNED，不冒充原目标完成。驱动补齐attack身份校验及自身/引擎哈希复核。

- depth01首次检查暴露其它角色紧凑后备形态无解；失败保留。补齐回退后depth02为74,282项PASS，白九阳48人双向40间距、60人双向32间距，实地图包络及镜像本地槽相同。
- sentinel48-normal01/mirror01、sentinel60-normal01/mirror01四场均PASS，清尾、展开、普通碰撞稳定20tick、原目标到达均通过；无执行错误/漂移。contract07为149项PASS，dynamic02为21项PASS。
- gpt-6-sol完成矩阵驱动独立命名、覆盖保护、最多2场并行和首失败后停止派发；exit-matrix02已按首失败停止派发：50场计划中47场完整终态、46 PASS/1 FAIL、3场未运行，无中止场，候选和驱动漂移均为空。唯一失败为ranger36镜像，护卫路径最大240.053253，正常239.999847；详见`artifacts/legion57/exit-matrix02-summary.json`。ranger36-mirror01定向复测仍FAIL，ranger60-normal01亦FAIL（未完成展开/原目标到达），待修后重新冻结复测；不得计50场通过。
- handoff01为180项检查中的4个失败断言：30/100tick自动交还均仍进入旧任务归队，停止卡仍被排队交还；预算未被直接清零。handoff02亦报告自动交还失败，具体断言待核实。失败结果保留，待修复交还行为后补专项及最终门；正式接回和完整门NOT_RUN。

以上均为SIMULATED候选证据；父维护/B仍REWORK。正式接回、400局部触发矩阵、受火/交通/完整局与最终发布门仍未完成。

### 游骑兵出口后续定位（矩阵02之后）

ranger36-mirror01仅去掉护卫路径的0.001容差仍失败；根因继续定位到SimulationWorld._advance_unit用相对坐标is_equal_approx判断受限位置，随后丢弃受限结果并写原移动点。改为精确比较；整卡完成前的同类检查同步处理。ranger36-mirror02通过，原矩阵失败不可改写。

游骑兵60人原布局容量失败；同角色纵深压缩允许局部纵向调整至96（仍受欧氏96范围与角色/护将约束），depth03为74,964项通过，包含白九阳和游骑兵48/60双向。ranger60-normal02/03仍因一名单位处于SEPARATING夹角内未完成，均保留失败。

补充普通速度分离方向：依当前重叠友军的法线/切线和合成方向搜索，所有候选继续走既有扫掠碰撞、地形、护卫约束，不开新穿透、不推邻兵、不中断1.5承伤。separation01及ranger60-normal04曾因新代码变量类型推断解析错误主动结束；补显式float后separation02双向14项PASS，dynamic03为21项PASS。ranger60-normal05/mirror01定向尚在运行，待终态。run_case.py新增脚本错误即时停止并去重错误摘要，原始日志保留。

自动交还修复仅有staging/legion_control_handoff.gd草案，尚未接入candidate，依赖的字段/调用方尚未实现，不能作为可运行机制。handoff01/02仍FAIL。父项/B保持REWORK。

### 当前续接：出口矩阵03、交还与预览

- ranger60-normal05/mirror01双向PASS（约359万检查/场），普通速度分离规则修复最后一名成员卡住。失败normal01–04均保留。
- 自动交还已正式接入隔离候选：LegionControlHandoff接管当前formation命令及任务目标，UnitCardState/Snapshot记录player_stopped与continuing_player_order，延续中的卡不被旧军团槽/旧战略任务改写；新合法指令解除延续标记。停止卡不自动排队交还。重整对象/预算保持原值；旧四关显式交还路径保留。
- handoff03为2,684项PASS；handoff04进一步验证实际到达、部署观察20tick及旧快照独立，PASS。suite03为18套PASS（239.45秒，无错误/漂移）。当前exit-matrix03运行中，先读取终态再改candidate。
- attack-matrix01已STOPPED_FOR_REWORK：4场终态2 PASS/2 FAIL，46未启动。spear24双向清尾/展开后护卫identity12的最终进攻槽距将领超过240，二者无法同时到位；下一步在同批合格核心中选择当前可达且最终阵位相容的护卫，保持身份/目标/实际护卫约束，另跑独立冻结。不能以普通移动通过认证攻击移动。
- gpt-6-sol已生成staging/preview-markers.patch和接口说明，候选未应用；仅纯展示将领菱形/炮位方框，根代理需应用后补预览专项。

完整400触发矩阵、受火四组对照、动态交通/撤退、整团仅通行目标、10/30tick分离告警/将领参与提示、完整局、完整发布门及正式接回仍未完成；B/父项继续REWORK。

### 最新终态与进攻护卫修复

普通出口exit-matrix03已50/50 PASS，五将×五档×双向全部清尾、展开并普通碰撞稳定20tick、原目标到达；零源码/驱动漂移。此冻结早于进攻护卫/预览后续修改，不能作为最终全源码验收。

attack-matrix02在26场终态后首失败停止：24 PASS/2 FAIL/24未运行，林墨36双向未进入EXPAND。同批当前/最终均可达护卫与最多96将领局部调整已接入；后续诊断显示八单位采样漏过受其它核心保护区约束、宽不足一单位的合法将领口袋。增加护卫239.9边界几何候选，仍逐项检查192保护排斥、48炮位、64地形、真实护卫路径不超240；不放宽约束、不移动士兵身份槽/目标。attack-gunner36-normal02/mirror02分别1,410,974/1,410,828检查PASS，无错误/漂移；当前attack-matrix03完整50场运行中。

此前2单位细采样尝试normal01失败；命名mirror01那场漏传镜像参数，实际为重复原向失败，不计镜像证据。escort-geometry01解析错误保留，显式类型修复后的geometry02只用于诊断，不能作为行为验收。

预览标记已实际接入candidate，preview06为26项、markers01为27项PASS，覆盖将领菱形、炮位方框和点位/值拷贝/清理。旧staging补丁不等同落地证据。gpt-6-sol准备400局部恢复草稿，但建模缺口未解决，NOT_RUN，不计400场通过。其余未完成范围与B/父REWORK不变，正式接回/完整门NOT_RUN。

attack-matrix03已终态50/50 PASS（全部实际清尾、展开稳定20tick及原目标到达），无源码/驱动漂移；attack-replay01比较gunner36双向独立运行，同候选/引擎下完整JSON与path_hash相同。新preview-route01为10项中的2个双向失败：点导航能穿过32宽缝，但64包络不能；现有movement_plan提前返回STANDARD，待修。护卫阵亡测试escort-loss01运行中。

preview-route02修复后10/10 PASS：STANDARD与COMPRESSED也须先通过64地形包络；窄缝双向拒绝，拓宽后标准部署仍可用。escort-loss01在进入EXPAND后受控移除护卫，旧选择保持240距离但无法恢复原角色阵型；修复替补选择必须当前/最终同一核心可达且不再移动既定阵位后，escort-loss02为657,386项PASS，替补最大实际路径239.999603、存活者稳定20tick。此为受控死亡实验，不是自然战斗/经济整局。最新candidate已不同于attack-matrix03冻结，后续最终回归仍需按变更范围执行。

分离告警已接入候选：separating_since_tick由权威首次进入SEPARATING设置、重复end保留、SOLID/begin清除，快照值拷贝；10tick受影响卡提示、30tick军团可见合并告警、将领REFORMING/SEPARATING独立可见提示，均保留+50%风险。gpt-6-sol交付镜像经源/目标SHA256核验和逐差分审查后应用；其git apply检查因ignored子目录静默跳过不计证据。根代理修正测试缩进、增补视口/将领文字尺寸后，warning02为471项PASS（2语言×5尺寸），像素NOT_RUN。import13 headless导入无脚本错误。move-replay01/02各715,992项PASS，同冻结/引擎，完整JSON与路径hash一致。suite04因误传不存在脚本执行失败保留；正确入口suite05正在运行，冻结期间不得改candidate。

交还生命周期审查后的复现：handoff-graph01有3失败，旧graph任务被原地改成玩家目标，节点完成会停止当前移动；handoff-life01有10失败，终态/丢失formation/无活成员/英雄死亡残留continuing标记。候选改为仅取消被玩家命令替代的旧卡片图节点与预约，不停当前formation，创建独立handoff任务；旧排队START重新校验被拒绝，其它卡节点不在该方法取消范围。终态、撤离、无活成员、英雄回营走显式cancel_current，保留单位重整预算。handoff-graph03 48项PASS（含旧快照独立/旧START拒绝），handoff-life03 360项PASS（含真正withdrawal/hero生产路径和合法新命令）。原handoff05到达回归已18,156项PASS（artifacts/legion57/handoff05/terminal.json），无错误/漂移。suite05已18套PASS，150.218秒，无错误/漂移，但早于本次生命周期修改；后续最终门仍需新冻结。


### 静止将领阵位修复与标准空间攻转防矩阵

静止且非撤退时沿用record.spatial.facing，避免把将领到目标的偏移反复当成新朝向。可行STANDARD/COMPRESSED部署使用identity60的实际计划将领槽，并选择当前与最终路径均不超过240的合格核心；合法地形/已见暴露约束仍在。林墨60双向定向各119,991项PASS；其早期脚本未认证将领最终槽，完整槽断言已加入后续矩阵。此分支也影响非撤退行军，须保留对应新回归。

action-matrix01：30 PASS/2脚本FAIL/18未运行；白九阳12双向因空卡无formation而越界，修正夹具判空并断言仅空卡可缺formation。action-sentinel12-01为5,007项PASS。新冻结action-matrix02为50/50 PASS，零候选/驱动漂移，包含五将×12/24/36/48/60×地图中心180度镜像，最长局部暴露15tick、最大护卫路径236.421509、最少连续稳定20tick，明确检查identity60最终槽及士兵实体槽。证据artifacts/legion57/action-matrix02-summary.json及逐场终态。

范围为真实地图标准空间、受控ATTACK初阵经内部生产stop转换DEFEND及局部执行；不算完整400矩阵或完整命令端到端。当前源码suite06运行中；正式接回、适用完整发布门、受限空间/其余触发、受火四组对照、动态交通/自然完整局仍未完成。B/父项REWORK，HUMAN可选NOT_RUN。


### 2026-09-28 撤退命令链补验

suite06为18套PASS、145.54秒、零错误/漂移，早于以下撤退修复。gpt-6-sol交付受控撤退夹具；初稿漏跑战略任务系统而未到达（retreat-spear12-01，保留失败）。补上队列应用→战略任务提议→局部运动，改用明确整团目标/朝向，保持原512退路；retreat-spear12-02确认士兵第17tick才动，原因是DISENGAGE仍受普通15/30tick与学说准备等待。候选将已接受撤退的activation_tick设为当前tick并取消等待发现敌人的门，不改变普通进攻延迟；retreat-spear12-03为10,607项PASS。

retreat-matrix01首失败停止，28 PASS/2 FAIL/20未运行：林墨60双向整团计划STANDARD，但单卡探针未携带整团朝向，从退路自动推导相反朝向，导致炮组NO_SPACE。诊断回执retreat-gunner60-diagnostic01保留；probe沿用command.deployment_facing后，retreat-gunner60-02为240,016项PASS。候选只修改simulation_world.gd以上两处；正式源码未接回。

撤退matrix02及完整候选门release01运行中，等待终态，冻结期间不改候选。撤退夹具含真实submit_command/生产应用/战略任务，仍为受控初阵和局部执行，不认证自然完整局或全部400矩阵。父项/B仍REWORK。


撤退matrix02终态50/50 PASS、零漂移，士兵沿原退路最迟第2tick取得进展、最长局部风险21tick、将领护卫最大222.716003、最终全员普通状态稳定20tick。preview07在撤退修复后26项PASS。独立脚本audit_transition_matrices.py核对action02/retreat02各50个唯一profile/count/mirror、逐场终态/日志/输入冻结/结果哈希和稳定性条件，回执transition-matrix-audit.json；两矩阵仍各自认证自己的冻结，不冒称400场或自然整局。release01完整门继续冻结执行。


release01终态FAIL（1327.681秒）：前15阶段通过，含两轮18套、旧四关/灰脊完整局、72场综合平衡与双语五视口UI；第16试玩报告工具因Python中转继承PowerShell7模块路径而找不到Get-FileHash。无游戏脚本错误、候选/正式运行文件零漂移；此结果不是完整门PASS，导出/后续工具未运行。修正外部驱动子进程PSModulePath后，独立报告smoke通过。候选缺少的9个打包说明/入口及27个本地导出模板依赖从正式目录只读复制，已有不同文件拒绝覆盖，回执release-support-added.json。release02采用候选此前不存在的build/windows默认导出路径，确保kit检查当前产物，终态复制进独立证据目录；其完整门运行中。未改正式文件、未发布。


### 预算收尾：完整门仍未通过

release02终态FAIL、1320.190秒、前20阶段通过；Windows导出因候选缺WARSEED.sln产生.NET错误，严格驱动终止原进程，源码/主工程零漂移。随后核对已有csproj与正式一致，只复制缺失sln并加入冻结输入。export-preflight01在补齐前虽退出0但有错误，不计通过；export-preflight02有.NET publish完成、EXE/PCK及无错误日志，但长期未退出，预算收尾时核验PID49428命令行后taskkill精确终止。回执export-preflight02/terminal.json为INTERRUPTED，导出smoke与kit NOT_RUN。失败与产物全部保留，未发布。

截至get_goal总tokens23,171,090，按起点17,295,945、50美元/百万token折算293.75725美元；停止新增实现与测试批次，为最后证据记录预留成本。goal仍未完成，不标DONE/不推进R6。先诊断补齐sln后的导出退出问题并补导出smoke/kit及完整门，再继续400恢复矩阵、受火四组、动态交通/整团仅通行、自然完整局和正式接回。正式工程无本轮代码接回。


### 导出退出修复专项（预算内续接）

export-preflight03通过：相同候选和引擎，在补齐sln后增加显式--quit，导出12.864秒退出0、无错误；导出EXE独立会话headless启动2.152秒退出0、无错误。记录189个导出/.NET依赖文件及哈希，候选与正式运行文件零漂移。回执artifacts/legion57/export-preflight03/terminal.json。此前preflight02不能回写PASS。候选tools/verify_grey_ridge_release.ps1的Windows导出参数已追加--quit；此次补丁后的完整门未重跑，试玩kit仍NOT_RUN，不能将这两个专项提升为完整门通过。


打包补验发现实质遗漏：kit01 manifest仅17文件，未包含本次导出的187个.NET依赖。候选build_playtest_kit.ps1现在保留完整data_WARSEED_windows_x86_64目录，缺少托管导出目录时拒绝打包；kit smoke要求WARSEED.dll、GodotSharp.dll和WARSEED.runtimeconfig.json进入manifest。kit02打包/ZIP解压/全量manifest哈希检查退出0通过（artifacts/legion57/kit02-terminal.json）。旧残缺build/windows经绝对路径边界检查移至candidate/build/windows-failed-release02；当前默认导出复制自preflight03，不覆盖失败证据。此前导出EXE启动通过，但尚未运行打包后启动或以上工具修复后的完整门；不合并声明完整门PASS。预算已到交接预留线，记录总tokens23,196,323、增量5,900,378、估算295.0189美元。无活动测试，父目标未完成。


打包后启动补验kit03 PASS：重新构建包并解压，204个manifest文件（17基础+187.NET依赖）逐项SHA256匹配；解压后的EXE在全新profile中headless启动2.215秒退出0，无脚本错误，候选输入零漂移。候选默认导出已安全保留为build/windows-pre-release03；新版完整门release03运行中，冻结期间不改候选。预算约295.7542美元，后续仅收取已启动验收及交接，300美元上限保持。


### 发布回归门终态与完整目标边界

release03终态PASS：完整脚本1378.296秒，驱动1380.497秒，23个唯一阶段全部通过，包括两轮18套、灰脊完整局、旧四关矩阵、72场平衡审计、UI、5项工具、Windows debug导出、隔离启动及试玩包。独立audit_release03.py重新检查逐阶段PASS标记、日志零错误、1485候选/1380正式输入与引擎/驱动哈希、3个导出文件及187个托管依赖归档，零漂移；回执artifacts/legion57/release03/audit.json。D-028性能门暂缓，没有性能PASS声明；HUMAN可选NOT_RUN。kit03另有204文件哈希与解压后新profile启动PASS。

这证明当前隔离候选通过既有发布回归。B仍缺完整400局部触发/受限空间矩阵、受火四组与补亡成本对照、动态出口/交汇/相向队列、整团仅通行、自然完整局及后续正式接回验证；A DONE，B/父001 REWORK，C/D未完成，不推进R6。旧失败原件与各自冻结不改写。所有本轮测试进程终态，预算剩余额度留交接，不新增实现批次。


### 自然最终决战的负面观测与预算收尾

natural01复用growth_match_selfplay完整18000tick上限和真实world.advance_tick，仅添加观测/JSON输出，未篡改人数、补给或命令。驱动900秒超时终止，退出1、缺最终结果，不能计完整局PASS；零脚本错误、候选/正式输入零漂移。三个真实日志检查点：1000tick人口85/85、占点5/5、累计补员50；2000tick人口136/144、占点8/8、补员160；3000tick人口136/145、补给300/300、占点8/9、补员161；三点均无弹丸发射。实际终止tick未知，不用最后日志tick替代。重整统计没有最终JSON，未认证。

observation-audit.json核对终态、冻结和日志哈希，列出bai_jiuyang、di_tian、lu_zheng、mobile_legion、red_lu_zheng、red_mobile_legion六组在2000/3000tick的目标/兵力/卡中心/任务打印串完全相同。仅提示可能停滞，不能证明中间完全未移动或直接断言根因。下一次先记录这些组的任务phase/block reason、护卫/空间状态、归队路径与招聘等待原因，再修自然推进；不要只扩超时并宣布完成。

当前目标仍未完成：release03的发布回归PASS不覆盖自然玩法的负面观测。按300美元用户成本上限保留最后交接余量，停止新的批次并暂停目标；不标DONE，不接回正式工程。
