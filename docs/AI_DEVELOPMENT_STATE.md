# WARSEED AI 开发状态与任务队列

> 2026-10-05：[WS-MAINT-20261005-001](work_items/WS-MAINT-20261005-001.md) GitHub自动发包切片VERIFYING。用户授权提交全部既有工程改动，选择日常推送构建验证、版本标签发布；仅修改CI/打包工具和交接文档，不改游戏。流程使用固定Godot4.6.3 Mono/.NET8、原完整26阶段发布门、Windows自含包/来源/哈希；标签成功后创建测试预发布。实际提交/推送与首次云端结果待核对，证据artifacts/github-release，原父维护仍REWORK，R6/R7不变。

> 2026-10-04：独立权限切片 [WS-MAINT-20261004-001](work_items/WS-MAINT-20261004-001.md) 已DONE；D-040正式执行持续将领意图/整卡授权及取消坚守/显式交还。权限与边界/UI专项290项、release03完整发布门26/26（1441.592秒）、实际新PCK权限75项及双语五档UI141项均PASS，证据artifacts/control-contract。33个已有文件有本轮差异、12个新增文件；其余1528个基线文件及118个数据文件哈希未变。旧WS-MAINT-20260920-001仍REWORK且其他范围未完成，R5/阶段门不变。全部SIMULATED；旧成长探针NOT_PASS原件保留，HUMAN/实际FPS/本轮自然终局整局NOT_RUN，性能D-028暂缓；无提交推送。

> legion63交付：D-039默认自由行军，四种阵型仅玩家在将领卡主动配置并显示当前兵力标准宽深；取消常态全团阵位/护卫/批次等待，恢复将领随军，固定文本行数与实际HUD预留高度。模式/路径/布局1291项、实际场景中英五档HUD120项、900tick十将行军288966项及精确重放、控制49、重叠31、炮组开火/抢占66项通过。release03完整门23/23 PASS（1247.61秒）；新ZIP 204文件哈希、独立启动、实际PCK专项1291与行军288966均PASS，包内行军结果与源码重放逐字节一致。126数据文件哈希未变。包build/playtest-kits/WARSEED-Free-Movement-20260928.zip，SHA256 f3cd18ab7c8c5304ddf75eb23b8108e6438164a788d3cb780266b2f717f367c0。切片REVIEWING→完成；父001仍REWORK，其他缺口未完成。全部SIMULATED，真人/实际FPS/本轮自然整局NOT_RUN；无提交推送，用户编辑器保持。详情LEGION_OPTIONAL_FORMATION_20260928.md，审计artifacts/legion63/release-audit.json及package-audit.json。

> 预算截止补验：主代码与已交付ZIP均未改。artillery-main-completion01真实图自然结束tick393、整卡交还tick82，共150项PASS。加入真实先前玩家意图后，old-intent01在360tick观察内未终态，失败保留；old-intent02延长600tick，tick457自然终态，但20tick后检查出现“炮位承诺重新存在”和“执行来源不再STAFF_PLAN”两项失败（152项）。尚未核查是否由后续合法AI命令重新授权，不能直接断言残留意图越权，也不能宣称该场景通过。下一步先对照终态后命令/事件与来源再决定是否修复。主移动/窄路及release23/23证据保持，但不覆盖这一新增场景。辅助需求审查在预算边界主动中断，不作为完成证据。父项仍REWORK，完整目标未完成。

> legion62最终交付：22个炮组差异正式接回，覆盖前备份及旧导出保留；主900tick十将移动294531项、满编双向窄路10例1297526项均与原移动版结果逐字节一致，控制49/重叠31/真实参谋开火及首tick移动撤退抢占110项通过。完整发布门release01 23/23阶段PASS（1503.188秒），新包204文件哈希/独立启动/实际PCK移动21项及炮组110项通过，release-audit.json PASS。ZIP为build/playtest-kits/WARSEED-Legion-Artillery-20260928.zip，SHA256 30d50cea67d4ab2068e78593d9deb4130608783bc78034fbd3fa2f508ee8f80e。九次候选专项和18组测试只作对应源码证据；主natural05终局属于之前Movement版本，不认证新炮兵自然整局。完整父001仍REWORK：导弹在途承诺、白九阳完整侦察占点、巩固、云岚接替返回/路径ETA及更广图生命周期/B动态压力/C-D验收未完成。HUMAN及实际FPS NOT_RUN，性能按D-028。所有本轮测试终态，无运行残留；无提交/推送。

> 下方此前“运行中／隔离／待合入”均为相应检查点历史；以本段与release-audit.json为当前交付状态。

> legion62正式整合进行中：18组候选测试通过（artillery-suite01），22个已审查差异经主基线冲突校验接回，覆盖前副本保存在artifacts/legion62/integration-backup，旧默认导出保存在previous-default-export。主图开火/移动撤退抢占110项与候选结果完全一致；当前完整发布门release01和主移动/窄路复验正在运行，不宣称已发布。现有Movement ZIP保持原哈希；炮组整合不会把侦察/接替/ETA等未完项改为DONE。

> legion62补验：diagnostic01确认原live01目标可见，但炮兵距484–510，超过实际射程420；516只是特殊炮位选择上限，不能冒充武器射程。目标改为初始据点前240的独立inrange01场景后，真实参谋批准tick55进入战斗、tick71实际发射，三炮就位；撤退/MOVE首tick抢占均通过，共110项。独立replay01同110项且结果JSON逐字节一致。原失败和诊断原件保留，不称远距追击通过。最终mirror09/intent07/authority11/ui08/guard12/moving13及grants02/inrange01/replay01九次审计review-v5 PASS，源码/入口/继承/引擎一致；当前仍仅隔离候选、未正式合入，不代表完整C/D。

> 状态版本：171
> 更新时间：2026-10-05
> 更新规则：每个完成、阻塞或重新规划的工作项都必须更新本文件。
> 历史原文：[v109 完整快照](archive/state/AI_DEVELOPMENT_STATE_v109.md)，原第 12 节唯一保存的临时维护契约也在其中。
> 当前空间规则按Accepted D-039：默认自由行军，四态仅玩家显式选择；D-038实际重叠承伤×1.5保留。下面legion58–62为当时历史基线，不能覆盖本轮新授权。父项仍REWORK。

> 最新执行状态见下方控制块与第11节；旧失败原件与旧冻结结果完整保留，不能把局部通过升级为整个维护完成。详见 LEGION_RAPID_REFORMATION_IMPLEMENTATION_20260927.md。

## 1. 机器可读控制块

