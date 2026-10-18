class_name GameHUD
extends CanvasLayer

signal start_requested
signal restart_requested
signal pause_requested
signal sound_requested
signal fullscreen_requested

const INK := Color("e3eeef")
const MUTED := Color("819ca9")
const MINT := Color("79dec4")
const GOLD := Color("f1c475")

var _root: Control
var _score: Label
var _best: Label
var _combo: Label
var _combo_hint: Label
var _formula: Label
var _combo_bar: ColorRect
var _wave: Label
var _wave_bar: ColorRect
var _cleared: Label
var _speed: Label
var _loads: Array[Label] = []
var _ticks: Array[ColorRect] = []
var _pause: Button
var _sound: Button
var _fullscreen: Button
var _fast_hint: Label
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_body: Label
var _overlay_tag: Label
var _overlay_score: Label
var _overlay_primary: Button
var _overlay_secondary: Button
var _overlay_hint: Label
var _overlay_mode: String = "ready"
var _gain: Label
var _gain_time: float = 0.0
var _combo_emphasized: bool = false
var _fast_emphasized: bool = false
var _load_cache := PackedInt32Array([-1, -1, -1, -1, -1, -1])


func _ready() -> void:
	_root = Control.new()
	_root.name = "Interface"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	_root.theme = theme
	add_child(_root)
	_build_header()
	_build_stats()
	_build_capacity()
	_build_footer()
	_gain = _label(_root, "", Vector2(450, 112), Vector2(380, 36), 24, GOLD)
	_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_build_overlay()


func _process(delta: float) -> void:
	_gain_time = maxf(0.0, _gain_time - delta)
	_gain.modulate.a = minf(_gain_time * 3.0, 1.0)
	_gain.position.y = 120.0 - (1.2 - _gain_time) * 16.0


func update_display(data: Dictionary) -> void:
	_score.text = str(data["score"])
	_best.text = "会话最佳   %d" % int(data["best"])
	var combo: int = int(data["combo"])
	_combo.text = "×%d" % maxi(combo, 1)
	if _combo_emphasized != (combo > 1):
		_combo_emphasized = combo > 1
		_combo.add_theme_color_override("font_color", GOLD if _combo_emphasized else MINT)
	_formula.text = "%d × 方块数 × 连续次数" % int(data["points_per_block"])
	_combo_bar.size.x = 192.0 * clampf(float(data["buff"]) / float(data["buff_duration"]), 0.0, 1.0)
	_combo_hint.text = "剩余 %.1f 秒 · 再消除，倍率 +1" % float(data["buff"]) if combo > 0 else "消除同色方块，开启连续窗口"
	_wave.text = "%.1f 秒" % maxf(float(data["wave_time"]), 0.0)
	_wave_bar.size.x = 192.0 * clampf(1.0 - float(data["wave_time"]) / float(data["wave_interval"]), 0.0, 1.0)
	_cleared.text = "已消除  %d 块" % int(data["cleared"])
	_speed.text = "下落速度  %.1f×" % float(data["speed_scale"])
	_pause.disabled = not bool(data["can_pause"])
	if _fast_emphasized != bool(data["fast"]):
		_fast_emphasized = bool(data["fast"])
		_fast_hint.add_theme_color_override("font_color", GOLD if _fast_emphasized else INK)
	for direction: int in range(6):
		var count: int = int(data["loads"][direction])
		if _load_cache[direction] == count:
			continue
		_load_cache[direction] = count
		_loads[direction].text = "%d/10" % count
		for depth: int in range(10):
			_ticks[direction * 10 + depth].color = Color("ef7772") if count >= 8 else MINT
			_ticks[direction * 10 + depth].modulate.a = 0.85 if depth < count else 0.1


func set_sound(enabled: bool) -> void:
	_sound.text = "声音 开" if enabled else "声音 关"


func set_fullscreen(enabled: bool) -> void:
	_fullscreen.text = "F11 窗口" if enabled else "F11 全屏"


func show_gain(points: int, combo: int) -> void:
	_gain.text = "+%d   连续 ×%d" % [points, combo]
	_gain_time = 1.2


