class_name SupportPanel
extends PanelContainer

signal card_decision_requested(kind: int)
var contextual_card_actions: bool = false
var supply_label: Label
var _economy_label: Label
var _plan_toggle: Button
var _plan_box: VBoxContainer
var _plan_reserve: SpinBox
var _plan_rates: Dictionary[StringName, SpinBox] = {}
var _plan_status: Label
var _plan_apply: Button
var _plan_snapshot: WorldSnapshot


@onready var title_label: Label = $Margin/Scroll/Layout/Title
@onready var pair_selector: OptionButton = $Margin/Scroll/Layout/Pair
@onready var recon_button: Button = $Margin/Scroll/Layout/Recon
@onready var fortify_button: Button = $Margin/Scroll/Layout/Fortify
@onready var reinforcement_button: Button = $Margin/Scroll/Layout/Reinforcement
@onready var engineering_button: Button = get_node_or_null("Margin/Scroll/Layout/Engineering") as Button
@onready var fire_support_button: Button = get_node_or_null("Margin/Scroll/Layout/FireSupport") as Button
@onready var rapid_mobility_button: Button = get_node_or_null("Margin/Scroll/Layout/RapidMobility") as Button
@onready var frontline_logistics_button: Button = get_node_or_null("Margin/Scroll/Layout/FrontlineLogistics") as Button
@onready var status_label: Label = $Margin/Scroll/Layout/Status
@onready var intel_title_label: Label = $Margin/Scroll/Layout/IntelTitle
@onready var intel_label: Label = $Margin/Scroll/Layout/Intel

@export var simulation_host: SimulationHost
@export var input_controller: InputController
var _region_pairs: Array = []
var _status_receipt_text: String = ""
var _status_receipt_until_msec: int = 0
var _pending_reinforcement_card_id: StringName
var _pending_reinforcement_before_strength: int = -1

const STATUS_RECEIPT_DURATION_MSEC := 6000


func _ready() -> void:
	var supply_header := Control.new()
	supply_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(supply_header)
	supply_label = Label.new()
	supply_label.name = "Supply"
	supply_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	supply_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	supply_label.add_theme_font_size_override("font_size", 13)
	supply_label.add_theme_color_override("font_color", Color(0.96, 0.78, 0.28))
	supply_header.add_child(supply_label)
	supply_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	supply_label.offset_left = 10
	supply_label.offset_right = -10
	supply_label.offset_top = 8
	supply_label.offset_bottom = 30
	$Margin.add_theme_constant_override("margin_top", 36)
	_resolve_extended_buttons()
	if not recon_button.pressed.is_connected(_request_recon):
		recon_button.pressed.connect(_request_recon)
	if not fortify_button.pressed.is_connected(_request_fortify):
		fortify_button.pressed.connect(_request_fortify)
	if not reinforcement_button.pressed.is_connected(_request_reinforcement):
		reinforcement_button.pressed.connect(_request_reinforcement)
	if engineering_button != null and not engineering_button.pressed.is_connected(_request_engineering_route):
		engineering_button.pressed.connect(_request_engineering_route)
	if fire_support_button != null and not fire_support_button.pressed.is_connected(_request_fire_support):
		fire_support_button.pressed.connect(_request_fire_support)
	if rapid_mobility_button != null and not rapid_mobility_button.pressed.is_connected(_request_rapid_mobility):
		rapid_mobility_button.pressed.connect(_request_rapid_mobility)
	if frontline_logistics_button != null and not frontline_logistics_button.pressed.is_connected(_request_frontline_logistics):
		frontline_logistics_button.pressed.connect(_request_frontline_logistics)
	refresh_locale()


func configure(host: SimulationHost) -> void:
	_resolve_extended_buttons()
	simulation_host = host
	_status_receipt_text = ""
	_status_receipt_until_msec = 0
	_pending_reinforcement_card_id = &""
	_pending_reinforcement_before_strength = -1
	_rebuild_region_pairs()
	refresh_locale()