```yaml
workflow_version: 1.2
state_version: 171
github_release_work_item: WS-MAINT-20261005-001
github_release_status: VERIFYING
github_release_workflow: .github/workflows/grey-ridge-ci.yml
github_release_evidence: artifacts/github-release
control_contract_work_item: WS-MAINT-20261004-001
control_contract_status: DONE
control_contract_release: artifacts/control-contract/release-audit.json
control_contract_source_audit: artifacts/control-contract/release-source-audit.json
control_contract_package_audit: artifacts/control-contract/package-audit.json
control_contract_scope_audit: artifacts/control-contract/scope-audit.json
control_contract_export: build/control-contract/WARSEED.exe
control_contract_evidence: SIMULATED
control_contract_decision: D-040
legion63_status: SLICE_VERIFIED_PARENT_REWORK
legion63_release: artifacts/legion63/release-audit.json
legion63_package: build/playtest-kits/WARSEED-Free-Movement-20260928.zip
legion63_package_audit: artifacts/legion63/package-audit.json
legion63_data_audit: PASS_126_UNCHANGED
legion63_report: docs/LEGION_OPTIONAL_FORMATION_20260928.md
updated_at: 2026-10-05
legion58_status: MAIN_MOVEMENT_SLICE_VERIFIED_PARENT_REWORK
legion58_report: docs/LEGION_MOVEMENT_REPAIR_20260928.md
legion58_integration: PASS_135_PATHS_NO_BASELINE_CONFLICT
legion58_collision: OVERLAP_FINAL04_31_PASS
legion58_manual02: PASS_294378_CHECKS_10_COMMANDERS_900_TICKS_PRE_REVIEW_FIX
legion58_manual03: PASS_294453_EXACT_REPLAY
legion58_manual04: PASS_294531_EXACT_REPLAY
legion58_narrow_full03: PASS_10_CASES_1297526_CHECKS
legion58_hq_after01: PASS_10_OF_10
legion58_natural04: INCOMPLETE_TIMEOUT_5400_SECONDS_LAST_TICK_10000
legion58_natural05: PASS_VICTORY_TICK11017_DEFAULT_ECONOMY
legion58_final_review: artifacts/legion58/final-audit-v2.json
legion61_retreat_barrier: PASS_57243_BLUE_RED_CONTROLLED_MOVEMENT
legion61_review: artifacts/legion61/independent-audit.json
legion59_status: STAGED_PREPARATION_ONLY_NOT_PRODUCTION
legion59_artillery: STAGED03_PASS_29
legion59_recon: STAGED02_PASS_20
legion59_report: docs/LEGION_ROLE_PREPARATION_20260928.md
legion62_status: RELEASE_VERIFIED_ADDITIONAL_OLD_INTENT_REVIEW_REQUIRED_BUDGET_STOP
legion62_release: artifacts/legion62/release-audit.json
legion62_package: build/playtest-kits/WARSEED-Legion-Artillery-20260928.zip
legion62_review: artifacts/legion60/review-v5.json
legion60_status: INTEGRATED_BY_LEGION62_PARTIAL_C_VERIFIED
legion60_runtime: MIRROR08_PASS_14794
legion60_guard: GUARD11_PASS_2900
legion60_moving: MOVING12_PASS_23_ATTACK_AND_DEFENSE
legion60_intent: INTENT06_PASS_43
legion60_authority: AUTHORITY10_PASS_46
legion60_ui: UI07_PASS_109
legion60_report: docs/LEGION_ARTILLERY_RUNTIME_PREPARATION_20260928.md
legion60_review: artifacts/legion60/review-v4.json
legion58_dynamic02: PASS_3163_FULL_TICK_LIFECYCLE
legion58_actions02: PASS_60297_FIVE_PROFILES_FOUR_ACTIONS
legion58_traffic02: PASS_124141_THREE_LEGIONS_MIRROR_HIDDEN_CONTROL
legion58_hq_attack01: PASS_25_REAL_PROJECTILE_DAMAGE
legion58_requirement_audit: artifacts/legion58/requirements-audit.json
legion58_full_gate: RELEASE03_PASS_23_STAGES_MAIN
legion58_new_package: KIT01_PASS_204_FILES_ISOLATED_BOOT
legion58_package_path: build/playtest-kits/WARSEED-Legion-Movement-20260928.zip
legion58_budget_usd: 600
legion58_HUMAN: USER_REPORTED_MOVEMENT_FAILURE_RETEST_NOT_RUN
legion57_status: HISTORICAL_CANDIDATE_GATE_PASS_SUPERSEDED_BY_D038
legion57_exit_matrix03: PASS_50_OF_50
legion57_exit_matrix03_evidence: artifacts/legion57/exit-matrix03-summary.json
legion57_exit_matrix02: STOPPED_46_PASS_1_FAIL_3_NOT_STARTED
legion57_exit_matrix01: STOPPED_36_PASS_4_FAIL_2_INTERRUPTED_8_NOT_STARTED
legion57_preview_route02: 10_PASS
legion57_escort_loss02: 657386_PASS_CONTROLLED_INJECTION
legion57_attack_matrix03: PASS_50_OF_50
legion57_attack_replay01: EXACT_RESULT_AND_PATH_EQUAL_BOTH_DIRECTIONS
legion57_attack_matrix02: STOPPED_24_PASS_2_FAIL_24_NOT_STARTED
legion57_preview06: 26_PASS
legion57_markers01: 27_PASS
legion57_attack_matrix01: STOPPED_2_PASS_2_FAIL_46_NOT_STARTED
legion57_handoff: GRAPH03_48_PASS_LIFE03_360_PASS_HANDOFF05_18156_PASS
legion57_action_matrix01: STOPPED_30_PASS_2_SCRIPT_FAIL_18_NOT_STARTED
legion57_action_matrix02: PASS_50_OF_50_STANDARD_ATTACK_TO_DEFEND
legion57_retreat_matrix02: PASS_50_OF_50_STANDARD_COMMAND_RETREAT
legion57_retreat_matrix02_evidence: artifacts/legion57/retreat-matrix02-summary.json
legion57_transition_audit: artifacts/legion57/transition-matrix-audit.json
legion57_preview07: 26_PASS_AFTER_RETREAT_FIX
legion57_action_matrix02_evidence: artifacts/legion57/action-matrix02-summary.json
legion57_action_matrix02_scope: CONTROLLED_SOURCE_POSE_LOCAL_EXECUTOR_NOT_FULL_400
legion57_depth_checks: 74964_PASS
legion57_separation_checks: 14_PASS
legion57_unit_suites: SUITE06_18_PASS_BEFORE_RETREAT_FIX
legion57_warnings02: 471_PASS_HEADLESS_2_LOCALES_5_SIZES
legion57_report: docs/LEGION_RAPID_REFORMATION_IMPLEMENTATION_20260927.md
legion57_formal_integration: COMPLETED_BY_LEGION58
legion57_full_gate: RELEASE03_PASS_23_STAGES_CANDIDATE_ONLY
legion57_full_gate_evidence: artifacts/legion57/release03/audit.json
legion57_export_preflight02: INTERRUPTED_NO_TERMINAL_EXIT
legion57_export_preflight03: PASS_EXPORT_AND_ISOLATED_BOOT
legion57_release_export_quit_fix: VERIFIED_IN_RELEASE03
legion57_kit02: PASS_PACKAGE_ZIP_HASH_AND_MANAGED_RUNTIME
legion57_kit02_evidence: artifacts/legion57/kit02-terminal.json
legion57_new_work: RESUMED_IN_LEGION58_WITH_600_USD_CAP
legion57_natural01: INCOMPLETE_TIMEOUT_LAST_LOGGED_TICK_3000
legion57_natural01_evidence: artifacts/legion57/natural01/observation-audit.json
legion57_kit03: PASS_204_MANIFEST_FILES_AND_EXTRACTED_ISOLATED_BOOT
legion57_release01: FAILED_TOOL_ENV_AFTER_15_PASS_STAGES
legion56_design_status: DOCUMENTATION_DONE
legion56_design: docs/LEGION_RAPID_REFORMATION_20260927.md
legion56_document_audit: artifacts/legion56-design/verification.json
legion56_behavior_implementation: NOT_RUN
legion56_gameplay_simulation: NOT_RUN
legion56_formal_integration: NOT_RUN
legion56_HUMAN: NOT_RUN_OPTIONAL
legion55_attempt04_status: INVALID_ARGUMENTS_SCRIPT_ERRORS_TIMEOUT
legion55_attempt04_valid_cases: 0
legion55_attempt04_evidence: artifacts/legion55/attempt04-spear-24-normal/terminal.json
legion55_status: SIMULATED_CANDIDATE_REWORK
legion55_report: docs/LEGION55_TRANSIT_EXIT_MATRIX_20260925.md
legion55_evidence: artifacts/legion55/matrix-summary.json
legion55_candidate: artifacts/legion50/candidate
legion55_cases: 50
legion55_physical_tail_clear: 48_OF_50
legion55_full_exit_pass: 0_OF_50
legion55_spear_24_clear: 0_OF_2
legion55_role_capacity_blocked: 48_OF_50
legion55_execution_errors: 0
legion55_timeouts: 0
legion55_runtime_drift: 0
legion55_main_integration: NOT_RUN
legion55_candidate_full_gate: NOT_RUN
legion55_combat_economy_full_match: NOT_RUN
legion55_HUMAN: NOT_RUN_OPTIONAL
project: WARSEED
current_phase: R5
current_gate: R5_EXIT_ACCEPTED
phase_status: COMPLETE_SIMULATED
release_candidate: R1-FEEDBACK-RC2
release_candidate_status: ENGINEERING_BASELINE_ARCHIVED
release_candidate_package: build/playtest-kits/WARSEED-R1-Feedback-RC2-20260901.zip
release_candidate_sha256: 730B7F496F8871D62CA887F5B955974CF540014F3B5EA9307E6F5D4070C10A08
working_build_id: 0.1.0-legion-movement.20260928
latest_maintenance_work_item: WS-MAINT-20261004-001
latest_maintenance_status: DONE
active_maintenance_work_item: WS-MAINT-20261005-001
active_maintenance_status: VERIFYING
unfinished_maintenance_work_item: WS-MAINT-20260920-001
unfinished_maintenance_status: REWORK
final_decision_status: PERFORMANCE_SLICE_VERIFIED_GOAL_INCOMPLETE
legion31_design_status: DELIVERED_PARTIAL_FIT
legion31_evidence: SIMULATED_PROTOTYPE
legion31_local_scenarios: 564
legion31_production_integration: NOT_RUN
legion32_documentation_status: DONE
legion32_design: docs/LEGION_FORMATION_REVISION_20260923.md
legion32_growth: docs/LEGION_GROWTH_TABLE_20260923.md
legion32_gameplay_verification: NOT_RUN
legion32_production_integration: NOT_RUN
legion32_addendum_status: DONE
legion32_addendum_evidence: artifacts/legion32-addendum/verification.json
current_turn_scope: GITHUB_AUTOMATED_WINDOWS_PLAYTEST_RELEASE
legion54_status: VERIFICATION_TERMINATED_DESIGN_REWORK
legion54_report: docs/LEGION_TRANSIT_ACCEPTANCE_20260925.md
legion54_evidence: artifacts/legion54/verification.json
legion54_candidate: artifacts/legion50/candidate
legion54_candidate_runtime_files: 708
legion54_candidate_test_files: 316
legion54_matrix_cases: 50
legion54_movement_and_queue_pass: 50_OF_50
legion54_physical_tail_clear: 20_OF_50
legion54_full_exit_pass: 0_OF_50
legion54_attack_move_no_enemies: QUEUE_10_OF_10_FULL_EXIT_0_OF_10
legion54_independent_replays: 10_EXACT
legion54_regressions: PASS_9_RUNS_1327565_CHECKS
legion54_rejoin_stress: PASS_37_OF_37_TICK_2296_TWO_EXACT_RUNS
legion54_rejoin_stress_scope: CONTROLLED_REAR_INJECTION_NOT_NATURAL_RECRUITMENT
legion54_verified_runs: 81
legion54_assertion_calls: 94166389
legion54_execution_errors: 0
legion54_matrix_session: TERMINATED_EXIT_1_21873_DESIGN_FAILURE
legion54_regression_session: TERMINATED_EXIT_0_13432
legion54_stress_session: TERMINATED_EXIT_0_94573
legion54_main_runtime_files: 703
legion54_main_runtime_unchanged: true
legion54_main_integration: NOT_RUN
legion54_candidate_full_gate: NOT_RUN
legion54_combat_traffic_natural_match: NOT_RUN_CURRENT_CANDIDATE
legion54_HUMAN: NOT_RUN_OPTIONAL
legion54_initial_exit_probe_scope: HISTORICAL_THREE_2400_TICK_CASES
legion52_scope: HISTORICAL_708_PRE_EXIT_ATTEMPT_CHECKPOINT
legion52_matrix_evidence: artifacts/legion52/matrix03/audit.json
legion52_matrix_pass: QUEUE_50_OF_50_FULL_EXIT_0_OF_50
legion52_matrix_checks: 58811357
legion52_matrix_replays: 10_EXACT
legion52_integrated_evidence: artifacts/legion52/integrated03/audit.json
legion52_integrated_pass: 12_RUNS_1769295_CHECKS_3_EXACT_REPLAYS
legion52_historical_stress: PASS_37_OF_37_TICK_1989_3585741_CHECKS
legion51_scope: HISTORICAL_707_CHECKPOINT_SUPERSEDED_FOR_CURRENT_RESULTS
legion51_status: MATRIX_AUDITED_DESIGN_REWORK
legion51_candidate: artifacts/legion50/candidate
legion51_candidate_files: 707
legion51_evidence: artifacts/legion51/validation-audit.json
legion51_final_receipt: artifacts/legion51/verification.json
legion51_checkpoint: artifacts/legion51/validated-checkpoint
legion51_matrix_sessions: TERMINATED_EXIT_0_58029_30352_DRIVERS_ONLY
legion51_cases: 50
legion51_replays: 20
legion51_matrix_checks: 85970710
legion51_gather_bend_queue_pass: 48_OF_50
legion51_growth_failure: RANGER_36_BOTH_DIRECTIONS_35_OF_36_READY
legion51_complete_exit_pass: 0
legion51_manual_move: FAIL_2_OF_38322_COLLISION_AND_OVERSPEED
legion51_growth_rejoin: FAIL_1_OF_31108_NO_REAR_SLOT
legion51_controls: PASS_40423
legion51_regressions: PASS_392899_203010_145762_137
legion51_mirror_timing: NOT_IDENTICAL_MAX_27_TICKS_RANGER_60
legion51_growth_followup_session: TERMINATED_EXIT_0_41368_DRIVER_ONLY
legion51_growth_failure_replays: 2_EXACT
legion51_growth_extended: FAIL_BOTH_DIRECTIONS_2400_TICKS
legion51_growth_followup_evidence: artifacts/legion51/growth-followup/audit.json
legion51_main_integration: NOT_RUN
legion51_candidate_full_gate: NOT_RUN
legion54_exit_acceptance_status: EXIT_WAIT_REPRODUCED_REWORK
legion54_exit_acceptance_evidence: artifacts/legion50/candidate/artifacts/legion52/exit-acceptance01.json; artifacts/legion50/candidate/artifacts/legion52/exit-acceptance02-mirror.json; artifacts/legion50/candidate/artifacts/legion52/exit-acceptance03-full.json
legion54_exit_acceptance_cases: 3
legion54_exit_acceptance_checks: 5608013
legion54_exit_acceptance_full_exit_pass: 0_OF_3
legion54_exit_acceptance_main_integration: NOT_RUN
legion50_status: EXPERIMENT_COMPLETE_DESIGN_REWORK
legion50_candidate: artifacts/legion50/candidate
legion50_report: docs/LEGION_TRANSIT_IMPLEMENTATION_20260924.md
legion50_evidence: artifacts/legion50/transit-matrix-audit.json
legion50_arrival_checkpoint: artifacts/legion50/arrival-checkpoint/checkpoint-audit.json
legion50_candidate_files: 706
legion50_arrival_contract: HISTORICAL_CHECKPOINT_PASS_392899_EXIT_0_78819
legion50_regressions: HISTORICAL_CHECKPOINT_PASS_203010_145762_137_EXIT_0_45220
legion50_geometry: PASS_17_COMPONENT_ONLY
legion50_physical_narrow_execution: IMPLEMENTED_PARTIAL_6_ENTERED_5_EXIT_WAIT_OF_20
legion50_matrix_session: TERMINATED_EXIT_0_85848_EXPERIMENT_DRIVER_ONLY
legion50_matrix_cases: 20
legion50_replays: 10
legion50_matrix_checks: 27124770
legion50_full_narrow_contract_pass: 0
legion50_all_full_strength_gather: FAILED_10_OF_10
legion50_control_boundary: FAIL_1_OF_35777_STALE_GOAL
legion50_width_boundary: FAIL_1_OF_23243_MISSING_4_TO_3
legion50_exit_expansion: NOT_IMPLEMENTED
legion50_main_integration: NOT_RUN
legion50_candidate_full_gate: NOT_RUN
legion49_status: DONE_SIMULATED_DESIGN_REWORK
legion49_report: docs/LEGION_NARROW_EXECUTOR_VALIDATION_20260924.md
legion49_evidence: artifacts/legion49/verification-aligned.json
legion49_matrix_session: TERMINATED_EXIT_1_1677_DESIGN_FAILURE
legion49_replay_session: TERMINATED_EXIT_1_99048_DESIGN_FAILURE
legion49_cases: 40
legion49_independent_replays: 20
legion49_main_road_completed: 20_OF_20
legion49_narrow_road_completed: 2_OF_20_NOT_FULL_CONTRACT_PASS
legion49_execution_errors: 0
legion49_production_changed: false
legion49_initial_reflection: RETAINED_PERTURBED_START_ONLY
legion48_status: VERIFICATION_DONE_B_REWORK
legion48_focused_session: TERMINATED_EXIT_0_86476
legion48_focused_receipt: artifacts/legion48/checkpoint-audit.json
legion48_runtime_files: 703
legion48_runtime_freeze: artifacts/legion48/runtime-freeze.json
legion48_report: docs/LEGION_SPATIAL_EXECUTION_20260924.md
legion48_release_status: PASS_97571_EXIT_0
legion48_release_seconds: 1670.184
legion48_release_receipt: artifacts/legion48/release-audit.json
legion48_natural_status: TWO_TERMINAL_REPLAYS_AUDITED_NO_COMBAT
legion48_natural_session: TERMINATED_EXIT_0_15192
legion48_natural_checks: 808161
legion48_natural_receipt: artifacts/legion48/natural-audit.json
legion48_natural_gameplay: artifacts/legion48/natural-gameplay-audit.json
legion48_first_natural_tick: 18000
legion48_first_natural_outcome: DRAW_NO_COMBAT_EVENTS
legion48_first_natural_audit: artifacts/legion48/natural0-audit.json
legion48_first_natural_gameplay: artifacts/legion48/natural0-gameplay-audit.json
legion45_status: VERIFICATION_DONE_B_REWORK
legion45_final_receipt: artifacts/legion45/verification.json
legion45_report: docs/LEGION_CORE_COHESION_FIX_20260924.md
legion45_motion_checks: 344
legion45_motion_receipt: artifacts/legion45/motion05.json
legion45_execution01: FAILED_NATURALLY_EXIT_1
legion45_execution02_session: TERMINATED_EXIT_0_57352
legion45_execution_checks: 95041
legion45_runtime_checks: 137
legion45_runtime_freeze: artifacts/legion45/runtime-freeze.json
legion45_runtime_files: 697
legion45_release_status: PASS_93981_WITH_EDITOR_DIAGNOSTIC
legion45_release_seconds: 1648.958
legion45_release_receipt: artifacts/legion45/release-audit.json
legion45_natural_status: PASS_TWO_TERMINAL_REPLAYS_B_REWORK
legion45_natural_checks: 515670
legion45_natural_receipt: artifacts/legion45/natural-audit.json
legion45_cohesion_receipt: artifacts/legion45/cohesion-audit.json
legion45_first_natural_tick: 11558
legion45_first_natural_outcome: DEFEAT
legion45_first_natural_events: 163318
legion45_first_natural_births: 1121
legion45_first_natural_audit: artifacts/legion45/natural0-audit.json
legion45_second_natural_session: TERMINATED_EXIT_0_10528
legion45_rejoin_diagnostic_session: TERMINATED_EXIT_0_7454
legion45_rejoin_cause: artifacts/legion45/rejoin-cause.json
legion45_rejoin_max_path: 9472.564453125
legion45_prefix_evidence: artifacts/legion45/natural-prefix-audit.json
legion45_prefix_status: HISTORICAL_PREFIX_SUPERSEDED_BY_FULL_REPLAY
legion46_status: DONE_SIMULATED_PARTIAL_FIT
legion46_matrix_session: TERMINATED_EXIT_0_52038
legion46_replay_session: TERMINATED_EXIT_0_78759
legion46_cases: 120
legion46_mirror_pairs: 60
legion46_repeat_pairs: 20
legion46_historical_controls: 40
legion46_evidence: artifacts/legion46/verification.json
legion46_report: docs/LEGION_RETREAT_POSITION_FACTORS_20260924.md
legion47_status: DONE_SIMULATED_PARTIAL_FIT
legion47_matrix_session: TERMINATED_EXIT_0_74124
legion47_replay_session: TERMINATED_EXIT_0_42911
legion47_cases: 12
legion47_mirror_pairs: 6
legion47_repeat_pairs: 6
legion47_evidence: artifacts/legion47/verification.json
legion47_report: docs/LEGION_RETREAT_EXTENDED_WINDOW_20260924.md
legion43_status: VERIFICATION_DONE_B_REWORK
legion43_final_receipt: artifacts/legion43/verification.json
legion43_gap_cause: artifacts/legion43/escort-selection-cause.json
legion43_diagnostic_gap: 8284.8076
legion43_report: docs/LEGION_FORMATION_RUNTIME_20260924.md
legion43_runtime_freeze: artifacts/legion43/runtime-freeze.json
legion43_runtime_files: 695
legion43_focused_receipt: artifacts/legion43/focused-audit.json
legion43_protection_checks: 129
legion43_batch_checks: 443154
legion43_execution_checks: 95041
legion43_runtime_checks: 137
legion43_ui_checks: 4071
legion43_release_session: TERMINATED_EXIT_0_28332
legion43_release_status: PASS
legion43_release_seconds: 1638.038
legion43_release_receipt: artifacts/legion43/release-terminal.json
legion43_natural_session: TERMINATED_EXIT_0_56463
legion43_natural_status: PASS_REPLAY_ACCOUNTING_B_REWORK
legion43_natural_checks: 173597
legion43_natural_receipt: artifacts/legion43/natural-audit.json
legion43_full_B_status: NOT_COMPLETE
legion43_first_natural: TERMINAL_6667_TICKS_DEFEAT
legion43_first_natural_events: 70446
legion43_first_natural_births: 592
legion43_first_natural_audit: artifacts/legion43/natural0-audit.json
legion43_sampled_escort_gap_max: 8144.5986
legion43_gap_diagnostic_session: TERMINATED_EXIT_0_38725
legion43_gap_diagnostic01: FAILED_SCRIPT_ABORTED_EXIT_1_28335
legion44_status: DONE_SIMULATED_PARTIAL_FIT
legion44_matrix_session: TERMINATED_EXIT_0_15263
legion44_replay_session: TERMINATED_EXIT_0_7433
legion44_cases: 100
legion44_mirror_pairs: 50
legion44_repeat_pairs: 20
legion44_evidence: artifacts/legion44/verification.json
legion44_report: docs/LEGION_EQUAL_DISTANCE_PURSUIT_20260924.md
legion42_status: DONE_PREPARATION_ONLY
legion42_report: docs/LEGION_STABLE_BATCH_PREPARATION_20260924.md
legion42_evidence: artifacts/legion42/verification.json
legion42_checks_per_run: 443154
legion42_growth_cases: 490
legion42_faction_pairs: 245
legion42_independent_runs: 2
legion42_regressions_fixed: 4
legion42_production_integration: NOT_RUN
legion33_A_status: DONE
legion33_A_receipt: artifacts/legion39/verification-final.json
legion33_B_status: REWORK
legion41_status: DONE_SIMULATED_PROTOTYPE
legion41_design_status: PARTIAL_FIT_REWORK
legion41_report: docs/LEGION_PURSUIT_VALIDATION_20260924.md
legion41_evidence: artifacts/legion41/verification.json
legion41_cases: 80
legion41_mirror_pairs: 40
legion41_repeat_pairs: 28
legion41_matrix_session: TERMINATED_EXIT_0_53504
legion41_protected_session: TERMINATED_EXIT_0_29910
legion41_replay_session: TERMINATED_EXIT_0_1957
legion41_encirclement: NOT_RUN
legion41_dynamic_cutoff: NOT_RUN
legion39_status: DONE
legion39_contract: docs/LEGION_EVENT_ORDER_FIX_20260924.md
legion39_runtime_freeze: artifacts/legion39/runtime-freeze.json
legion39_runtime_changed_files: 1
legion39_event_regression: PASS_600_TICKS_1311_EVENTS
legion39_tactical_regression: PASS
legion39_release_session: TERMINATED_EXIT_0_13016
legion39_release_status: PASS
legion39_release_duration_seconds: 1251.738
legion39_release_receipt: artifacts/legion39/release-terminal.json
legion39_natural_session: TERMINATED_EXIT_0_55194
legion39_natural_status: PASS_TWO_TERMINAL_REPLAYS
legion39_natural_checks: 450262
legion39_natural_failures: 0
legion39_natural_events_per_run: 234717
legion39_natural_state_samples_per_run: 180
legion39_natural_receipt: artifacts/legion39/natural-audit.json
legion39_final_receipt: artifacts/legion39/verification-final.json
legion39_first_natural_status: PASS_INDEPENDENT_AUDIT_18000_TICKS
legion39_first_natural_births: 1549
legion39_first_natural_events: 234717
legion39_prefix_status: HISTORICAL_PREFIX_SUPERSEDED_BY_FULL_REPLAY
legion39_prefix_records: 134710
legion39_prefix_last_event_tick: 10838
legion39_natural_log: artifacts/legion39/natural01.log
legion40_status: DONE_SIMULATED_THREE_LEGION_MERGE
legion40_contract: docs/LEGION_JUNCTION_VALIDATION_20260924.md
legion40_matrix_session: TERMINATED_EXIT_0_63957
legion40_replay_session: TERMINATED_EXIT_0_76682
legion40_cases: 16
legion40_mirror_pairs: 8
legion40_repeat_pairs: 8
legion40_evidence: artifacts/legion40/verification.json
legion40_cyclic_exits: NOT_RUN
legion40_hard_pursuit: SEPARATE_LEGION41_PARTIAL_FIT
legion38_status: SIMULATION_DONE_DESIGN_PARTIAL_FIT_NOT_PRODUCTION
legion38_report: docs/LEGION_FORMATION_VERIFICATION_20260924.md
legion38_evidence: artifacts/legion38/verification-followup.json
legion38_pace_short_checks: 17041
legion38_pace_long_checks: 95041
legion38_pace_long_ticks: 1200
legion38_pace_long_runs: 2
legion38_actual_escort_path_max: 227.2952
legion38_runtime_changed: false
legion38_contract: docs/LEGION_FORMATION_INTEGRATION_20260924.md
legion38_protection_checks: 129
legion38_protection_result: artifacts/legion38/protection-after05.json
legion37_status: DONE_SIMULATED_PROTOTYPE
legion37_design_status: REWORK
legion37_cases: 430
legion37_historical_controls: 210
legion37_repeat_pairs: 13
legion37_hidden_pairs: 20
legion37_evidence: artifacts/legion37/verification.json
legion37_sentinel_evidence: artifacts/legion37/sentinel-verification.json
legion37_contract: docs/LEGION_FORMATION_FACTORS_20260924.md
legion37_factor_session: TERMINATED_EXIT_0_81099
legion37_sentinel_session: TERMINATED_EXIT_0_75305
legion37_sentinel_cases: 30
legion37_sentinel_design: REWORK
legion36_natural_economy_session: TERMINATED_EXIT_1_22908
legion36_natural_economy_status: ACCOUNTING_PASS_EVENT_REPLAY_FAIL
legion36_natural_accounting_audit: artifacts/legion36/natural-accounting-audit.json
legion36_natural_terminal: artifacts/legion36/natural-terminal.json
legion36_natural_checks: 450260
legion36_natural_failures: 1
legion36_natural_first_ticks: 18000
legion36_natural_first_outcome: draw
legion36_natural_first_births: 1549
legion36_natural_first_audit: artifacts/legion36/natural0-audit.json
legion36_natural_report: docs/LEGION_NATURAL_ECONOMY_20260924.md
legion36_growth_table_rows_verified: 245
legion33_status: REWORK
legion33_blocker: none
legion33_contract: docs/LEGION_IMPLEMENTATION_20260923.md
legion33_active_slice: B_FORMATIONS_AND_TRANSIT
legion35_report: docs/LEGION_FIXED_ROSTER_PROGRESS_20260923.md
legion35_atomic_recruitment: PASS_FOCUSED
legion35_growth_births: 480
legion35_release_gate: PASS
legion35_release_gate_duration_seconds: 1090.66
legion35_final_receipt: artifacts/legion35/verification-final.json
legion35_economy_arbitration: REWORK
legion36_status: REWORK
legion36_report: docs/LEGION_ECONOMY_PROGRESS_20260923.md
legion36_economy_focused_checks: 465
legion36_economy_focused_result: PASS
legion36_boundary_checks: 55
legion36_content_checks: 535
legion36_growth_regression_checks: 5123
legion36_live_checks: 159427
legion36_latest_ui: PASS_201_HEADLESS
legion36_release_gate: PASS
legion36_release_gate_duration_seconds: 1234.658
legion36_release_session: TERMINATED_EXIT_0_80957
legion36_release_log: artifacts/legion36/release02.log
legion36_runtime_freeze: artifacts/legion36/runtime-final-freeze.json
legion33_resume_slice: B_FORMATIONS_AND_TRANSIT
legion34_status: REWORK
legion34_simulation_batch_status: DONE
legion34_latest_report: docs/LEGION_FORMATION_VALIDATION_20260923.md
legion34_contract: docs/LEGION_SECOND_SIMULATION_20260923.md
legion34_evidence: SIMULATED_PROTOTYPE
legion34_local_cases: 720
legion34_map_cases: 240
legion34_traffic_fixtures: 9
legion34_defense_ab_cases: 200
legion34_transition_cases: 300
legion34_wide_relief_cases: 36
legion34_narrow_relief_cases: 16
legion34_new_repeat_pairs: 12
legion34_mirror_pairs: 296
legion34_mirror_failures: 0
legion34_result: PARTIAL_FIT
legion34_evidence_audit: PASS
legion34_evidence_audit_receipt: artifacts/legion34/evidence-audit.json
final_decision_package: build/playable/WARSEED-Movement-Escort-20260921.zip
final_decision_package_sha256: B0D00A1914737D203015DB6A04DAC05D48F9F4B738342679D97E9FCA114DCDD6
feedback_build_id: 0.1.0-r1-feedback.2
feedback_schema_version: 1
feedback_collection_status: COMPLETE_SIMULATED
feedback_human_validation_status: OPTIONAL_NOT_RUN
feedback_server_guide: docs/FEEDBACK_SERVER_GUIDE.md
feedback_focus_guide: docs/CURRENT_PLAYTEST_FEEDBACK_FOCUS.md
feedback_release_gate_duration_seconds: 489.325
field_execution_guide: docs/P6_7_FIELD_EXECUTION_CHECKLIST.md
human_evidence_checked_at: 2026-08-20
human_assessment_count: 0
cohort_summary_count: 0
countable_human_session_count: 0
unassigned_raw_session_count: 1
human_validation_policy: OPTIONAL_RESEARCH
human_evidence_required: false
release_human_evidence_required: false
human_validation_debt: CLOSED_BY_D026
human_validation_test_plan: docs/HUMAN_VALIDATION_TEST_PLAN.md
simulated_gate_authorized_at: 2026-08-21
simulated_gate_authority: product_owner_user_message
next_work_item: none
next_work_item_status: none
next_work_item_blocker_kind: none
next_work_item_blocker: none
machine_ready_work_item: none
active_work_item: none
queued_maintenance_work_item: none
queued_maintenance_status: none
expansion_implementation_allowed: false
agent_playbook: docs/AI_AGENT_PLAYBOOK.md
delegation_template: docs/AI_DELEGATION_TEMPLATE.md
low_cost_provider_guide: docs/AI_LOW_COST_PROVIDER.md
preferred_external_text_model: Agents-A1
external_model_qualification: NO_USABLE_FINAL_TEXT_WITHIN_4096_TOKENS
primary_model_budget_usd: 1000
primary_model_billing_source: USER_CONFIRMED_INPUT_10_OUTPUT_50_USD_PER_MILLION
primary_model_budget_enforcement: LOCAL_TOKEN_RECORD_CONSERVATIVE_ESTIMATE
primary_model_implementation_stop_usd: 970
performance_gate_policy: DEFERRED_BY_D028
external_luna_cost_in_budget: false
phase_exit_requires_product_owner: true
r1_engineering_status: COMPLETE
r1_exit_status: ACCEPTED
r1_exit_authorized_at: 2026-09-07
r1_exit_authority: product_owner_user_message
r1_simulated_full_gate: PASS
r1_simulated_full_gate_duration_seconds: 651.775
r1_simulated_verified_at: 2026-08-21
r2_engineering_status: COMPLETE_SIMULATED
r2_exit_status: ACCEPTED
r2_exit_authorized_at: 2026-09-10
r2_exit_authority: product_owner_goal_maintenance_then_R3_R4_R5
r2_simulated_full_gate: PASS
r2_simulated_full_gate_duration_seconds: 1426.714
r2_simulated_verified_at: 2026-09-07
r3_engineering_status: COMPLETE_SIMULATED
r3_exit_status: ACCEPTED
r3_exit_authorized_at: 2026-09-13
r3_exit_authority: product_owner_goal_maintenance_then_R3_R4_R5
r3_simulated_full_gate: PASS
r3_simulated_full_gate_duration_seconds: 686.300
r3_simulated_verified_at: 2026-09-13
r4_engineering_status: COMPLETE_SIMULATED
r4_exit_status: ACCEPTED
r4_exit_authority: USER_CONTINUATION_AND_D029
r4_simulated_full_gate_duration_seconds: 819.106
r4_simulated_verified_at: 2026-09-16
r5_engineering_status: COMPLETE_SIMULATED
r5_exit_status: ACCEPTED
r5_exit_authority: USER_CONTINUATION_R4_R5
r5_simulated_full_gate_duration_seconds: 960.707
r5_simulated_verified_at: 2026-09-16
r5_playable_package: build/playtest-kits/WARSEED-R5-Fix-20260916.zip
r5_playable_package_sha256: 157E561CFD980793F052F730766F2C978EA764A1C6D622EDA103B08ED36D798F
goal_protocol_version: 1.1
gameplay_rework_roadmap: docs/GAMEPLAY_REWORK_ROADMAP.md
recommended_goal_command: "/goal continue"
full_gate_command: >-
  powershell -ExecutionPolicy Bypass -File
  .\tools\verify_grey_ridge_release.ps1
  -GodotConsolePath <godot-console>
documentation_audit: docs/DOCUMENTATION_AUDIT_20260921.md
documentation_slice_status: DONE
```

