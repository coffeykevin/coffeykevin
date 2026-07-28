class_name Hud
extends CanvasLayer
## The concept HUD: weather+time label top-left, and the full-width charcoal
## control bar — PLAYER 1 · POWER · WIND · ANGLE · PLAYER 2 — with typed
## entry on both meters (the 1991 ritual, kept sacred). Title, debrief, and
## match-end overlays included.

signal power_changed(v: float)
signal angle_changed(v: float)
signal mode_picked(vs_ai: bool)
signal rematch()

const YELLOW := Color("ffc93c")
const CYAN := Color("35c4f0")
const CHARCOAL := Color(0.11, 0.125, 0.15, 0.94)

var _updating := false
var power_slider: HSlider
var angle_slider: HSlider
var power_edit: LineEdit
var angle_edit: LineEdit
var power_val: Label
var angle_val: Label
var wind_label: Label
var wx_cond: Label
var wx_time: Label
var banner: Label
var p1_name: Label
var p2_name: Label
var p1_pips: Label
var p2_pips: Label
var debrief_panel: PanelContainer
var debrief_text: RichTextLabel
var title_panel: Control
var end_panel: Control
var end_label: Label


func _ready() -> void:
	_build_bar()
	_build_labels()
	_build_debrief()
	_build_title()
	_build_end()


func _panel_style(radius := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CHARCOAL
	s.set_corner_radius_all(radius)
	s.border_width_top = 1
	s.border_color = Color(1, 1, 1, 0.08)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	return s


func _label(txt: String, size: int, col := Color.WHITE, bold := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _build_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _panel_style(12))
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = 16.0
	bar.offset_right = -16.0
	bar.offset_top = -92.0
	bar.offset_bottom = -14.0
	add_child(bar)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	bar.add_child(h)

	# Player 1
	var p1 := VBoxContainer.new()
	p1_name = _label("KILO", 20, YELLOW)
	p1_pips = _label("● ○ ○", 12, YELLOW)
	p1.add_child(p1_name)
	p1.add_child(p1_pips)
	h.add_child(p1)

	# POWER group
	power_val = _label("68", 30, Color.WHITE)
	h.add_child(power_val)
	var pw := VBoxContainer.new()
	pw.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw.add_child(_label("POWER", 11, YELLOW))
	power_slider = HSlider.new()
	power_slider.min_value = 1
	power_slider.max_value = 100
	power_slider.value = 68
	power_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pw.add_child(power_slider)
	power_edit = LineEdit.new()
	power_edit.text = "68"
	power_edit.custom_minimum_size = Vector2(64, 0)
	pw.add_child(power_edit)
	h.add_child(pw)

	# WIND center
	wind_label = _label("WIND  ➡  23 MPH", 20, Color.WHITE)
	wind_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	h.add_child(wind_label)

	# ANGLE group
	var ag := VBoxContainer.new()
	ag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ag.add_child(_label("ANGLE", 11, CYAN))
	angle_slider = HSlider.new()
	angle_slider.min_value = 0
	angle_slider.max_value = 90
	angle_slider.value = 42
	angle_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ag.add_child(angle_slider)
	angle_edit = LineEdit.new()
	angle_edit.text = "42"
	angle_edit.custom_minimum_size = Vector2(64, 0)
	ag.add_child(angle_edit)
	h.add_child(ag)
	angle_val = _label("42°", 30, Color.WHITE)
	h.add_child(angle_val)

	# Player 2
	var p2 := VBoxContainer.new()
	p2_name = _label("NEWTON", 20, CYAN)
	p2_pips = _label("○ ○ ○", 12, CYAN)
	p2.add_child(p2_name)
	p2.add_child(p2_pips)
	h.add_child(p2)

	power_slider.value_changed.connect(_on_power_slider)
	angle_slider.value_changed.connect(_on_angle_slider)
	power_edit.text_submitted.connect(_on_power_typed)
	angle_edit.text_submitted.connect(_on_angle_typed)


func _build_labels() -> void:
	var wx := VBoxContainer.new()
	wx.anchor_left = 0.0
	wx.anchor_top = 0.0
	wx.offset_left = 20.0
	wx.offset_top = 14.0
	wx_cond = _label("SUNSET", 20, Color.WHITE)
	wx_time = _label("7:45 PM", 13, Color(1, 1, 1, 0.8))
	wx.add_child(wx_cond)
	wx.add_child(wx_time)
	add_child(wx)

	banner = _label("", 22, Color.WHITE)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.anchor_top = 0.0
	banner.offset_top = 16.0
	banner.offset_left = -300.0
	banner.offset_right = 300.0
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(banner)


func _build_debrief() -> void:
	debrief_panel = PanelContainer.new()
	debrief_panel.add_theme_stylebox_override("panel", _panel_style(10))
	debrief_panel.anchor_left = 0.0
	debrief_panel.anchor_top = 1.0
	debrief_panel.anchor_bottom = 1.0
	debrief_panel.offset_left = 16.0
	debrief_panel.offset_top = -320.0
	debrief_panel.offset_bottom = -104.0
	debrief_panel.custom_minimum_size = Vector2(300, 0)
	debrief_text = RichTextLabel.new()
	debrief_text.bbcode_enabled = true
	debrief_text.fit_content = true
	debrief_text.custom_minimum_size = Vector2(280, 190)
	debrief_panel.add_child(debrief_text)
	debrief_panel.visible = false
	add_child(debrief_panel)


func _build_title() -> void:
	title_panel = _overlay()
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	var t := _label("BANANARC", 64, YELLOW)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label("ANGLE · POWER · BANANAS", 16, Color(1, 1, 1, 0.8))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var b1 := Button.new()
	b1.text = "  Hot-Seat Duel (2 players)  "
	b1.custom_minimum_size = Vector2(320, 44)
	b1.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b1.pressed.connect(func() -> void: mode_picked.emit(false))
	v.add_child(b1)
	var b2 := Button.new()
	b2.text = "  Solo vs. Newton (AI)  "
	b2.custom_minimum_size = Vector2(320, 44)
	b2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b2.pressed.connect(func() -> void: mode_picked.emit(true))
	v.add_child(b2)
	var hint := _label("Aim with the meters or type exact numbers.\nEnter, Space, or click your gorilla to throw.", 13, Color(1, 1, 1, 0.6))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	title_panel.add_child(v)


func _build_end() -> void:
	end_panel = _overlay()
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	end_label = _label("KILO WINS THE MATCH", 40, YELLOW)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(end_label)
	var b := Button.new()
	b.text = "  Rematch  "
	b.custom_minimum_size = Vector2(240, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: rematch.emit())
	v.add_child(b)
	end_panel.add_child(v)
	end_panel.visible = false


func _overlay() -> Control:
	var c := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.04, 0.06, 0.82)
	c.add_theme_stylebox_override("panel", s)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c