func refresh_locale() -> void:
	if title_label == null:
		return
	title_label.text = GameText.t(&"SUPPORT_PANEL_TITLE")
	_rebuild_pair_labels()
	recon_button.text = GameText.t(&"SUPPORT_AIR_RECON")
	fortify_button.text = GameText.t(&"SUPPORT_FORTIFY")
	reinforcement_button.text = GameText.t(&"SUPPORT_REINFORCEMENT")
	if engineering_button != null:
		engineering_button.text = GameText.t(&"SUPPORT_ENGINEERING_ROUTE")
	if fire_support_button != null:
		fire_support_button.text = GameText.t(&"SUPPORT_FIRE_SUPPORT")
	if rapid_mobility_button != null:
		rapid_mobility_button.text = GameText.t(&"SUPPORT_RAPID_MOBILITY")
	if frontline_logistics_button != null:
		frontline_logistics_button.text = GameText.t(&"SUPPORT_FRONTLINE_LOGISTICS")
	status_label.text = GameText.t(&"SUPPORT_READY")
	intel_title_label.text = GameText.t(&"INTEL_CARDINAL_TITLE")
	if simulation_host != null and simulation_host.current_snapshot != null:
		update_snapshot(simulation_host.current_snapshot)


func update_snapshot(snapshot: WorldSnapshot) -> void:
	if snapshot == null or simulation_host == null:
		return
	var faction := snapshot.get_faction(SimulationWorld.LOCAL_PLAYER_ID)
	if supply_label != null:
		supply_label.text = GameText.t(&"SUPPORT_SUPPLY_BALANCE") % [faction.supply if faction != null else 0, faction.supply_capacity if faction != null else 0]
	if simulation_host.get_battle_definition() != null and simulation_host.get_battle_definition().growth_mode:
		_update_growth_support(snapshot)
		return
	var affordable := faction != null and faction.supply >= SimulationWorld.SUPPORT_COST
	var recon_cooldown := maxi(0, faction.air_recon_cooldown_until_tick - snapshot.tick) if faction != null else 0
	var fortify_cooldown := _generic_cooldown(faction, SupportOrderCommand.SupportKind.EMERGENCY_FORTIFY, snapshot.tick)
	var reinforcement_cooldown := _generic_cooldown(faction, SupportOrderCommand.SupportKind.FIELD_REINFORCEMENT, snapshot.tick)
	recon_button.disabled = not affordable or recon_cooldown > 0
	var selected_card := snapshot.get_unit_card(input_controller.selected_unit_card_id) if input_controller != null else null
	_update_pending_reinforcement_receipt(snapshot)
	fortify_button.disabled = not affordable or fortify_cooldown > 0 or selected_card == null or selected_card.deployment_state != UnitCardState.DeploymentState.DEPLOYED or selected_card.fortified_ticks_remaining > 0
	reinforcement_button.disabled = not affordable or reinforcement_cooldown > 0 or selected_card == null or selected_card.deployment_state != UnitCardState.DeploymentState.DEPLOYED or selected_card.current_strength >= selected_card.authorized_strength or faction == null or faction.population >= faction.population_capacity
	var routes := simulation_host.get_battle_definition().engineering_routes if simulation_host.get_battle_definition() != null else []
	var engineer_selected := selected_card != null and selected_card.deployment_state == UnitCardState.DeploymentState.DEPLOYED and selected_card.has_active_unit_type(&"engineer_vehicle")
	var route_available := not routes.is_empty() and not simulation_host.world.opened_engineering_routes.has(routes[0].route_id)
	if engineering_button != null:
		engineering_button.visible = not routes.is_empty()
		engineering_button.disabled = not affordable or not engineer_selected or not route_available
	var fire_definition := simulation_host.get_support_definition(SupportOrderCommand.SupportKind.FIRE_SUPPORT)
	var mobility_definition := simulation_host.get_support_definition(SupportOrderCommand.SupportKind.RAPID_MOBILITY)
	var logistics_definition := simulation_host.get_support_definition(SupportOrderCommand.SupportKind.FRONTLINE_LOGISTICS)
	var fire_cooldown := _generic_cooldown(faction, SupportOrderCommand.SupportKind.FIRE_SUPPORT, snapshot.tick)
	var mobility_cooldown := _generic_cooldown(faction, SupportOrderCommand.SupportKind.RAPID_MOBILITY, snapshot.tick)
	var logistics_cooldown := _generic_cooldown(faction, SupportOrderCommand.SupportKind.FRONTLINE_LOGISTICS, snapshot.tick)
	var logistics_needed := selected_card != null and (selected_card.organization_enabled and selected_card.organization < 100.0 or selected_card.current_strength < selected_card.authorized_strength)
	if fire_support_button != null:
		fire_support_button.visible = fire_definition != null
		fire_support_button.disabled = fire_definition == null or faction == null or faction.supply < fire_definition.supply_cost or fire_cooldown > 0 or _region_pairs.is_empty()
		fire_support_button.tooltip_text = GameText.t(&"SUPPORT_FIRE_SUPPORT_TOOLTIP")
	if rapid_mobility_button != null:
		rapid_mobility_button.visible = mobility_definition != null
		rapid_mobility_button.disabled = mobility_definition == null or faction == null or faction.supply < mobility_definition.supply_cost or mobility_cooldown > 0 or selected_card == null or selected_card.deployment_state != UnitCardState.DeploymentState.DEPLOYED
		rapid_mobility_button.tooltip_text = GameText.t(&"SUPPORT_RAPID_MOBILITY_TOOLTIP")
	if frontline_logistics_button != null:
		frontline_logistics_button.visible = logistics_definition != null
		frontline_logistics_button.disabled = logistics_definition == null or faction == null or faction.supply < logistics_definition.supply_cost or logistics_cooldown > 0 or selected_card == null or selected_card.deployment_state != UnitCardState.DeploymentState.DEPLOYED or not logistics_needed
		frontline_logistics_button.tooltip_text = GameText.t(&"SUPPORT_FRONTLINE_LOGISTICS_TOOLTIP")
	recon_button.tooltip_text = _recon_tooltip(affordable, recon_cooldown)
	fortify_button.tooltip_text = _fortify_tooltip(affordable, fortify_cooldown, selected_card)
	reinforcement_button.tooltip_text = _reinforcement_tooltip(affordable, reinforcement_cooldown, selected_card, faction)
	var reinforcement_title := GameText.t(&"SUPPORT_REINFORCEMENT")
	if selected_card != null and selected_card.deployment_state == UnitCardState.DeploymentState.DEPLOYED:
		reinforcement_title = GameText.t(&"SUPPORT_REINFORCEMENT_SELECTED") % [selected_card.current_strength, selected_card.authorized_strength]
	var status_text := GameText.t(&"SUPPORT_USAGE_GUIDE")
	if not affordable:
		status_text += "\n" + GameText.t(&"SUPPORT_NEEDS_SUPPLY") % SimulationWorld.SUPPORT_COST
	elif selected_card == null or selected_card.deployment_state != UnitCardState.DeploymentState.DEPLOYED:
		status_text += "\n" + GameText.t(&"SUPPORT_SELECT_CARD_GUIDE")
	if recon_cooldown > 0 or fortify_cooldown > 0 or reinforcement_cooldown > 0:
		status_text += "\n" + GameText.t(&"SUPPORT_COOLDOWN_STATUS") % [
			ceili(recon_cooldown * SimulationWorld.TICK_SECONDS),
			ceili(fortify_cooldown * SimulationWorld.TICK_SECONDS),
			ceili(reinforcement_cooldown * SimulationWorld.TICK_SECONDS),
		]
	if not _status_receipt_text.is_empty() and Time.get_ticks_msec() <= _status_receipt_until_msec:
		status_text = "%s\n%s" % [_status_receipt_text, status_text]
	elif Time.get_ticks_msec() > _status_receipt_until_msec:
		_status_receipt_text = ""
	if contextual_card_actions:
		# These entries open a faction-wide list, independently of the selected card.
		_update_contextual_entry(fortify_button, fortify_cooldown)
		_update_contextual_entry(reinforcement_button, reinforcement_cooldown)
		_update_contextual_entry(engineering_button, 0)
		_update_contextual_entry(rapid_mobility_button, mobility_cooldown)
		_update_contextual_entry(frontline_logistics_button, logistics_cooldown)
		reinforcement_title = GameText.t(&"CARD_ACTION_REINFORCE")
		status_text = GameText.t(&"CARD_DECISION_SUPPORT_GUIDE")
	status_label.text = status_text
	_update_cooldown_label(recon_button, &"SUPPORT_AIR_RECON", recon_cooldown)
	_update_cooldown_label(fortify_button, &"CARD_ACTION_FORTIFY" if contextual_card_actions else &"SUPPORT_FORTIFY", fortify_cooldown)
	_update_cooldown_label(reinforcement_button, &"", reinforcement_cooldown, reinforcement_title)
	_update_cooldown_label(engineering_button, &"CARD_ACTION_ENGINEERING" if contextual_card_actions else &"SUPPORT_ENGINEERING_ROUTE", -1)
	_update_cooldown_label(fire_support_button, &"SUPPORT_FIRE_SUPPORT", fire_cooldown)
	_update_cooldown_label(rapid_mobility_button, &"CARD_ACTION_MOBILITY" if contextual_card_actions else &"SUPPORT_RAPID_MOBILITY", mobility_cooldown)
	_update_cooldown_label(frontline_logistics_button, &"CARD_ACTION_LOGISTICS" if contextual_card_actions else &"SUPPORT_FRONTLINE_LOGISTICS", logistics_cooldown)
	var battle := simulation_host.get_battle_definition()
	var automatic := battle != null and battle.automatic_reinforcement
	reinforcement_button.visible = not automatic
	if automatic and faction != null:
		status_label.text = GameText.t(&"AUTO_LOGISTICS_SUMMARY") % [faction.population, faction.population_capacity, battle.reinforcement_supply_reserve]
	var lines: Array[String] = []
	var active_reports: Array[IntelReportSnapshot] = []
	for report in snapshot.intel_reports:
		if not report.superseded:
			active_reports.append(report)
	var first_index := maxi(0, active_reports.size() - 3)
	for index in range(first_index, active_reports.size()):
		var report := active_reports[index]
		var region := snapshot.get_strategic_region(report.region_id)
		var region_name := GameText.t(region.display_name_key) if region != null else String(report.region_id)
		var age_seconds := floori(report.age_ticks * SimulationWorld.TICK_SECONDS)
		var line := ""
		if not report.has_estimate:
			line = GameText.t(&"INTEL_REPORT_UNKNOWN_LINE") % [
				region_name, GameText.t(report.source_key), age_seconds, GameText.t(report.confidence_key),
			]
		else:
			line = GameText.t(&"INTEL_REPORT_LINE") % [
				region_name, GameText.t(report.source_key), age_seconds,
				GameText.t(report.target_category_key), report.estimated_min, report.estimated_max,
				GameText.t(report.direction_key), GameText.t(report.confidence_key),
			]
		var eta_text := _eta_text(report)
		var conflict_text := GameText.t(&"INTEL_CONTRADICTION") if report.contradictory else ""
		line += GameText.t(&"INTEL_REPORT_META") % [eta_text, GameText.t(report.freshness_key), conflict_text]
		lines.append(line)
	intel_label.text = "\n".join(lines)