`release_candidate`、`feedback_*` 和 `working_build_id` 保留历史工程基线含义，当前大地图运行包以 `final_decision_package` 为准。预算记录来自历史授权，不是本轮创建的新目标。

## 2. 已交付基线与当前工作区

| 范围 | 当前事实 |
|---|---|
| 阶段 | R1–R5 已接受；R6/R7 未开始 |
| 最终决战 | 三路、上下野区、26 节点、五兵团；每团 12 士兵开局、60 士兵上限，另有 1 将领；双方满编 610 |
| 战前编成 | 已交付motion29包仍自选配额；工作区A已实现五将固定编制、只读配比和专属侦察，事件排序及重放问题已在legion39闭环，A DONE；新版阵型通行属于B/REWORK |
| 操作 | 战略目标、路线、联合行动与整卡纠正；最终决战仍为 D-036 默认 3/10 秒自动交还 |
| 炮车 | artillery26 单导弹普通攻击、无限弹、20–80、420 射程、无最小射程、2 秒展开；无旧备用炮/识别门/付费压制 |
| 将领 | 每团真实将领，死亡回营与复活；motion29 修复倒放、不可达跟随目标与独立追击干扰；未保证始终紧密成阵 |
| 旧四关 | 灰脊、断桥、雾林、黑井及其卡牌、战术、成长、敌方行动继续保留，不套用最终决战全部规则 |
| 持久化 | 军团 v4，值快照、安全迁移/备份/原子写入；最终决战独立开局，不继承旧关战力 |
| 技术 | Godot 4.6.3 .NET、GDScript 与 .NET 8 C# 表现内核；包内运行时；SimulationWorld 10 Hz |