func show_overlay(mode: String, score: int = 0, reason: String = "") -> void:
	_overlay_mode = mode
	_overlay.visible = true
	_overlay_score.visible = mode == "game_over"
	_overlay_secondary.visible = mode == "paused"
	if mode == "ready":
		_overlay_tag.text = "六个方向 · 四种颜色 · 一块棋盘"
		_overlay_title.text = "旋转，连接，消除。"
		_overlay_body.text = "转动中心六边形，让至少 3 块同色方块相连。\n不断腾出空间，接住下一波来块。"
		_overlay_primary.text = "开始游戏"
		_overlay_hint.text = "也可按空格开始"
	elif mode == "paused":
		_overlay_tag.text = "稍作停留"
		_overlay_title.text = "已暂停"
		_overlay_body.text = "下落与连续消除倒计时均已暂停。\n准备好后，继续旋转。"
		_overlay_primary.text = "继续游戏"
		_overlay_hint.text = "P / Esc 继续"
	else:
		_overlay_tag.text = "本局结束"
		_overlay_title.text = "再转出一点空间。"
		_overlay_body.text = reason
		_overlay_score.text = str(score)
		_overlay_primary.text = "再来一局"
		_overlay_hint.text = "空格 / R 重新开始"


func hide_overlay() -> void:
	_overlay.visible = false
	_gain_time = 0.0


func _build_header() -> void:
	_label(_root, "HexElim", Vector2(40, 22), Vector2(180, 44), 32, INK)
	_label(_root, "六角消除", Vector2(224, 32), Vector2(140, 28), 15, MUTED)
	_label(_root, "试玩版  /  %s" % ProjectSettings.get_setting("application/config/version"), Vector2(740, 31), Vector2(174, 28), 13, MUTED)
	_fullscreen = _button(_root, "F11 全屏", Vector2(922, 28), Vector2(106, 34), false)
	_fullscreen.pressed.connect(func() -> void: fullscreen_requested.emit())
	_pause = _button(_root, "P 暂停", Vector2(1040, 28), Vector2(94, 34), false)
	_pause.pressed.connect(func() -> void: pause_requested.emit())
	_sound = _button(_root, "声音 开", Vector2(1146, 28), Vector2(94, 34), false)
	_sound.pressed.connect(func() -> void: sound_requested.emit())


func _build_stats() -> void:
	_panel(_root, Vector2(40, 145), Vector2(232, 190))
	_label(_root, "本局得分", Vector2(60, 160), Vector2(190, 28), 15, MUTED)
	_score = _label(_root, "0", Vector2(58, 191), Vector2(200, 72), 48, INK)
	_best = _label(_root, "会话最佳   0", Vector2(60, 274), Vector2(190, 28), 14, MINT)
	_cleared = _label(_root, "已消除  0 块", Vector2(60, 301), Vector2(190, 24), 13, MUTED)
	_panel(_root, Vector2(40, 353), Vector2(232, 137))
	_label(_root, "连续消除", Vector2(60, 369), Vector2(130, 28), 15, MUTED)
	_combo = _label(_root, "×1", Vector2(189, 362), Vector2(62, 42), 30, MINT)
	_formula = _label(_root, "6 × 方块数 × 连续次数", Vector2(60, 404), Vector2(192, 24), 13, INK)
	_combo_bar = _bar(Vector2(60, 439), Vector2(192, 5), GOLD)
	_combo_hint = _label(_root, "", Vector2(60, 453), Vector2(198, 22), 11, MUTED)
	_panel(_root, Vector2(40, 508), Vector2(232, 106))
	_label(_root, "下一波", Vector2(60, 520), Vector2(95, 25), 14, MUTED)
	_wave = _label(_root, "", Vector2(154, 518), Vector2(97, 30), 21, INK)
	_wave.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_bar = _bar(Vector2(60, 558), Vector2(192, 4), MINT)
	_speed = _label(_root, "下落速度  1.0×", Vector2(60, 578), Vector2(192, 22), 12, MUTED)