func _update_cooldown_label(button: Button, title_key: StringName, remaining_ticks: int, title_override: String = "") -> void:
	if button == null:
		return
	var title := title_override if title_key.is_empty() else GameText.t(title_key)
	var cooldown := GameText.t(&"SUPPORT_COOLDOWN_READY")
	if remaining_ticks < 0:
		cooldown = GameText.t(&"SUPPORT_COOLDOWN_NONE")
	elif remaining_ticks > 0:
		cooldown = GameText.t(&"SUPPORT_COOLDOWN_REMAINING") % ceili(remaining_ticks * SimulationWorld.TICK_SECONDS)
	button.text = title + "\n" + cooldown
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, 48.0)


func _generic_cooldown(faction: FactionSnapshot, support_kind: int, tick: int) -> int:
	return maxi(0, CardActionProjector.cooldown_until(faction, support_kind) - tick) if faction != null else 0


func _update_contextual_entry(button: Button, cooldown_ticks: int) -> void:
	if button == null:
		return
	button.disabled = cooldown_ticks > 0
	button.tooltip_text = GameText.t(&"SUPPORT_DISABLED_COOLDOWN") % ceili(cooldown_ticks * SimulationWorld.TICK_SECONDS) if cooldown_ticks > 0 else GameText.t(&"CARD_DECISION_OPEN")