数值与操作详见[现行玩法](CURRENT_GAMEPLAY.md)，该表描述motion29已交付基线。工作区已有legion33未验收实现，不能将表中基线或候选设计当作当前脏工作区已通过验证的行为；本轮文档补订不改动这些运行文件。

## 3. 活动任务与范围

[WS-MAINT-20260920-001](work_items/WS-MAINT-20260920-001.md) 仍为 REWORK。炮车、性能、motion29 修复和军团 A 已有各自验收；完整 A–D 目标未完成。本轮交付B的legion56快速重整/压缩/部署预览文档；有效出口矩阵仍为legion55的0/50通过。后续依新契约补齐候选行为和模拟，再完成交通、撤退及健康对局验收。文档或模拟记录交付不等于完整B或整个维护项DONE。

当前没有新增 READY 工作项。R6/R7 不自动启动；历史状态中的“唯一下一项 R4-004”等任务指示已经完成，不再领取。

## 4. 产品与工程边界

玩家管目标、风险、时机和资源，将领管执行，整卡是正式手控下限。双方使用同一命令校验和合法知识；typed Resource 与稳定 ID、10 Hz、值快照及安全存档不变。D-026 将 HUMAN 改为可选研究；D-028 暂缓性能通过要求，不取消其他工程门。

旧 60–80 实体门属于四关历史基准；D-030 至 D-037 的最终决战规模另为 610。不能用旧规模覆盖已接受大地图，也不能把一次 610 headless 采样等同实渲达标。

## 5. 游戏验证与版本边界

当前正式主工程仍为 legion48 的 703 文件冻结；专项86476与完整门97571均已终态（完整门1670.184秒，23阶段/严格日志/导出审计通过）。自然15192也已终态，两局18000tick无交战平局，账目和全量重放通过但玩法不通过。最新 legion54 只在独立候选验证，队列50/50、完整出口0/50，九项回归通过；受验范围与下一步见[物理出口验收](LEGION_TRANSIT_ACCEPTANCE_20260925.md)。正式旧门只认证其旧冻结，不能认证新候选或完整B；以下legion45仍为更早检查点。

工作区最新：legion45完整门1648.958秒退出0（保留初始编辑器诊断），两次11558tick完整事件/状态/账目重放通过，515670项零工程断言失败。近处有效护卫被远簇排挤的问题已修复，但本地护卫阵亡后红白九阳独自接近9472.564之外核心，完整B仍REWORK。详细见[本地护卫验证报告](LEGION_CORE_COHESION_FIX_20260924.md)，最终回执artifacts/legion45/verification.json。legion46的120场撤退阵位对照及legion47的12场延长观察均完成，保将改善但高战损与部分失将仍保留。全部本轮验证进程终态；A的legion39验收仍有效但不替代完整B/C/D。以下motion29数据仅属已交付旧包。

motion29 完整发布门 `1082.44s PASS`：两轮 18 套、灰脊完整局及旧关矩阵、公平知识、v4、UI、工具、Windows 导出与独立包检查。详细证据：[移动与随军修复](MOVEMENT_AND_ESCORT_FIX_20260921.md)。本轮文档整理未重跑这些测试。

motion29当时的大地图自主观察为 6000 tick / 10 分钟，在观察上限停止，**非完整局**；59899 次位置检查，无 20 秒持续脱队低净位移窗口。蓝方林墨与最近主力最大距离仍达 2340.439，红方对应为 1230.063；仍在移动不等于始终紧密同行。

610 压力单次 P95/P99/max 为 `27.199/32.798/37.791ms`，11290 次发射；仅 headless CPU，不是 FPS 或 A/B 收益。历史 artillery26/perf27 曾重复 11026 tick 蓝胜，但 motion29 改变权威移动后未以完整局重新确认，不挪用旧局结论。

证据均为 `SIMULATED`；HUMAN 为可选 `NOT_RUN`。当前遵守用户仅无窗口验证限制；当前运行会话以控制块与第11节为准。

## 6. 最新交付

2026-10-04权限契约切片WS-MAINT-20261004-001 DONE：详见[正式契约](PLAYER_AI_CONTROL_CONTRACT_20261004.md)。硬规则优先，同作用域最新有效玩家命令仲裁；整卡接管持续，普通意图恢复后回原目标，强攻不自主撤退，取消转各卡原地坚守，显式交还恢复自治且不复活旧意图。统一入口/队列/应用、值快照、双语UI与公平知识已闭环。release03完整26/26及新专项290项PASS；独立导出PCK权限75/UI141复验PASS，源码1409项无漂移，旧包未覆盖。旧成长探针NOT_PASS及中断门原件保留；真人、实际FPS与本轮自然终局整局未测，父维护仍REWORK。

- ZIP：`build/playable/WARSEED-Movement-Escort-20260921.zip`
- ZIP SHA256：`B0D00A1914737D203015DB6A04DAC05D48F9F4B738342679D97E9FCA114DCDD6`
- PCK SHA256：`4FC90EE4BAF6C1AC4E42450DF1BE6E6FCC8A6E8965440C7649D0C7502B5F7556`
- 回执：`artifacts/motion29-delivery-package.json`；运行冻结：motion29 的 387 文件。
- 旧 perf28 包保留；文档清理不重新打包，不改变旧包证据。

## 7. 待讨论设计

最新修订：[快速重整、空间压缩与移动部署预览](LEGION_RAPID_REFORMATION_20260927.md)。用户允许短时忽略单位碰撞/体积并承受1.5倍伤害、空间不足压缩和手控移动空间指示；文档建议限于友军移动碰撞，保留敌军/地形封锁。候选默认30tick、硬上限60tick、普通间距48/40/32，炮位/保护距离不整体缩放；紧凑档到位容差修正为至多4。数值待模拟，当前只完成文档检查，未修改本轮正式或隔离候选行为。

当前候选入口为[第二版兵团与大地图通行设计](LEGION_FORMATION_REVISION_20260923.md)及[第二版245行成长表](LEGION_GROWTH_TABLE_20260923.md)。明确将领保护、炮组独立展开、白九阳风险退出、窄路批次/会车/交汇/残阵与机动接替；林墨开局1/5/3/3、白九阳4/6/2/0，云岚早期增长重排，满编配比及将领候选参数保持。无战损成长702补给。最初为2026-09-23文档候选，最新隔离模拟见[新版阵型最终模拟报告](LEGION_FORMATION_VALIDATION_20260923.md)；部分通过，不挪用legion31的564场结果证明本版。

本次补订明确96批间净空，61实体均衡六批三列总纵深1728；长窄路方向清空与路口释放分开；出口容量不能重复承诺，循环等候无空间时如实受阻。补齐护炮前卫不追击凑开火率、三种到达状态、默认岗位/核心就绪和702补给的经济时间预算，几何预算属于设计计算；已有通行/接替专项模拟，正式世界行为仍未验收。

[兵团玩法提案](LEGION_GAMEPLAY_PROPOSAL_20260921.md)为建议入口：[四态阵型初稿](COMMANDER_FORMATIONS_DRAFT_20260921.md)提供展开示例，[玩家/AI 权限草案](PLAYER_AI_CONTROL_RULES_DRAFT_20260921.md)提供控制权讨论。2026-09-22用户授权调整候选将领参数并逐步规定增长成本，现有[实验报告](LEGION_BALANCE_LAB_20260922.md)、[245行增长表](LEGION_GROWTH_TABLE_20260922.md)和[逐项结果](LEGION_SIMULATION_RESULTS_20260922.md)。候选已明确，但结论部分符合，未切换正式规则；不声明强攻锁定、专属侦察占点或自动接替已正式实现。

## 8. 当前风险与缺口

- 现有 30 分钟平局上限与历史 20–40 分钟目标冲突，需要产品范围澄清后再改数值。
- 将领固定速度、兵种速度差、长路绕行和分兵仍可能导致脱队；固定阵型需要真实导航与残阵契约。
- 一支野区团需分时覆盖两片野区，机动接替/退出/返回尚缺完整任务约束。
- 优先补员经常暂停机动，未来救援职责与战备要求需共同评估。
- 草案不能覆盖 D-036 控制规则，也不能恢复 D-037 移除的战线覆盖层。
- 旧灰脊低纠正负担指标不能直接证明大地图已达到同样操作目标。

## 9. 历史证据入口

[R4 出口](R4_EXIT_EVIDENCE.md)、[R5 出口](R5_EXIT_EVIDENCE.md)、[历史目录](archive/README.md)、[完整 v109 状态](archive/state/AI_DEVELOPMENT_STATE_v109.md)。45 份完成工作项保存在 `docs/archive/work_items/`；活动 001 留在原路径。

## 10. 最新维护记录

2026-10-04 WS-MAINT-20261004-001 DONE：D-040将权限草案转为正式执行契约；新增typed意图、授权版本、作用范围与值回执，在统一校验/队列/应用入口处理持续将领意图、整卡控制、撤退/取消/交还和旧AI阶段失效。普通目标恢复后回原目标，强攻禁止自主撤退改向，取消各卡原地坚守，显式交还不复活旧任务。双方越权/隐藏扰动/死亡回营/同tick顺序、坚守目标校验和真实终局双语五档UI专项75/74/141共290项PASS；撤退到位防追击、接受不删队列及拒绝接管不抑制合法补员修复后，release03从头完整26/26 PASS、exit0，1441.592秒。实际新PCK权限75/UI141 PASS，与发布记录包哈希一致；源码冻结1409项无漂移、118数据文件未变、无关基线1528项未变。release01/02中断不计通过，旧成长探针NOT_PASS与Windows证书环境诊断保留；证据artifacts/control-contract。旧父001仍REWORK，R6/R7未开始，HUMAN/实际FPS/本轮自然终局整局NOT_RUN，性能D-028暂缓；无提交推送。

2026-09-28 legion62参谋图权限续作：仅修改legion60隔离候选，成功安装参谋计划记录STAFF_PLAN来源，按实际ACTIVE ENGAGE/EXPLOIT分队任务授权，目标/炮位/人数/前卫共用授权身份；暂停、预备队、撤退、接管和终态不借用旧意图。受控grants02 42项、intent07 43项、authority11 46项通过。真实批准live01共274项有1项失败：两场均tick208进入战斗节点，但360tick内炮兵0发、展开人数0，未运行后续移动/撤退抢占断言；旧fingerprint拒绝验证通过。不能把图授权通过当作实际开火通过。review.json仅核对证据完整性，candidate_verified=false；review-v4仍只认证之前冻结。主源码/移动包保持，父001 REWORK、完整目标未完成。下一步先定位真实计划下炮位/射程/目标，后适用回归、正式整合与完整门；C其余职责及D仍待。