func _build_capacity() -> void:
	_panel(_root, Vector2(1008, 145), Vector2(232, 274))
	_label(_root, "六边容量", Vector2(1028, 160), Vector2(190, 30), 16, INK)
	_label(_root, "对应棋盘外侧的方向编号", Vector2(1028, 191), Vector2(190, 22), 11, MUTED)
	for direction: int in range(6):
		var y: float = 224.0 + direction * 28.0
		_label(_root, "%02d" % (direction + 1), Vector2(1028, y), Vector2(26, 22), 12, MUTED)
		for depth: int in range(10):
			var tick := ColorRect.new()
			tick.position = Vector2(1063 + depth * 11, y + 8)
			tick.size = Vector2(8, 6)
			tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_root.add_child(tick)
			_ticks.append(tick)
		var load_label := _label(_root, "0/10", Vector2(1180, y), Vector2(42, 22), 11, MUTED)
		_loads.append(load_label)
	_panel(_root, Vector2(1008, 437), Vector2(232, 177))
	_label(_root, "给下一块留个位置", Vector2(1028, 451), Vector2(195, 30), 15, INK)
	var hint := _label(_root, "同边上下、相邻边同层可以连接。\n消除后向中心收拢，可触发连锁。\n每边 10 块，接不住下一块则结束。", Vector2(1028, 490), Vector2(194, 70), 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var colors: Array[Color] = [Color("ef5350"), Color("ffd54f"), Color("66bb6a"), Color("42a5f5")]
	for index: int in range(4):
		var chip := Panel.new()
		chip.position = Vector2(1028 + index * 50, 579)
		chip.size = Vector2(36, 6)
		chip.add_theme_stylebox_override("panel", _style(colors[index], colors[index], 3))
		_root.add_child(chip)


func _build_footer() -> void:
	_panel(_root, Vector2(40, 655), Vector2(1200, 43))
	_label(_root, "A  逆时针", Vector2(140, 661), Vector2(155, 30), 14, INK)
	_label(_root, "D  顺时针", Vector2(338, 661), Vector2(155, 30), 14, INK)
	_fast_hint = _label(_root, "按住 S  加速下落", Vector2(535, 661), Vector2(190, 30), 14, INK)
	_label(_root, "P / Esc  暂停", Vector2(780, 661), Vector2(170, 30), 14, INK)
	_label(_root, "R  重开", Vector2(980, 661), Vector2(90, 30), 14, INK)
	_label(_root, "F11  全屏", Vector2(1100, 661), Vector2(120, 30), 14, INK)


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.025, 0.05, 0.08, 0.82)
	_overlay.size = Vector2(1280, 720)
	_root.add_child(_overlay)
	_panel(_overlay, Vector2(400, 182), Vector2(480, 358))
	_overlay_tag = _label(_overlay, "", Vector2(420, 210), Vector2(440, 26), 13, MINT)
	_overlay_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_title = _label(_overlay, "", Vector2(420, 249), Vector2(440, 48), 29, INK)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body = _label(_overlay, "", Vector2(430, 310), Vector2(420, 59), 13, MUTED)
	_overlay_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay_score = _label(_overlay, "0", Vector2(430, 353), Vector2(420, 57), 42, GOLD)
	_overlay_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_primary = _button(_overlay, "开始游戏", Vector2(522, 421), Vector2(236, 48), true)
	_overlay_primary.pressed.connect(_primary_pressed)
	_overlay_hint = _label(_overlay, "", Vector2(430, 477), Vector2(420, 22), 12, MUTED)
	_overlay_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_secondary = _button(_overlay, "重新开始", Vector2(582, 505), Vector2(116, 25), false)
	_overlay_secondary.pressed.connect(func() -> void: restart_requested.emit())


func _primary_pressed() -> void:
	if _overlay_mode == "paused":
		pause_requested.emit()
	else:
		start_requested.emit()


func _label(parent: Node, text: String, position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _panel(parent: Node, position: Vector2, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = position
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color("101e2b"), Color("253b49"), 14))
	parent.add_child(panel)
	return panel


func _button(parent: Node, text: String, position: Vector2, size: Vector2, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16 if primary else 12)
	button.add_theme_color_override("font_color", Color("0a2829") if primary else INK)
	button.add_theme_stylebox_override("normal", _style(MINT if primary else Color("172c39"), MINT if primary else Color("304b59"), 9))
	button.add_theme_stylebox_override("hover", _style(Color("9aefda") if primary else Color("264654"), MINT, 9))
	button.add_theme_stylebox_override("pressed", _style(Color("5dbba5") if primary else Color("102630"), MINT, 9))
	parent.add_child(button)
	return button


func _bar(position: Vector2, size: Vector2, color: Color) -> ColorRect:
	var background := ColorRect.new()
	background.position = position
	background.size = size
	background.color = Color("233744")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(background)
	var fill := ColorRect.new()
	fill.position = position
	fill.size = Vector2(0, size.y)
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fill)
	return fill


func _style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