func _resolve_extended_buttons() -> void:
	fire_support_button = get_node_or_null("Margin/Scroll/Layout/FireSupport") as Button
	rapid_mobility_button = get_node_or_null("Margin/Scroll/Layout/RapidMobility") as Button
	frontline_logistics_button = get_node_or_null("Margin/Scroll/Layout/FrontlineLogistics") as Button


func _recon_tooltip(affordable: bool, cooldown_ticks: int) -> String:
	if not affordable:
		return GameText.t(&"SUPPORT_DISABLED_SUPPLY") % SimulationWorld.SUPPORT_COST
	if cooldown_ticks > 0:
		return GameText.t(&"SUPPORT_DISABLED_COOLDOWN") % ceili(cooldown_ticks * SimulationWorld.TICK_SECONDS)
	return GameText.t(&"SUPPORT_RECON_TOOLTIP")


func _fortify_tooltip(affordable: bool, cooldown_ticks: int, selected_card: UnitCardSnapshot) -> String:
	if not affordable:
		return GameText.t(&"SUPPORT_DISABLED_SUPPLY") % SimulationWorld.SUPPORT_COST
	if cooldown_ticks > 0:
		return GameText.t(&"SUPPORT_DISABLED_COOLDOWN") % ceili(cooldown_ticks * SimulationWorld.TICK_SECONDS)
	if selected_card == null or selected_card.deployment_state != UnitCardState.DeploymentState.DEPLOYED:
		return GameText.t(&"SUPPORT_SELECT_CARD")
	if selected_card.fortified_ticks_remaining > 0:
		return GameText.t(&"SUPPORT_DISABLED_FORTIFIED")
	return GameText.t(&"SUPPORT_FORTIFY_TOOLTIP")