2026-09-28 legion61截路撤退补验：真实最终地图、实际蓝红陆铮12人编制各150个生产移动步，双方合法整团撤退均接受；各17名可见敌兵横挡，双方各12成员持续近敌停滞，受控清障后同12成员向原目标缩短距离>24。57243项及独立哈希审计PASS，扫掠敌碰撞/身体地形/0.1秒速度约束通过。主运行源码与natural05冻结一致；无新的运行缺陷。证据仅受控生产移动系统，不是完整world.advance_tick、战斗经济或自动改道；FORMING未细分敌阻挡提示仍为诊断局限。01–03夹具分诊没有各自入口冻结，不认证；04最终冻结/退出0证据保留。主报告见artifacts/legion61/analysis.md，父001/B完整范围及C/D保持未完成。

2026-09-28 legion60驻守接位补验：mirror/intent同步初始卡锚点，避免受控身体与逻辑位置不一致。发现驻守卡无普通移动槽导致迟到炮被跳过，候选允许已授权局部任务创建原执行器使用的槽；迟到炮只能接近同卡已有火力线，不得越线追击。moving12进攻/防守两场23项通过，各7发；对应mirror08/intent06/authority10/guard11/ui07及moving12最终回归通过（14794/43/46/2900/109/23），review-v4哈希核对通过。此前review-v3保留旧冻结通过，不替代这次源码。主工程及移动包未改，父项仍REWORK。

2026-09-28 legion58自然局终态：natural05正常退出0，无源码漂移/错误/超时，原18000tick上限内于11017tick蓝胜；12958发射、93据点易主、984补员、1建筑摧毁及正常结算。独立natural05/independent-audit.json与final-audit-v2.json复核通过，16项当前主源码移动/补验/完整门/包证据一致。900tick完整重放、10满编镜像和三团交通仍有效；单局不替代全局经济账本、所有截路或C/D职责。此前自然局“运行中”记录仅属历史。主工程及移动试玩ZIP不变。

2026-09-28 legion60前卫续作：新增128–192前卫警戒带、跨已展开炮兵的空位重选和边缘候选，guard09八人全部真实就位（2900项）；移动目标20tick重规划与内侧横移选点已实现，moving07实际移动目标/迟到炮最终4发，12项通过。首轮100tick观察未开火，180tick观察中tick116到位、136已开火，不宣称瞬时展开。authority04–07发现受控部署只移身体却未移部分卡锚点；修夹具一致性后authority08为46项，包括真实撤出/双世界重放，原断言未放宽。前卫UI中英tooltip及错误参数109项；最新选点改动后的mirror05/intent05/authority09/ui06/guard10/moving08全部PASS（14778/35/46/109/2900/12项），review-v3核对源码、入口、继承夹具、引擎与结果哈希通过。review-v2仅为历史。参谋图生命周期只读审查已存artifacts/legion60/graph-authority-analysis.md，尚未实现。父001仍REWORK、完整目标active，600美元累计上限不变。

2026-09-28 legion60权限与镜像补验：候选加入typed最后执行来源，实际玩家战略批准可展开，后续普通MOVE不会被残留意图劫持；HOLD恢复、取消/拒绝、阵亡回营与正常AI接续35项通过。双方正常/迟到炮组14778项，原权限30/UI92复验和review-v2.json哈希审计通过；主工程/移动包不变。旧mirror误要求不同ID的随机伤害逐数相等、intent短观察/已生效AI再次提案为空的失败均保留并解释，不改武器数值或放松首tick抢占。任务图只验证受控拥有者抢占，完整图生命周期/前卫警戒/移动目标及其余C/D仍待。natural05会话14603继续，最新9000tick/9576发射/842补员，未终局，完整目标及父001仍active/REWORK。

2026-09-28 legion60隔离权威准备：candidate副本接入炮组typed资源、真实移动/武器、己方值快照和中英UI；runtime07的7331、authority02的30、ui03的92项通过，独立review.json核对最终源码/入口/引擎/结果哈希。迟到炮实际进射程开火，移动/撤退首tick抢占，近敌中断、多目标隔离及受控重放通过；修复同卡迟到炮被过严目标匹配排除，失败原件保留。主工程与移动包零漂移；natural05会话14603继续，最新7000tick/6699发射/710补员，无终局。玩家战略意图授权精确区分、移动目标、前卫警戒及C/D余项未完成，不能正式接入或标整个维护完成。详见[炮组隔离准备](LEGION_ARTILLERY_RUNTIME_PREPARATION_20260928.md)。预算以600美元累计，旧300文字失效。

2026-09-28 legion59隔离准备：主工程继续冻结供natural05运行，最新4000tick/2675发射/541补员，尚未终局。炮组typed参数/稳定A-B状态/合法快照观察器29项通过；白九阳先导槽/战力比/滚动损伤窗口20项通过，均只是纯规划，未接权威或UI。保留首次class cache解析失败与过严替补顺序断言，修复30tick最大生命基线边界；外部脚本与主工程哈希无漂移。四项移动补验新增独立源码/继承脚本/结果哈希审计PASS。详见[职责组件准备](LEGION_ROLE_PREPARATION_20260928.md)，父001仍REWORK、B完整局/C正式实施/D最终验收未完成。

2026-09-28 legion58移动修复：135个候选差异已正式接回主工程，按D-038以可通行为先，解除收列/护卫等待硬门；修正身体导航、出生、玩家目标提前改派、总部落点与碰撞重设。最终移动900tick及完整结果重放各294531项PASS，满编双方窄路10例1297526项PASS，控制49、重叠31、预览26、总部10、提示布局471项PASS。主工程release03完整门23/23阶段通过，kit01的204文件哈希与隔离启动、packed01包内600tick/21项均PASS；新包build/playtest-kits/WARSEED-Legion-Movement-20260928.zip可供验收。natural04已在5400秒墙钟上限超时，最后10000tick/10479发射/896补员，完整局未通过；同源码natural05以18000秒墙钟上限重新运行，规则/游戏时限不变。四态actions02、三团交通traffic02、完整tick生命周期dynamic02和总部真实攻击hq-attack01补验通过，仍未认证C全部职责。仅SIMULATED，真人复验NOT_RUN，性能按D-028，父001仍REWORK；累计预算600美元。最终证据见LEGION_MOVEMENT_REPAIR_20260928.md及artifacts/legion58。以下为历史维护记录，其中“当前/运行中”仅指记录当时。

2026-09-27 legion57续行：当前最新：exit-matrix03普通移动50/50 PASS；attack-matrix02为24 PASS/2 FAIL/24未运行，林墨36人双向清尾后无法展开。修复同批护卫选择及窄将领口袋几何采样后，attack-gunner36-normal02/mirror02双向PASS；attack-matrix03已50/50 PASS，attack-replay01双向独立重放完整JSON与路径哈希一致；后续护卫阵亡/预览包络回归正在补验。预览将领/炮位标记已接入，preview06为26项、markers01为27项PASS。各项仅认证自己的冻结，B/父项保持REWORK，正式接回/完整门NOT_RUN。 证据见artifacts/legion57/exit-matrix03-summary.json、attack-matrix02-summary.json、preview06/terminal.json、markers01/terminal.json。均SIMULATED_CANDIDATE；一次命名mirror01的定向命令漏传--mirror，仅为重复原向失败，不计镜像证据；normal02/mirror02参数已核对。

2026-09-27 legion57出口矩阵主动止损：`artifacts/legion57/exit-matrix01-summary.json`记录50场计划中40场完整终态，36 PASS、4 FAIL（白九阳48/60人双向），2场中止、8场未运行；进程树已主动停止，状态STOPPED_FOR_REWORK。失败场清尾后后排纵深超出可部署地形，标准48/轻压缩40/紧凑32三档局部适配均无解，未完成展开、稳定20tick、出口回执及原目标到达。后续修同角色空间适配并重新冻结复测，不能用36场通过认证完整矩阵。既有contract06、preview03、suite02和定向出口回执仍只认证各自冻结；正式接回、完整门、完整局NOT_RUN，HUMAN可选NOT_RUN。B/父001继续REWORK，C/D未完成。

2026-09-27 legion56-design文档交付：按用户最新原则完成快速重整状态/伤害时序/退出与停止重叠处理、稳定角色分档压缩、窄路出口和96通道释放边界、五将策略及玩家目标空间指示。沿用001，不新增目标、不推进阶段。7份文档经结构/链接/算例及diff检查，正式与候选运行文件相对本轮基线无漂移；证据artifacts/legion56-design/verification.json，游戏机制/模拟/正式整合/完整门NOT_RUN，HUMAN可选未运行。只读收口attempt04：唯一首场参数被拆分，有脚本错误且300秒超时，后续三场未启动；检查时仅有用户主工程编辑器，无候选测试残留。不改变legion55原50场矩阵与失败结论。B/父001继续REWORK，A DONE，C/D未完成；下一步先修驱动并依新设计接入有界重整/伤害/压缩/预览，再分层模拟。

2026-09-25 legion55新版阵型窄路出口矩阵复验：在artifacts/legion50/candidate/以每场独立冻结运行五将×12/24/36/48/60×原向/镜像，共50场。清尾48/50（spear24双向未清尾），完整出口0/50；48场因TRANSIT_EXIT_ROLE_CAPACITY停在phase3，全部未进入角色阵型展开、未产出出口完成回执、未到原任务目标。镜像可配对清尾tick最大差3。每场退出1均为场景验收失败；无脚本错误、超时、源码漂移，约90,705,204项调用含逐tick重复检查。证据artifacts/legion55/matrix-summary.json，报告LEGION55_TRANSIT_EXIT_MATRIX_20260925.md。B继续REWORK；后续先修出口落脚/角色阵位容量与96通道净空，再复测spear24、gunner60及全矩阵。正式接回/完整门/交汇交通/撤退/战斗经济整局仍NOT_RUN，C/D未完成，HUMAN可选未运行，性能按D-028。

2026-09-25 legion54物理出口矩阵与回归收口：仅新增测试、证据与文档，当前候选708运行/316测试及引擎冻结，主703运行零漂移。50移动、10无敌攻击移动、10独立重放、9回归、2归队压力共81次执行/94,166,389项断言调用；重复逐tick断言不是独立战术样本。移动50/50和攻击移动10/10守住移动/队列约束，实际清尾分别20/50和5/10，完整出口均0通过。10重放一致；镜像最大入列差27tick仍保留。9项回归1,327,565项全通过，37人后侧注入压力两次各4,203,425项全通过，2296tick完成；不是自然经济招募。矩阵21873退出1如实保留设计失败，回归13432/压力94573退出0，无脚本错误或超时。出口要求漏算前批纵深，较大编制直推终点外受地形限制；名义EXPAND仍使用窄列目标。640宽阵地形窗口可行，不能把任务终点当窄口或把450剩余路程当出口空间不足。当前报告LEGION_TRANSIT_ACCEPTANCE_20260925.md、总回执artifacts/legion54/verification.json。独立审计亦核对legion52旧冻结/原件与证据，旧手控/弯道/归队失败保留为历史而非当前缺陷。完整B REWORK，正式接回、新完整门、交通/撤退/战斗经济自然局及C/D未完成；HUMAN/原生像素NOT_RUN，性能按D-028。

2026-09-25 legion54新版阵型出口严格验收：仅在候选`artifacts/legion50/candidate/`运行新增`legion54_transit_exit_acceptance.gd`，原向12人、镜像12人、原向60人共3场/5,608,013项检查。连续64包络、96批间净空、将领同批护卫均无失败；但三场均在`EXIT_WAIT`停滞，未进入`EXPAND`、未产生`TRANSIT_EXIT_COMPLETE`、未达到展开稳定20tick。12人后批约7298路径单位停住，60人最终为`TRANSIT_PATH_BLOCKED`；出口几何总长约7202、6752后恢复8列。结论`SIMULATED_CANDIDATE / REWORK`，不能把此前50场收列通过升级为完整出口通过。正式主工程、完整发布门、战斗经济交通、HUMAN与原生像素仍`NOT_RUN`；B继续REWORK。证据保存在候选`artifacts/legion52/exit-acceptance01.json`、`exit-acceptance02-mirror.json`、`exit-acceptance03-full.json`及报告`LEGION_TRANSIT_IMPLEMENTATION_20260924.md`。

2026-09-24 legion51模拟验证收口：同一707候选50场五将五档双向与20独立重放全部终态，58029/30352驱动退出0；独立validation-audit复核85970710项、源码/测试/引擎及全部证据，主703运行/11测试零漂移。48/50通过收列/过弯/排队槽归位，云岚36人双向35/36；41368追加两次原始失败精确重放和两次2400tick延长观察，5717710项，四个子进程均退出1。身份27从600至2400tick采样位置不变，目标与身份8相距约19.16小于24，地形直达合法，弯道目标占用冲突已证实。完整出口展开0通过；手控38322项2失败（碰撞/超速）、补员31108项1失败（无后侧槽）保留；合法改令40423及392899/203010/145762/137回归通过。镜像6组入列时间不同、云岚60最大27tick，不宣称镜像全等。当前差分和受验源码保存validated-checkpoint，本轮未应用修复草稿。主自然15192已退出0，808161项，两局均18000tick平局、各238出生/18906事件；全量事件/物理状态/成长/账目重放一致。独立自然玩法审计两局攻击/伤害/发射/摧毁均0，双方最终179人口、300补给，账目PASS不能作战术成功证据。下一步先修弯道阵位冲突、手控物理和补员归队，再出口/尾队/交通与整体验收；A DONE、B REWORK、C/D及父001未完成。