# ---- sync helpers -----------------------------------------------------------

func _on_power_slider(v: float) -> void:
	if _updating:
		return
	_set_power_widgets(v)
	power_changed.emit(v)


func _on_angle_slider(v: float) -> void:
	if _updating:
		return
	_set_angle_widgets(v)
	angle_changed.emit(v)


func _on_power_typed(t: String) -> void:
	var v := clampf(t.to_float(), 1.0, 100.0)
	set_power(v)
	power_changed.emit(v)


func _on_angle_typed(t: String) -> void:
	var v := clampf(t.to_float(), 0.0, 90.0)
	set_angle(v)
	angle_changed.emit(v)


func _set_power_widgets(v: float) -> void:
	power_val.text = str(int(round(v)))
	power_edit.text = str(int(round(v)))


func _set_angle_widgets(v: float) -> void:
	angle_val.text = "%d°" % int(round(v))
	angle_edit.text = str(int(round(v)))


func set_power(v: float) -> void:
	_updating = true
	power_slider.value = v
	_set_power_widgets(v)
	_updating = false


func set_angle(v: float) -> void:
	_updating = true
	angle_slider.value = v
	_set_angle_widgets(v)
	_updating = false


func set_wind(w: float) -> void:
	var arrow := "➡" if w >= 0.0 else "⬅"
	wind_label.text = "WIND  %s  %d MPH" % [arrow, Sim.wind_mph(w)]


func set_weather(cond: Dictionary) -> void:
	wx_cond.text = cond["name"]
	wx_time.text = cond["time"]


func set_scores(a: int, b: int, to_win: int) -> void:
	p1_pips.text = _pips(a, to_win)
	p2_pips.text = _pips(b, to_win)


func _pips(n: int, total: int) -> String:
	var out := ""
	for i in range(total):
		out += "● " if i < n else "○ "
	return out.strip_edges()


func set_turn(msg: String, col: Color) -> void:
	banner.text = msg
	banner.add_theme_color_override("font_color", col)


func show_debrief(d: Dictionary) -> void:
	var drift: float = d["drift"]
	var arrow := "⟶" if drift >= 0.0 else "⟵"
	debrief_text.text = (
		"[b][color=#%s]● %s[/color][/b]   THROW %d\n\n" % [d["accent"], d["who"], d["n"]]
		+ "Angle	[b]%d°[/b]\n" % d["angle"]
		+ "Power	[b]%d[/b]\n" % d["power"]
		+ "Flight	[b]%.1f s[/b]\n" % d["time"]
		+ "Apex	[b]%d m[/b]\n" % int(d["apex"])
		+ "Distance	[b]%d m[/b]\n" % int(d["dist"])
		+ "[color=#35c4f0]Wind drift	[b]%+d m %s[/b][/color]\n\n" % [int(round(drift)), arrow]
		+ "[color=#888888]%s[/color]" % d["note"]
	)
	debrief_panel.visible = true


func hide_debrief() -> void:
	debrief_panel.visible = false


func show_title(v: bool) -> void:
	title_panel.visible = v


func show_end(msg: String, col: Color) -> void:
	end_label.text = msg
	end_label.add_theme_color_override("font_color", col)
	end_panel.visible = true


func hide_end() -> void:
	end_panel.visible = false