func _reinforcement_tooltip(affordable: bool, cooldown_ticks: int, selected_card: UnitCardSnapshot, faction: FactionSnapshot) -> String:
	if not affordable:
		return GameText.t(&"SUPPORT_DISABLED_SUPPLY") % SimulationWorld.SUPPORT_COST
	if cooldown_ticks > 0:
		return GameText.t(&"SUPPORT_DISABLED_COOLDOWN") % ceili(cooldown_ticks * SimulationWorld.TICK_SECONDS)
	if selected_card == null or selected_card.deployment_state != UnitCardState.DeploymentState.DEPLOYED:
		return GameText.t(&"SUPPORT_SELECT_DAMAGED_CARD")
	if selected_card.current_strength >= selected_card.authorized_strength:
		return GameText.t(&"SUPPORT_DISABLED_FULL_STRENGTH")
	if faction == null or faction.population >= faction.population_capacity:
		return GameText.t(&"SUPPORT_DISABLED_POPULATION")
	return GameText.t(&"SUPPORT_REINFORCEMENT_TOOLTIP") % [selected_card.current_strength, selected_card.authorized_strength]


func _eta_text(report: IntelReportSnapshot) -> String:
	if report.eta_max_ticks < 0:
		return GameText.t(&"INTEL_ETA_UNKNOWN")
	if report.eta_max_ticks == 0:
		return GameText.t(&"INTEL_ETA_CURRENT")
	var min_seconds := ceili(report.eta_min_ticks * SimulationWorld.TICK_SECONDS)
	var max_seconds := ceili(report.eta_max_ticks * SimulationWorld.TICK_SECONDS)
	return GameText.t(&"INTEL_ETA_RANGE") % [min_seconds, max_seconds]


func _request_recon() -> void:
	if _begin_area_targeting(SupportOrderCommand.SupportKind.AIR_RECON):
		return
	if simulation_host == null or _region_pairs.is_empty():
		return
	var selected_index := clampi(pair_selector.selected, 0, _region_pairs.size() - 1)
	var pair: Array = _region_pairs[selected_index]
	var first: StringName = pair[0]
	var second: StringName = pair[1]
	var result := simulation_host.submit_command(simulation_host.create_support_order_command(
		SupportOrderCommand.SupportKind.AIR_RECON, first, second
	))
	status_label.text = GameText.t(&"SUPPORT_RESULT") % GameText.command_result(result)


func _rebuild_region_pairs() -> void:
	_region_pairs.clear()
	if simulation_host == null or simulation_host.get_battle_definition() == null:
		return
	var seen: Dictionary = {}
	for region in simulation_host.get_battle_definition().strategic_regions:
		for adjacent_id in region.adjacent_region_ids:
			var ids: Array[StringName] = [region.region_id, adjacent_id]
			ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
			var key := "%s:%s" % [ids[0], ids[1]]
			if seen.has(key):
				continue
			seen[key] = true
			_region_pairs.append([ids[0], ids[1]])
	_rebuild_pair_labels()


func _rebuild_pair_labels() -> void:
	if pair_selector == null:
		return
	pair_selector.clear()
	var region_by_id := simulation_host.get_battle_definition().region_dictionary() if simulation_host != null and simulation_host.get_battle_definition() != null else {}
	for pair_variant in _region_pairs:
		var pair: Array = pair_variant
		var first := region_by_id.get(pair[0]) as BattleRegionDefinition
		var second := region_by_id.get(pair[1]) as BattleRegionDefinition
		var first_name := GameText.t(first.display_name_key) if first != null else String(pair[0])
		var second_name := GameText.t(second.display_name_key) if second != null else String(pair[1])
		pair_selector.add_item("%s + %s" % [first_name, second_name])
	pair_selector.disabled = _region_pairs.is_empty()


func _request_fortify() -> void:
	if contextual_card_actions:
		card_decision_requested.emit(SupportOrderCommand.SupportKind.EMERGENCY_FORTIFY)
		return
	if simulation_host == null or input_controller == null or input_controller.selected_unit_card_id.is_empty():
		status_label.text = GameText.t(&"SUPPORT_SELECT_CARD")
		return
	var result := simulation_host.submit_command(simulation_host.create_support_order_command(
		SupportOrderCommand.SupportKind.EMERGENCY_FORTIFY,
		&"", &"", input_controller.selected_unit_card_id
	))
	status_label.text = GameText.t(&"SUPPORT_RESULT") % GameText.command_result(result)