2026-09-24 legion50真实物理补验完成：同一候选706运行文件、4既有改动/3新增，主703运行/11测试零漂移。初次林墨12人净空69.448925失败，诊断确认准入落后者与弯道前批回移；实际净空准入/相邻双向约束后局部通过，未放宽96。五将12/60双向20场及10独立重放终态，27124770项、原始JSON重放一致，无脚本错误；6入列、5出口等待，全部满编和白/云12人仍收列失败，陆铮双向一过一停，完整出口展开0通过。35777项合法命令边界1失败（旧通行目标未替换），23243项宽度探针1失败（路径928处需3列仍锁4列），原失败全保留。85848退出0只表示驱动完成，场景失败保持退出1。回执artifacts/legion50/transit-matrix-audit.json；历史704检查点另存arrival-checkpoint，不认证新候选。主15192首局18000tick平局，238出生/18906事件/双方179人口300补给，首局完整账目审计通过；独立事件审计确认攻击/伤害/发射/摧毁全0，不能作为战术有效证据。第二局同会话已观察1000tick，继续原进程。下一步同候选先分阶段收列与逐批准入、动态减列/弯道恢复，再修新目标替换和出口展开；正式接回/新完整门/C/D及父001未完成。

2026-09-24 legion50候选实现：主15192自然双局确认仍运行，首局已观察12000tick；保持主703冻结，在artifacts/legion50/candidate复制当前工作工程，两个基线smoke与legion49逐字段一致。候选先修源卡完成后到达节点未消费：实际重整411tick完成，原窄路失败不变；392899项不同目标/新合法命令经真实任务延迟/快照/接管停止边界通过，原203010到达/145762四态/137运行回归通过。新增64连续扫掠包络及局部弯道几何组件17项通过，尚未接通物理收列，不替代legion49失败矩阵。候选704文件仅1既有运行文件变化加1新组件；独立checkpoint审计通过，正式接入/新完整门NOT_RUN。初次测试遗漏任务推进与几何解析错误均保留。下一步在同一候选直接接真实批次/收列/弯道/尾队，续自然15192，不重建副本或重启长局；完整B/C/D及父001保持未完成。

2026-09-24 legion49正式移动系统实际地图补验完成：正常宽阵出发40场、20独立重放、2smoke对照；速度/中心线段/实体间距检查无失败，同方向重放逐字段一致。主路20/20完成；320窄路仅云岚12人双向765/764tick完成且最长停滞23.9秒，其余18场1200tick未完成，最大不可达14人。B仍REWORK。初版夹具左右反射已识别，原40场/20重放降为扰动初阵诊断而非正常控制；重整后炮卡不结束的139620项因果探针保留。正常回执artifacts/legion49/verification-aligned.json，实际退出1是设计失败，不是测试异常。703生产文件未改。legion48完整门97571退出0、1670.184秒、23阶段/日志/导出审计通过；自然15192最新已观察首局7000tick、238出生、双方179人口/300补给，无已报告检查失败但未终态。自然双局继续同一会话；下一实现先解决真实收列/弯道、受阻反馈及到达同步，完整B/C/D与父001不缩减。

2026-09-24 legion48最终七项专项完成：86476实际退出0，motion344/runtime137/actions145762/spatial3414958/arrival203010/UI4451/两次1200tick真实世界95041项全部零失败。1200tick输出逐字段重复，实际护卫路径≤240、十将净位移均≥500；703运行/11测试文件冻结未变，独立checkpoint审计只认证专项，不是全套阵型或发布通过。97571完整门与15192自然双局仍运行，现有日志无ERROR/SCRIPT ERROR；下一步续同一会话到终态再审计完整结果。真实物理批次、窄路收展/会车/交汇/循环退出及C/D仍未完成，父001与完整目标保留。

2026-09-24 legion48最终源码验证已启动：86476前六项motion344/runtime137/actions145762/spatial3414958/arrival203010/UI4451全部退出0，实际双1200tick行军仍在运行（新增每100tick进度记录，当前首局900tick零失败）。完整门97571运行，独立导出build/verification-legion48/WARSEED.exe；自然双局15192运行，新增空间行动/就绪/路径/身份与同tick护卫死亡状态观察。三个真实会话已确认存活，不重复启动。703运行文件与11个测试文件核对无漂移，版本不认证旧legion45证据。完整B仍REWORK，源码在本次验证期间冻结，任何后续修改须新建相应受验版本。

2026-09-24 legion48追加实际位移审查：12/60五团双向20场3414958项、四态/成长/核心损失145762项及双语五档4451项通过。新增两两占位暴露撤退将领随护卫约束一并丢失碰撞；保留距离脱耦但继续物理避让修复后通过，旧motion“约束对象必须null”断言由独立legion48版本改为partner_id=0，原测试/失败不覆盖。到达专项五团均复现“实员到位但卡仍移动”；修复只在实际阵位到达且原卡目标与军团目标一致时发原移动完成回执，不额外吸附、不伪造其他卡目标。arrival-after的203010项通过。因到达缺陷，原76153内长行军进程9072/37232按精确命令匹配主动终止，明确不算完成；原件在final-attempt03。最终703冻结重新生成，86476正运行七项适用专项，完整门/自然双局仍NOT_RUN。完整B/C/D继续，普通宽阵骨架不替代物理分批、窄路收展或协同战术。

2026-09-24 legion48正式士兵阵位执行进入VERIFYING：新增typed空间状态/成员目标，普通卡移动跳过被军团执行器接管的实体，独立单位循环亦避免重复位移。五将常态角色阵位按全60身份预留并包括将领保护空间；撤退保持真实空间关系，成长新身份先到后侧接入，死亡后同tick刷新护卫有效性。无本地核心由远核心返回接应，无任何突击/装甲时通过既有成长Agent申请恢复；不改变费用/将领数值/v4。12与60实际行军20场359158项通过，满编占位/四态/丢核心/成长专项此前66284项通过但后续加入英雄占位断言须重测。失败保留：类型推断解析错误、先后顺序造成旧位置观察、浮点指数区间不同的镜像夹具、满编兵种阵位重叠及云岚将领占位未预留。703文件新冻结、16个运行文件新增/变更；50870正在跑最终适用专项，完整门和自然长局NOT_RUN。完整B真实批次/窄路/交通及C/D仍须完成，不把本轮空间接入标为B验收。契约[空间执行](LEGION_SPATIAL_EXECUTION_20260924.md)，原legion45仅作历史基线。

2026-09-24 legion45最终验证收口：自然10528退出0，两次11558tick蓝方总部被毁、各1121出生/163318事件/115物理状态采样，515670检查零失败；全事件、逐advance摘要、状态/军团观察、账目、成长和逐tick护卫统计均重放一致。独立verify_final.py通过，回执artifacts/legion45/verification.json为VERIFICATION_DONE_B_REWORK，697冻结未变。完整门93981退出0、1648.958秒，但初始editor import一条Android设置诊断保留，复测未复现，不称无错误日志。诊断7454已完成，9472.564远核心独行和9个成阵标签却无活选中护卫tick均保留。legion46/47实验已完成且部分符合，全部本轮测试进程终态。A DONE，B/父001 REWORK，完整目标active；下一步继续B真实四态/稳定物理阵位/集结接应/交通，不再用小规划器或既有短测替代完整执行，也不省略C/D及战术缺口。

2026-09-24 legion45归队定位完成：7454退出0、4450tick、44物理哈希与自然首局一致、187条成员记录。3958本地突击1022阵亡，3959唯一合格核心为远处装甲5367（9472.564），将领240内仍有4名侦察；普通锚点停止、将领单独接近，4440约128距离。独立audit_rejoin_diagnostic.py/回执rejoin-cause.json确认，不是旧密度优先误选；远核心接应/残部共同行动缺口保留。第二局10528仍运行；仅前83677条完整原始事件至7236tick逐行一致，回执PREFIX_ONLY_NOT_FINAL，不算完整确定性。697生产冻结保持，下一步完成同一第二局及完整审计，然后继续B完整执行返工。

2026-09-24 legion47延长撤退观察DONE：74124矩阵/42911独立重放均退出0，12场/6镜像/6重放、29818260项无失败，前600tick逐字段与legion46相同；后600tick无再接触。陆铮/狄天/云岚48人后置一批均在571–621tick脱离，末尾保留16/18人，仍非低损。697运行文件不变。完整门93981退出0但初次editor import有Godot内部Android设置诊断，targeted import60606退出0未复现；原日志和严格审计保留，发布审计为SCRIPT_PASS_WITH_EDITOR_DIAGNOSTIC。首局natural0在11558tick/163318事件/1121出生蓝败并经首局审计；第二次自然10528及白九阳重入诊断7454仍运行，不宣称双局重放通过。详见[延长观察](LEGION_RETREAT_EXTENDED_WINDOW_20260924.md)及[本地护卫修复](LEGION_CORE_COHESION_FIX_20260924.md)。

2026-09-24 legion46初始撤退阵位对照DONE：52038/78759均退出0，120场/60镜像/20独立重放/40历史控制逐字段审计一致；124589728检查无执行失败。24/48人原布局40/40失将，同批靠出口后移30失将/10到位仍接触，后置一批30脱离/4仍接触/6失将；后者24人仅剩6–7士兵，48白九阳两时机及林墨延迟仍失将，不能认作低损或通用修正。原始回执artifacts/legion46/verification.json及报告保留，697生产冻结不变。针对云岚48立即在tick599刚脱离，legion47只延长观察至1200tick，陆铮/狄天/云岚48人×两时机×镜像12场，smoke前600tick逐字段匹配原矩阵；74124矩阵/42911独立6场重放进行中。legion45完整门93981与自然10528继续，完整目标active。

2026-09-24 legion45专项补验通过：execution02会话57352退出0，两次1200tick、95041检查、实际护卫路径最大239.999985，十将净位移5544–14779，原红林墨/红陆铮停滞消失；motion05补真实绕障、路径长度独立超距反例、换护卫/回营清理后344项，runtime02的137项均退出0。697文件冻结，7原生产文件变化及2新文件；完整门93981和逐tick护卫距离分状态观察的自然双局10528运行中，旧43门不可代替。legion46初始站位单因素smoke6场通过、2控制与44历史逐字段一致，正式120场矩阵52038运行中；不改变生产数值/撤退执行。详见本地护卫与撤退阵位报告，B/父001仍REWORK。

2026-09-24 legion45本地护卫与真实移动返工：近处有效旧护卫优先，移除远簇密度优先；双方实际位移增加瞬态typed约束、实际路径240限制和有预算侧步，已接受撤退保持优先。132护卫选择、motion04的334移动/到位/接管专项通过；motion02曾额外吸附超速2失败，execution01自然退出1且95041项中3类失败（路径243.4003、红林墨22.7205/红陆铮258.5545净位移）。失败原件保留，路径/侧步改动后execution02会话57352运行中。runtime01的137项与ui01的4441项为早期通过，移动回归待最终重跑。695旧冻结已改变，本轮新完整门/自然双局NOT_RUN，不能挪用43证据；详见[本地护卫修复](LEGION_CORE_COHESION_FIX_20260924.md)。A DONE、B及父001 REWORK、完整目标active。

2026-09-24 legion43验证收口：28332完整门退出0、1638.038秒PASS；56463自然两局退出0，均6667tick蓝方总部被毁、592出生/70446事件/66物理采样/660军团观察，173597项，完整事件/状态/账目/出生及超距观察均一致。10条超240（蓝陆铮3、红狄天7），不能标B合格。定位38725退出0、4500tick/45物理哈希匹配原局，189条详细观察；4079tick旧护卫仍158.86、最近合格核心72.07、附近10人，远处17人簇把主簇阈值提到11，导致改选8284.81外护卫并追去。停锚点仍允许士兵归旧卡槽的330+超距也保留。回执artifacts/legion43/verification.json状态VERIFICATION_DONE/B_REWORK，原因证据escort-selection-cause.json；无本轮生产变动，695冻结保持。legion44补验完整结束。所有本轮进程终态，HUMAN/原生像素NOT_RUN，完整目标active且父001 REWORK；下一步完成B真实执行返工，不继续以小规划器替代四态和交通。

2026-09-24 legion44补验DONE：同3016撤离距离、固定600tick，五团×五成长阶段×两时机×镜像100场；136196466逐tick/结构检查、50对全字段镜像和20场独立重放通过，15263/7433均退出0。战术只有42场到最终脱离，58场将领阵亡；所有24/48人样本均失将，护卫最近距离仍≤145.06。云岚36延迟撤曾tick208短暂脱离后485失将，故首次3秒停火不能等于持续安全。完整原始结果/哈希/退出及独立verification.json保留，设计PARTIAL_FIT_REWORK。695生产冻结未变；B自然长局护卫脱队仍须修复，循环/截路等缺口未冒充通过。详见[同距离追击](LEGION_EQUAL_DISTANCE_PURSUIT_20260924.md)。

2026-09-24 legion43自然首局6667tick/11分6.7秒权威defeat（蓝方失败），592出生、70446事件，资金/成长/事件文件独立审计通过；不是两局重放通过。660个10秒间隔军团采样发现10条护卫距离>240：红狄天7条、蓝陆铮3条，红狄天4100tick为8144.5986且状态FORMING。短程95041项不能替代长局，B进入REWORK；原始formation-observations-first.json保留。完整门28332与自然第二局56463继续，诊断28335只读复现前4500tick并对比已有每100tick状态哈希。legion44同距离3016/固定600tick的五成长阶段×两时机×镜像100场矩阵15263继续，smoke8场通过，中间成长已出现战术失败；不改受验695文件。

2026-09-24 legion43 B第一接入VERIFYING：权威系统连接护将规划、卡锚点队速与稳定身份计划，值快照仅本阵营可见，UI显示原因/队速；士兵四态与物理批次尚未执行。护将129、身份443154（490状态）、真实两次1200tick执行95041（最大护卫路径227.2952）、命令/生命周期/知识/快照137、中英五档UI4071项通过，独立focused-audit.json核对695运行文件及6测试冻结。新增可见危险晚一tick停止的3项失败已修，窄屏44类裁切失败已修且补HUD高度缓存；原件保留。完整门28332与自然双局56463仍运行，正式源码冻结，不提前标PASS；自然增加每100tick阵型与计划采样，距离仅观察，完整局护将不能由短测保证。B IMPLEMENTING、A DONE、父001 REWORK和完整目标active。下一步完成当前验证，补齐实际四态/通行及战术缺口，详见[权威接入](LEGION_FORMATION_RUNTIME_20260924.md)。

2026-09-24 legion39 A最终验收DONE：同一自然进程55194实际退出0，两次18000tick权威平局、各1549出生/234717事件/180物理采样，450262检查零失败。严格自然审计核对完整原始事件、逐advance_tick摘要、物理采样、全账目和成长里程碑一致；结合新完整门1251.738秒PASS、600tick/战术回归与哈希确认未变的A专项，`verify_final.py`通过，新回执artifacts/legion39/verification-final.json。旧legion36事件失败不改写；A只完成固定编制/成长经济，不证明B/C战斗就绪或默认30分钟平局节奏合格。全部本轮进程已终态，A依赖解除，B READY→DISCOVERY；完整目标与父001仍active/REWORK。

同轮legion42稳定身份/批次准备完成：typed规划用正式己方值快照和固定成长身份，死亡/补亡/归队/手控不全团重排，安全重编才改变批次epoch；新身份在后侧等待接入，不拖住当前核心。首轮443074项通过后追加生命周期反例，443154项发现4类缺陷：异团卡冒占、复活将领无批次却可前进、回营未覆盖、成长解锁倒退；修复后两次独立443154项通过，490组成长/245两侧/实体重编号与输入逆序一致，10将真实开局快照可消费。组件和测试在artifacts/legion42/staging与tests/tools，未被游戏加载；687运行文件仍为legion39最终冻结。详见[稳定批次准备](LEGION_STABLE_BATCH_PREPARATION_20260924.md)，回执artifacts/legion42/verification.json。下一唯一实现为B完整接入，不停留于护将/身份规划；四态、物理通行/交通/手控/UI及适用完整门与长局均须继续。

2026-09-24 legion41动态追击补验DONE：原位置matrix02和靠撤出侧中间批次protected01各40场，含5将×12/60×立即/停3秒×镜像；40对镜像逐字段一致，28项独立重放与原矩阵完全一致，三个进程53504/29910/1957均退出0，无脚本/路径/速度/间距/接触不变量错误。原位置18/40脱离，候选28/40脱离（含镜像，不是胜率）；12人陆铮/狄天保将成功但仅剩5人，林墨两策略仍阵亡，白九阳/云岚有阵亡或到位仍接触。60人立即撤两版均49人脱离，但跨规模目标距离不同，不能归因于单纯兵力优势。保留失败，设计PARTIAL_FIT，报告[追击验证](LEGION_PURSUIT_VALIDATION_20260924.md)，独立核对artifacts/legion41/verification.json。687正式文件保持legion39冻结，本轮仅测试/证据/文档，无新生产功能或发布门。自然55194首局18000tick/1549出生/234717事件已独立审计；第二局前134710条完整落盘事件至10838tick相同，只是前缀。A仍VERIFYING，不重启观察；三出口循环/动态截路包围/白九阳低损清点/侧袭与正式B/C/D保留。HUMAN/像素NOT_RUN，下一步补小编制同距离追击与断后/接应单因素，再续完整整合。

2026-09-24 续行：legion39完整门13016退出0、1251.738秒PASS，独立EXE/PCK及687冻结核对通过；自然两局55194仍运行，最新首局16000tick、1330出生、零已报告失败。当前A VERIFYING，不能以完整门替代最后长局。legion40补齐真实三团同向合流：12/60×四情景×镜像共16场、8对重放通过，matrix02/replay01均退出0；独立核对6664832矩阵检查、8镜像轨迹和放行/到位一致。满编183实体/18批215.2秒完成，停止恢复235.2秒；永久手控和实际出口占满正确受阻。急弯挤压、入口弧长不一致与出口后批超越预约导致的失败全部保留，simple夹具弃用不计有效证据。详见[事件修复](LEGION_EVENT_ORDER_FIX_20260924.md)和[三团合流](LEGION_JUNCTION_VALIDATION_20260924.md)。未证明三出口循环/强敌追击或完整B/C战斗；唯一仍运行的本轮测试为55194，正式受验源码保持冻结。

2026-09-24 legion39正式确定性返工：修复前600tick再次复现361tick双侧侦察卡事件换序；生产TacticalAbilitySystem三处StringName排序改为明确文本序。修复后两次600tick各1311事件完全一致；常规TestTacticalCards加入双插入顺序的完成/光学归属/中断测试，专项通过。新增自然观察逐tick事件摘要、完整原始事件流及100tick单位物理状态摘要，支持独立复核。687运行文件相对legion36仅战术系统1文件改变，新freeze保存legion39。完整门13016和自然两局55194运行中，未通过前不标A DONE；legion40真实三团合流staging模拟准备中，初次类型推断失败已修正，smoke02会话91884。完整目标未完成。

2026-09-24 新版阵型补验完成、整体设计PARTIAL_FIT：新增真实护将距离断言，原两次300tick出现双方狄天/林墨4类失败；仅在测试替身协调卡锚点队速后17041检查通过，延长两次1200tick并逐tick核对真实护卫路径，95041检查通过、最大227.2952，位移与重放均通过。纯规划129项，含新增护卫选择修复。自然会话22908已退出1：两次18000tick、各1549出生、账本/成长/采样一致，450260检查中完整事件指纹1失败，A VERIFYING→REWORK。600tick诊断定位361tick侦察卡事件排序交换，staging改文本序后1311事件重放一致；未正式修复或重跑长局。687生产文件保持冻结。报告[补验结论](LEGION_FORMATION_VERIFICATION_20260924.md)，回执artifacts/legion38/verification-followup.json；不覆盖旧128/1512/430证据，白九阳低损清点/侧袭失败、三团交汇/强追击NOT_RUN保留。全部本轮进程已退出，下一步继续模拟缺口与A排序修复，不标父001/完整目标完成。

2026-09-24 目标续行有效进展：自然经济首局18000tick权威平局，1549出生（480首次成长/1069补亡），双方首次成长各702，十将均曾达到60人。独立按typed槽价格、唯一实体、每固定秒5人、资金账本和里程碑核对通过，报告[自然经济](LEGION_NATURAL_ECONOMY_20260924.md)。第二次同输入重放22908仍活跃，最新9000tick，不能标两局确定性通过或A DONE。B准备明确独立军团执行器边界；staging护将规划使用合法值快照、稳定护卫、20tick保护朝向及独立撤退方向、可达≤240核心路径和途中已知火力检查。预备128项通过，含十将真实开局快照；修复前97项2失败、路径98项1失败与一次解析错误保留。尚未写入正式运行、UI或存档，687生产文件冻结不变；详见[接入契约](LEGION_FORMATION_INTEGRATION_20260924.md)。下一步续同一22908，完成终局重放与A证据汇总后再正式接入B；完整目标未完成，不提交/推送/发布。

2026-09-24 legion37补充模拟DONE、设计REWORK：400防守因素对照+30白九阳预算对照，13对重放、20组隐藏污染通过，210控制样本与历史逐字段相同；进程81099/75305均退出0，无脚本或运动/目标合法性错误。白九阳侧袭仅转向即由10/10撤出退化至0/10，云岚仅压紧将领0/10存活，狄天/林墨单因素保将与组合结果不能互相替代。白九阳固定损失预算满编保留75%但全阶段0/10清场，仍不满足原低损清点要求。报告[因素分离与预算](LEGION_FORMATION_FACTORS_20260924.md)，687生产文件未变，未发布。同步确认legion36完整门release02已退出0、1234.658秒PASS，EXE/PCK哈希与专项核对完成；自然经济22908仍运行，最新第一局13000tick、1181次出生、零已报告错误，非完整局。245行成长表/480实际出生/每方702补给已核对。下一步继续同一自然观察，汇总A证据后再做B/C正式整合；三团真实交汇及强敌动态追击仍待。HUMAN与实渲NOT_RUN，不标父001或完整目标完成。

2026-09-24 legion37补充模拟：用户优先完成新版阵型验证，新增隔离因素对照，400场拆开最近敌人转向与残阵压紧；16场smoke无错误，其中8场控制与历史逐项一致，完整矩阵会话81099运行中。另按运行前冻结阈值做白九阳30场侦察回收/损失预算对照，会话75305；保兵退出不得计清点成功。契约见[补充验证](LEGION_FORMATION_FACTORS_20260924.md)。正式687文件冻结不变，release02会话80957与自然经济两次完整局观察22908继续运行，不重启。上一轮逐人成长表核对已通过245行/480真实出生/702追加费用。A仍VERIFYING，父001及B/C战术仍REWORK；不以新试验覆盖历史负结果。

2026-09-24 legion36继续：新增“预留所有者同秒排入两槽”复现1项真实缺陷，第二槽覆盖第一槽承诺导致重复显示/持有预留。确认进程后终止release01会话69825及其Godot子进程，记录release01-termination.json，不计旧门通过。保留首个已承诺身份后55边界、465经济、5123成长、159427自主回归全部重跑通过；ui02/content03适用行为未改，证据复用明确记录。最终687运行文件重新冻结runtime-final-freeze.json；新完整门release02会话80957运行中。报告与docs入口已同步，不用专项覆盖完整门或A–D其他缺口，父001仍REWORK。

2026-09-23 legion36正式共享经济：上一目标轮完成模拟证据复核与交接校正，本轮继续A权威实现。新增边界35项先复现14失败，再修复已选槽稳定、拒绝冷却不重复冻结、已接受玩家计划/优先级/接管取消自动补员并禁止重排；入队后重算承诺，排空批内不重新分配软预留。最终52边界、465受控经济、5123原子出生回归、201中英五档headless UI、535将领复活/专属侦察占点开火/内容/多兵种恢复通过；两次真实300tick自主159427断言、138实体/双方26补给及事件轨迹一致。无自然满编/完整经济局结论；B/C/D仍待，HUMAN可选未运行。完整门会话69825现正运行release01.log，687文件runtime-final-freeze.json冻结，不改受验生产源码；先完成该门，不重启/不引用旧门。失败夹具、类型错误与修复原件均保留，详情见[共享经济进展](LEGION_ECONOMY_PROGRESS_20260923.md)。A为VERIFYING、父001仍REWORK，不提交/打包交付或推进阶段。

2026-09-23 legion34证据交接复核：遵循用户优先完成新版阵型模拟的要求，复核冻结结果而不重复运行不变实验。1512有效场景、296镜像、12对新增重放、100条防守基线对照及16输入/源码、8结果哈希通过；回执artifacts/legion34/evidence-audit.json。实验DONE，候选仍PARTIAL_FIT/REWORK，白九阳54.2%保留低于60%及通用转向压紧拒收均保留；三团动态交汇/强敌包夹/完整经济局NOT_RUN。仅修改交接文档并新增证据审计脚本，无运行代码修改，不标父目标完成。同步核实legion35 release01已PASS1090.66秒，旧会话42551结束、最终回执存在；legion36接入后的economy08为465项PASS，仅受控收入，新增UI未导入/未验证，边界审查及新完整门待做。下一实现仍为A共享经济，详见实现契约legion36节；B/C/D不省略，HUMAN可选未运行。

2026-09-23 legion35原子补员：上一目标轮仅复核旧证据，按no-progress恢复A实际实现。补员先选合法安全且不重叠的出生位，失败不消耗编号/成员/任务/组织/槽/人口/资金/配额；入队值副本固定身份槽，应用拒绝不伪报成功。新增5123项专项覆盖双方480次出生，每方追加702补给，240对出生镜像、补亡、重建等待及支援争用。镜像失败定位为4×3总部占地偏置，修复中心对称地图占地反射；204导航专项通过。两次300tick自主运行均138实体/双方23补给，160903断言及事件/轨迹重放通过；非完整局。18套回归通过，最终源码完整门release01运行中，尚未发布。经济探针明确复现陆铮连续购买两人先于其他团第一人的双轮违规，共享费用预留未实现；A仍IMPLEMENTING、父001仍REWORK。详情及失败原件见[实现进展](LEGION_FIXED_ROSTER_PROGRESS_20260923.md)，下一步完成双轮仲裁/预留/UI原因，不推进B/C/D或R6/R7。

2026-09-23 legion35：目标续行，上一轮为有效进展。重新核对依赖：legion34未通过项属于B/C阵型与职责策略，不改变A已固定的编制、成长和数值契约，不再把战术返工作为A的全局阻塞。A由BLOCKED→READY→DISCOVERY→CONTRACT→IMPLEMENTING，先闭合typed固定模板、零兵种合法加载、换将携带整套编制、只读兵种数量与真实世界出生检查；再补原子补员、共享仲裁与完整验收。已有脏工作区保留，基线artifacts/legion35/runtime-before.json；此后不能重跑legion34零运行漂移验证器覆盖其历史回执。B/C拒收结论及A–D完整范围保留，尚未新验收，不推进R6/R7。

2026-09-23 legion34最终模拟批次DONE、候选仍REWORK：保留720局部战斗，新增200防守A/B、240含总部占地及地形速度的地图组、300实际收列/撤退/截断等流程、36主路接替、16窄路相向和12对重放；296对镜像指标一致，地图旧4组1tick差异已修复。实际批间96净空与保将240界限通过，满编收列耗时见最终报告。转向压紧组合导致部分将领生存及侦控脱离退化，拒收；白九阳60人清半规模混合守军仍仅54.2%保留，未达60%。v5首轮4个截路输入错误及弯道跨列批距问题已留档，补整批尾部约束后重跑300组。764运行相关文件未改，验证回执artifacts/legion34/v5/verification.json。实验完成不等于设计全绿：真实三团交汇、强敌动态包夹与正式经济/组织/命令/知识/UI/v4/完整局仍NOT_RUN，HUMAN可选未运行。下一步优先解耦核心保护/转向/补位及白九阳损失预算，然后续legion33，不发布、不提交、不推进R6/R7。报告见[新版阵型最终模拟报告](LEGION_FORMATION_VALIDATION_20260923.md)。