func _request_reinforcement() -> void:
	if contextual_card_actions:
		card_decision_requested.emit(SupportOrderCommand.SupportKind.FIELD_REINFORCEMENT)
		return
	if simulation_host == null or input_controller == null or input_controller.selected_unit_card_id.is_empty():
		_set_status_receipt(GameText.t(&"SUPPORT_SELECT_DAMAGED_CARD"))
		status_label.text = _status_receipt_text
		return
	var snapshot := simulation_host.current_snapshot
	var selected_card := snapshot.get_unit_card(input_controller.selected_unit_card_id) if snapshot != null else null
	var faction := snapshot.get_faction(SimulationWorld.LOCAL_PLAYER_ID) if snapshot != null else null
	var before_strength := selected_card.current_strength if selected_card != null else 0
	var missing_strength := maxi(0, selected_card.authorized_strength - before_strength) if selected_card != null else 0
	var population_room := maxi(0, faction.population_capacity - faction.population) if faction != null else 0
	var definition := simulation_host.get_support_definition(SupportOrderCommand.SupportKind.FIELD_REINFORCEMENT)
	var configured_strength := definition.strength if definition != null else SimulationWorld.FIELD_REINFORCEMENT_STRENGTH
	var expected_reinforcement := mini(configured_strength, mini(missing_strength, population_room))
	var result := simulation_host.submit_command(simulation_host.create_support_order_command(
		SupportOrderCommand.SupportKind.FIELD_REINFORCEMENT,
		&"", &"", input_controller.selected_unit_card_id
	))
	if result != null and result.is_accepted() and selected_card != null:
		_pending_reinforcement_card_id = selected_card.definition_id
		_pending_reinforcement_before_strength = before_strength
		_set_status_receipt(GameText.t(&"SUPPORT_REINFORCEMENT_QUEUED") % [
			GameText.t(selected_card.display_name_key), expected_reinforcement,
			before_strength, mini(selected_card.authorized_strength, before_strength + expected_reinforcement),
			selected_card.authorized_strength,
		])
	else:
		_set_status_receipt(GameText.t(&"SUPPORT_RESULT") % GameText.command_result(result))
	status_label.text = _status_receipt_text


func _update_pending_reinforcement_receipt(snapshot: WorldSnapshot) -> void:
	if _pending_reinforcement_card_id.is_empty() or _pending_reinforcement_before_strength < 0:
		return
	var card := snapshot.get_unit_card(_pending_reinforcement_card_id)
	if card == null or card.current_strength <= _pending_reinforcement_before_strength:
		return
	var added_strength := card.current_strength - _pending_reinforcement_before_strength
	_set_status_receipt(GameText.t(&"SUPPORT_REINFORCEMENT_APPLIED") % [
		GameText.t(card.display_name_key), added_strength, card.current_strength, card.authorized_strength,
	])
	_pending_reinforcement_card_id = &""
	_pending_reinforcement_before_strength = -1


func _set_status_receipt(text: String) -> void:
	_status_receipt_text = text
	_status_receipt_until_msec = Time.get_ticks_msec() + STATUS_RECEIPT_DURATION_MSEC


func _request_engineering_route() -> void:
	if contextual_card_actions:
		card_decision_requested.emit(SupportOrderCommand.SupportKind.ENGINEERING_ROUTE)
		return
	if simulation_host == null or input_controller == null or input_controller.selected_unit_card_id.is_empty():
		status_label.text = GameText.t(&"SUPPORT_SELECT_ENGINEER")
		return
	var battle := simulation_host.get_battle_definition()
	if battle == null or battle.engineering_routes.is_empty():
		return
	var route := battle.engineering_routes[0]
	var result := simulation_host.submit_command(simulation_host.create_support_order_command(
		SupportOrderCommand.SupportKind.ENGINEERING_ROUTE,
		route.route_id, &"", input_controller.selected_unit_card_id
	))
	status_label.text = GameText.t(&"SUPPORT_RESULT") % GameText.command_result(result)


func _request_fire_support() -> void:
	if _begin_area_targeting(SupportOrderCommand.SupportKind.MISSILE_BARRAGE):
			return
	if simulation_host == null or _region_pairs.is_empty():
		return
	var pair: Array = _region_pairs[clampi(pair_selector.selected, 0, _region_pairs.size() - 1)]
	var result := simulation_host.submit_command(simulation_host.create_support_order_command(
		SupportOrderCommand.SupportKind.FIRE_SUPPORT, pair[0]
	))
	status_label.text = GameText.t(&"SUPPORT_RESULT") % GameText.command_result(result)


func _request_rapid_mobility() -> void:
	_request_card_support(SupportOrderCommand.SupportKind.RAPID_MOBILITY)


func _request_frontline_logistics() -> void:
	if _begin_area_targeting(SupportOrderCommand.SupportKind.FIELD_HOSPITAL):
			return
	_request_card_support(SupportOrderCommand.SupportKind.FRONTLINE_LOGISTICS)


func _request_card_support(kind: int) -> void:
	if contextual_card_actions:
		card_decision_requested.emit(kind)
		return
	if simulation_host == null or input_controller == null or input_controller.selected_unit_card_id.is_empty():
		status_label.text = GameText.t(&"SUPPORT_SELECT_CARD")
		return
	var result := simulation_host.submit_command(simulation_host.create_support_order_command(
		kind, &"", &"", input_controller.selected_unit_card_id
	))
	status_label.text = GameText.t(&"SUPPORT_RESULT") % GameText.command_result(result)


func _begin_area_targeting(kind: SupportOrderCommand.SupportKind) -> bool:
	if simulation_host == null or simulation_host.get_battle_definition() == null or not simulation_host.get_battle_definition().growth_mode:
		return false
	if input_controller != null:
		input_controller.begin_area_support_targeting(kind)
		status_label.text = GameText.t(&"AREA_SUPPORT_TARGETING")
	return true


func _update_growth_support(snapshot: WorldSnapshot) -> void:
	_update_recruitment_plan(snapshot)
	for control in [pair_selector, fortify_button, reinforcement_button, engineering_button, rapid_mobility_button, intel_title_label, intel_label]:
		if control != null:
			control.visible = false
	var faction := snapshot.get_faction(snapshot.observer_faction_id)
	var buttons := [recon_button, fire_support_button, frontline_logistics_button]
	var kinds := [SupportOrderCommand.SupportKind.AIR_RECON, SupportOrderCommand.SupportKind.MISSILE_BARRAGE, SupportOrderCommand.SupportKind.FIELD_HOSPITAL]
	var names: Array[StringName] = [&"AREA_RECON_CARD", &"AREA_MISSILE_CARD", &"AREA_HOSPITAL_CARD"]
	var help: Array[StringName] = [&"AREA_RECON_HELP", &"AREA_MISSILE_HELP", &"AREA_HOSPITAL_HELP"]
	for index in range(buttons.size()):
		var button := buttons[index] as Button
		if button == null:
			continue
		var definition := simulation_host.get_support_definition(kinds[index])
		button.visible = definition != null
		if definition == null:
			continue
		var cooldown := _generic_cooldown(faction, kinds[index], snapshot.tick)
		button.disabled = faction == null or simulation_host.get_available_support_supply() < definition.supply_cost or cooldown > 0
		_update_cooldown_label(button, &"", cooldown, GameText.t(names[index]) + " · " + str(definition.supply_cost))
		button.tooltip_text = GameText.t(help[index])
	status_label.text = GameText.t(&"AREA_SUPPORT_TARGETING") if input_controller != null and input_controller.command_mode == InputController.CommandMode.AREA_SUPPORT_TARGETING else GameText.t(&"GROWTH_LOGISTICS_HELP")