2026-09-23 legion34本轮证据交付、设计验证REWORK：720个局部职责/对照场景，另有重复5组、隐藏污染5组、侦察资格5项与护甲3项，均无脚本或速度/路径/目标列表不变量错误。实际地图240组全部通过出口，12,211,772步进无穿障/超速/小于24间距；4组镜像差1tick，未豁免。9组抽象交通夹具8组清空、永久出口封闭不准入，不等同真实拥堵/交汇通过。林墨24–60人对固定24人守军各2/2胜；白九阳半规模清守军10/10胜但满编仅保留54.2%，未达60%目标。764个正式运行相关文件零漂移；新脚本仅测试入口。报告/逐项/输入源码哈希见legion34报告及artifacts/legion34/summary.json，v1/v2失败保留。真实收列/路内接敌/被截退路/跨团接替及完整局、正式经济/命令/UI/存档仍NOT_RUN；HUMAN可选未运行。下一步仍优先补阵型行为验证与已知失败，然后才恢复legion33 A；完整实现目标与父001均未完成，不打包、不提交、不推进R6/R7。

2026-09-23 legion34验证优先：用户明确“先完成新版阵型的模拟验证”，正式A–D实现目标保留，当前先做独立实验，不继续扩展生产代码。契约见[新版模拟](LEGION_SECOND_SIMULATION_20260923.md)。v1发现旧恢复逻辑把宽阵重排为按ID单列、护炮前卫重叠及弯道追尾；源码/日志留档，修正隔离适配后v2扩大验证。新计时区分每个实体穿过出口，不能把尾队仍在路内的到位当清空。当前结果仅SIMULATED_PROTOTYPE，正式经济/命令/UI/存档不由其证明。

2026-09-23 legion33恢复：活动目标续行明确要求按照文档实现并自主验收，上一轮文档补订属于有效进展，不能把仅文档范围继续作为当前实现阻塞。保留完整A–D范围并纳入新增通行/交接契约；A继续IMPLEMENTING。Godot headless editor import01退出0，无SCRIPT ERROR/ERROR；这仅是初步解析证据，不是成长/命令/UI通过。继续补齐原子出生、后勤仲裁、固定编成界面和定向真实世界验收。

2026-09-23 legion32-addendum 文档补订 DONE：以用户当前“先只在文档中完成设计”为准，保留已有legion33未验收源码，不继续实现或运行游戏。延续001，完成DISCOVERY→CONTRACT→IMPLEMENTING→VERIFYING→REVIEWING→DONE的文档切片，补齐长路批次、方向放行、空间容量、交接战备及经济预算。`python artifacts/legion32-addendum/verify_docs.py`与diff检查通过：本轮5份文档修改，245行成长及702/178账目、批次几何和经济算例复核，128份Markdown的328个本地链接及围栏/变更表格检查通过，1199个运行/数据/测试/工具文件零漂移。证据 `artifacts/legion32-addendum/verification.json`，旧回执保留；新行为模拟/正式验收NOT_RUN、HUMAN可选未运行。legion33 A暂BLOCKED于本轮范围，父001仍REWORK，R6/R7不推进。下一步先审阅本版候选，恢复实现时从A切片的解析/加载与完整契约核对开始。

2026-09-23 legion33 DISCOVERY→CONTRACT→IMPLEMENTING：用户已授权第二版全部正式实现和自主验收，覆盖此前仅文档限制。完整目标分为固定成长/成阵通行/职责协同/完整验收依赖序列，当前A活动，其余要求继续保留；契约见[实现记录](LEGION_IMPLEMENTATION_20260923.md)。尚无新功能通过声明，父001仍REWORK，不创建或替换目标。

2026-09-23 legion32 文档切片 DONE，父001仍REWORK。按用户“先只在文档中完成设计”完善四态/核心保护/炮兵展开/侦控脱离与补员，核对现行地图资源、导航刻路和总览图，明确1024/512/320道路与六横向/两纵向/河道连接，补齐窄路列数、批次、友军预约、交汇出口容量、弯道与被截退路。第二版逐人表245行，无战损成本160/156/157/105/124，合计702，免费初始名义价值178。保留第一版参数和失败证据，并标出版本替代关系。机械验证回执 `artifacts/legion32/verification.json`；文档链接/围栏/表格/账目和diff检查通过，1192个正式运行/资源/测试/工具文件无漂移。未运行新游戏模拟、发布门或真人研究，不改变Accepted决策/正式玩法/发行包，不推进R6/R7。下一步仅在获得实现或模拟授权后按第二版第11节做独立验证。

2026-09-22 legion31 设计验证切片交付，父001仍REWORK。五将差异化候选参数、五团开局12→满编60的245行逐人表，无战损合计704补给。隔离headless复用真实战斗/移动/导航系统，完成564场局部场景及5组重复、5组隐藏污染、5项侦察占点资格、3项护甲集火专项。运行无脚本/不变量错误，但职责评价部分失败：林墨36/60人攻击固定守军失败；白九阳正面0/48胜、撤退与清少量守军伤亡高；重装双团偏强。阵位能改善部分生存，普通粗基准不代表优化战术。仅原型修正分离超速，正式运行文件未变；完整大地图、经济/补员/组织/权限/存档整合NOT_RUN，HUMAN可选未执行。本轮没有新发布包，不推进R6/R7。详见实验报告；验证回执 `artifacts/legion31/verification.json`。

2026-09-21 docs30 文档切片 DONE，001 整体仍 REWORK。全面审读原 114 份 docs Markdown，归档 80 份旧设计/报告/发布/完成任务，另保存 v109 全量状态；新增文档入口、现行玩法与修订提案。保留打包工具读取的历史说明原路径，修复其适用范围提示。122 份 Markdown 本地链接与围栏无错误，新入口表格及五组 60/12 编制检查通过；原文遗失 0，81 份归档/快照正文除范围提示和引用路径外无变化。1191 个运行/测试/工具文件零漂移、零新增，git diff --check 通过。两项只读复核后补齐权限边界。未运行新游戏测试，不创建新目标、不推进 R6；证据见[文档审计](DOCUMENTATION_AUDIT_20260921.md)。

## 11. 下一次 AI 接手检查单

> 2026-10-05当前切片WS-MAINT-20261005-001 VERIFYING。先看工作项和GITHUB_RELEASE_GUIDE，以及artifacts/github-release的工具、包、提交/推送和云端结果。用户授权提交全部工程变更及配置标签自动发包；不替用户创建本次版本标签，不把Actions运行中标为通过。游戏逻辑未改，原权限完整门可按相同源码复用；云端须重新生成并验证完整Windows包。原父维护仍REWORK。

> 2026-10-04 WS-MAINT-20261004-001已DONE。先读控制块、工作项、D-040及PLAYER_AI_CONTROL_CONTRACT_20261004；release-audit/package-audit/source-audit记录完整26阶段、新专项290项、实际PCK75/141项PASS与1409项源码无漂移。相同源码与环境无需重复完整门。release01/02已中断，旧成长探针NOT_PASS原件保留，不能改写其结论；旧维护WS-MAINT-20260920-001的其他缺口仍REWORK。下一次只按该父项未完成范围建立/领取受控切片，不自动扩大本项或进入R6/R7；真人研究可选、实际FPS未测，性能仍D-028暂缓。

> legion63交付：D-039默认自由行军，四种阵型仅玩家在将领卡主动配置并显示当前兵力标准宽深；取消常态全团阵位/护卫/批次等待，恢复将领随军，固定文本行数与实际HUD预留高度。模式/路径/布局1291项、实际场景中英五档HUD120项、900tick十将行军288966项及精确重放、控制49、重叠31、炮组开火/抢占66项通过。release03完整门23/23 PASS（1247.61秒）；新ZIP 204文件哈希、独立启动、实际PCK专项1291与行军288966均PASS，包内行军结果与源码重放逐字节一致。126数据文件哈希未变。包build/playtest-kits/WARSEED-Free-Movement-20260928.zip，SHA256 f3cd18ab7c8c5304ddf75eb23b8108e6438164a788d3cb780266b2f717f367c0。切片REVIEWING→完成；父001仍REWORK，其他缺口未完成。全部SIMULATED，真人/实际FPS/本轮自然整局NOT_RUN；无提交推送，用户编辑器保持。详情LEGION_OPTIONAL_FORMATION_20260928.md，审计artifacts/legion63/release-audit.json及package-audit.json。


legion62最终交付：22个炮组差异正式接回，覆盖前备份及旧导出保留；主900tick十将移动294531项、满编双向窄路10例1297526项均与原移动版结果逐字节一致，控制49/重叠31/真实参谋开火及首tick移动撤退抢占110项通过。完整发布门release01 23/23阶段PASS（1503.188秒），新包204文件哈希/独立启动/实际PCK移动21项及炮组110项通过，release-audit.json PASS。ZIP为build/playtest-kits/WARSEED-Legion-Artillery-20260928.zip，SHA256 30d50cea67d4ab2068e78593d9deb4130608783bc78034fbd3fa2f508ee8f80e。九次候选专项和18组测试只作对应源码证据；主natural05终局属于之前Movement版本，不认证新炮兵自然整局。完整父001仍REWORK：导弹在途承诺、白九阳完整侦察占点、巩固、云岚接替返回/路径ETA及更广图生命周期/B动态压力/C-D验收未完成。HUMAN及实际FPS NOT_RUN，性能按D-028。所有本轮测试终态，无运行残留；无提交/推送。

2026-09-28 legion62参谋图权限续作：仅修改legion60隔离候选，成功安装参谋计划记录STAFF_PLAN来源，按实际ACTIVE ENGAGE/EXPLOIT分队任务授权，目标/炮位/人数/前卫共用授权身份；暂停、预备队、撤退、接管和终态不借用旧意图。受控grants02 42项、intent07 43项、authority11 46项通过。真实批准live01共274项有1项失败：两场均tick208进入战斗节点，但360tick内炮兵0发、展开人数0，未运行后续移动/撤退抢占断言；旧fingerprint拒绝验证通过。不能把图授权通过当作实际开火通过。review.json仅核对证据完整性，candidate_verified=false；review-v4仍只认证之前冻结。主源码/移动包保持，父001 REWORK、完整目标未完成。下一步先定位真实计划下炮位/射程/目标，后适用回归、正式整合与完整门；C其余职责及D仍待。


当前最新（legion58，2026-09-28）：用户将累计预算明确扩到600美元，并接受D-038放宽空间规则。135个候选差异路径已接回主工程，覆盖前备份在artifacts/legion58/integration-backup。修复军团等待收列、贴墙路径与64包络不一致、非法出生位置、将领平均中心落在建筑内误拒，以及玩家整团目标600距离提前完成；追加修复第二次将领规划清空碰撞、动态地图对称缓存、合法靠墙端点绕行。最终专项、900tick重放、满编双向窄路10例及主工程完整门23/23阶段通过；新包已生成，204文件哈希、隔离启动及包内600tick移动通过。natural04已5400秒超时，最后10000tick，完整局未通过；见LEGION_MOVEMENT_REPAIR_20260928.md。

旧legion57 release03/kit03是修复前隔离候选证据，不能认证新源码。旧natural01超时且0发射是停滞反例。旧严格240护卫/完整收列/非重叠成阵矩阵已由D-038改变验收契约，不再要求重复完整400；真实移动、敌地阻挡、停止/改令、合法知识、存档、完整门和导出仍必须验证。全部自动结果为SIMULATED；用户再次试玩为HUMAN/NOT_RUN。

1. 先读本控制块、本节、最新维护记录，再按[流程](AI_DEVELOPMENT_WORKFLOW.md)和[目标协议](AI_GOAL_COMMANDS.md)执行。历史只按需追溯。
2. 唯一活动维护仍为 001/REWORK；不新建或替换历史活动目标，不领取已归档任务，不自动进入 R6。
3. 先读 LEGION_MOVEMENT_REPAIR_20260928.md、D-038及最新terminal结果；natural04已超时未终局；natural05已在11017tick正常胜利结束，final-audit-v2复核16行通过。四态/动态交通/生命周期/HQ攻击补验已通过；按requirements-audit.json审查未豁免的B/C/D范围；不重复启动已结束的natural05。C炮组（staging，29项）与侦察（recon-staging，20项）纯规划准备已通过独立外部测试，详见LEGION_ROLE_PREPARATION_20260928.md；仍未接生产，不在长局期间改生产源码；已验证的新包见PLAYABLE_LEGION_MOVEMENT_20260928.md。不要重跑无关历史严格阵型矩阵，不用旧包替代新包。
4. legion60仅隔离副本接入；前卫/移动目标已补，驻守接位修改后六组回归及review-v4全部通过，旧review-v2/v3仅保留历史；见LEGION_ARTILLERY_RUNTIME_PREPARATION_20260928.md。继续补完整图生命周期、截路/导弹承诺及侦察/接替/ETA，不将prototype当正式C验收。延续仅无窗口验证限制；如修改主工程权威行为，按流程验证完整门，并为新版本补足适用完整局证据。
5. 保留 610 内容范围、10 Hz、双方公平知识、当前单导弹与 v4；不以文档中的旧人数、旧武器或旧门禁覆盖现行规则。
6. 任何报告分别标明 SIMULATED、HUMAN 与 NOT_RUN。6000 tick 观察不是完整局，旧构建胜利不是新构建验证。
7. 保护现有脏工作区；不提交、推送、创建分支或删除无关修改。文档切片完成不表示整体维护 DONE。