func _update_recruitment_plan(snapshot: WorldSnapshot) -> void:
	_plan_snapshot = snapshot
	var faction := snapshot.get_faction(snapshot.observer_faction_id)
	if faction == null: return
	if _economy_label == null:
		var layout := $Margin/Scroll/Layout
		_economy_label = Label.new()
		_economy_label.name = "GrowthEconomy"
		_economy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_economy_label.add_theme_font_size_override("font_size", 11)
		layout.add_child(_economy_label)
		layout.move_child(_economy_label, 0)
		_plan_toggle = Button.new()
		_plan_toggle.name = "RecruitmentPlanToggle"
		_plan_toggle.toggle_mode = true
		_plan_toggle.clip_text = true
		layout.add_child(_plan_toggle)
		layout.move_child(_plan_toggle, 1)
		_plan_box = VBoxContainer.new()
		_plan_box.visible = false
		layout.add_child(_plan_box)
		layout.move_child(_plan_box, 2)
		_plan_toggle.toggled.connect(func(enabled: bool) -> void:
			_plan_box.visible = enabled
			if enabled: _load_recruitment_plan())
		var reserve_label := Label.new()
		reserve_label.name = "ReserveLabel"
		reserve_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_plan_box.add_child(reserve_label)
		_plan_reserve = SpinBox.new()
		_plan_reserve.name = "ReserveSupply"
		_plan_reserve.min_value = 0
		_plan_reserve.max_value = faction.supply_capacity
		_plan_reserve.step = 1
		_plan_box.add_child(_plan_reserve)
		for commander in snapshot.commanders:
			if commander.faction_id != snapshot.observer_faction_id: continue
			var row := HBoxContainer.new()
			var label := Label.new()
			label.text = GameText.t(commander.display_name_key)
			label.name = "Name"
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.clip_text = true
			row.name = String(commander.definition_id)
			row.add_child(label)
			var rate := SpinBox.new()
			rate.name = "Rate"
			rate.min_value = 0
			rate.max_value = 2
			rate.step = 1
			row.add_child(rate)
			_plan_box.add_child(row)
			_plan_rates[commander.definition_id] = rate
		_plan_apply = Button.new()
		_plan_apply.name = "ApplyRecruitmentPlan"
		_plan_apply.pressed.connect(_apply_recruitment_plan)
		_plan_box.add_child(_plan_apply)
		_plan_status = Label.new()
		_plan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_plan_status.add_theme_font_size_override("font_size", 11)
		_plan_box.add_child(_plan_status)
	_plan_toggle.text = GameText.t(&"GROWTH_PLAN_OPEN")
	_plan_box.get_node("ReserveLabel").text = GameText.t(&"GROWTH_PLAN_RESERVE")
	_plan_apply.text = GameText.t(&"GROWTH_PLAN_APPLY")
	for id in _plan_rates:
		_plan_rates[id].get_parent().get_node("Name").text = GameText.t(snapshot.get_commander(id).display_name_key)
	var income := 0.0
	var battle := simulation_host.get_battle_definition()
	income += float(battle.base_supply_amount) * 10.0 / battle.base_supply_interval_ticks
	for region in snapshot.strategic_regions:
		if region.capturable and region.controller_faction_id == faction.faction_id and not region.contested:
			income += float(region.supply_per_settlement) * 10.0 / battle.region_settlement_interval_ticks
	_economy_label.text = GameText.t(&"GROWTH_ECONOMY_RATE") % [income, faction.previous_recruitment_spend, faction.previous_support_spend, faction.recruitment_reserve]
	_economy_label.tooltip_text = GameText.t(&"GROWTH_INCOME_HELP")
	var reservation := faction.recruitment_arbitration
	if not reservation.reserved_commander_id.is_empty():
		var saving_commander := snapshot.get_commander(reservation.reserved_commander_id)
		if saving_commander != null:
			_economy_label.text += "\n" + GameText.t(saving_commander.display_name_key) + " · " + GameText.t(&"GROWTH_SAVING_DETAIL") % [reservation.reserved_amount, reservation.reserved_cost]
		_economy_label.tooltip_text += "\n" + GameText.t(&"GROWTH_SAVING_HELP")
	for effect in snapshot.area_support_effects:
		if effect.faction_id == faction.faction_id and effect.support_kind == SupportOrderCommand.SupportKind.MISSILE_BARRAGE:
			_economy_label.text += "\n" + GameText.t(&"AREA_MISSILE_IMPACT" if effect.executed else &"AREA_MISSILE_WARNING")

func _load_recruitment_plan() -> void:
	var faction := _plan_snapshot.get_faction(_plan_snapshot.observer_faction_id)
	_plan_reserve.set_value_no_signal(faction.recruitment_reserve)
	for id in _plan_rates:
		_plan_rates[id].set_value_no_signal(faction.recruitment_rates.get(id, 2 if id == faction.priority_commander_id else 1))
	_plan_status.text = GameText.t(&"GROWTH_PLAN_HELP")

func _apply_recruitment_plan() -> void:
	var ids: Array[StringName] = []
	var rates: Array[int] = []
	var total := 0
	for id in _plan_rates:
		ids.append(id)
		rates.append(int(_plan_rates[id].value))
		total += int(_plan_rates[id].value)
	if total > 5:
		_plan_status.text = GameText.t(&"GROWTH_PLAN_OVER_LIMIT")
		return
	var command := simulation_host.create_recruitment_plan_command(ids, rates, int(_plan_reserve.value))
	var result := simulation_host.submit_command(command)
	_plan_status.text = GameText.command_result(result)
