extends Control

const DIGIT_LIMIT := 12
const KEY_GAP := 8
const DISPLAY_FONT_SIZE := 34
const KEY_ROWS := [
	["AC", "⌫", "±", "÷"],
	["7", "8", "9", "×"],
	["4", "5", "6", "−"],
	["1", "2", "3", "+"],
]
const TOOLTIP := {
	"AC": "Clear (Esc or Delete)",
	"⌫": "Backspace",
	"±": "Change sign",
	"÷": "Divide (/)",
	"×": "Multiply (*)",
	"−": "Subtract (-)",
	"+": "Add (+)",
	"=": "Equals (Enter)",
}

@onready var display: Label = %Display
@onready var expression: Label = %Expression

var entry := "0"
var result := 0.0
var left_operand := 0.0
var pending_operator := ""
var editing := false


func _ready() -> void:
	var theme_for_keys := Theme.new()
	_add_key_style(theme_for_keys, &"Button", Color("#e8eadd"), Color("#202e27"))
	_add_key_style(theme_for_keys, &"UtilityKey", Color("#d9e3d6"), Color("#202e27"))
	_add_key_style(theme_for_keys, &"OperatorKey", Color("#d0dfcd"), Color("#202e27"))
	_add_key_style(theme_for_keys, &"EqualsKey", Color("#2b5b46"), Color("#fffdf4"))
	%Keypad.theme = theme_for_keys

	for keys in KEY_ROWS:
		var row := _make_key_row()
		%Keypad.add_child(row)
		for key in keys:
			row.add_child(_make_key(key))

	var bottom_row := _make_key_row()
	%Keypad.add_child(bottom_row)
	bottom_row.add_child(_make_key("0"))
	var right_half := _make_key_row()
	right_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(right_half)
	right_half.add_child(_make_key("."))
	right_half.add_child(_make_key("="))
	display.resized.connect(_fit_display)


func _make_key_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", KEY_GAP)
	return row


func _make_key(key: String) -> Button:
	var button := Button.new()
	button.text = key
	button.tooltip_text = TOOLTIP.get(key, "")
	button.custom_minimum_size.y = 56
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match key:
		"AC", "⌫", "±":
			button.theme_type_variation = &"UtilityKey"
		"÷", "×", "−", "+":
			button.theme_type_variation = &"OperatorKey"
		"=":
			button.theme_type_variation = &"EqualsKey"
	button.pressed.connect(_press.bind(key))
	return button


func _add_key_style(key_theme: Theme, kind: StringName, fill: Color, ink: Color) -> void:
	if kind != &"Button":
		key_theme.set_type_variation(kind, &"Button")

	for state in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		key_theme.set_color(state, kind, ink)
	key_theme.set_font_size(&"font_size", kind, 22)

	for state in [&"normal", &"hover", &"pressed"]:
		var box := StyleBoxFlat.new()
		box.set_corner_radius_all(11)
		box.bg_color = fill
		if state == &"hover":
			box.bg_color = fill.lerp(ink, 0.09)
		elif state == &"pressed":
			box.bg_color = fill.lerp(ink, 0.17)
		key_theme.set_stylebox(state, kind, box)

	var focus := StyleBoxFlat.new()
	focus.set_corner_radius_all(11)
	focus.set_border_width_all(2)
	focus.border_color = ink
	focus.draw_center = false
	key_theme.set_stylebox(&"focus", kind, focus)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return

	var key := ""
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			key = "="
		KEY_ESCAPE, KEY_DELETE:
			key = "AC"
		KEY_BACKSPACE:
			key = "⌫"
		_:
			if event.unicode == 0:
				return
			key = String.chr(event.unicode)
			key = {"*": "×", "/": "÷", "-": "−"}.get(key, key)
			if not key.is_valid_int() and key not in [".", "+", "−", "×", "÷", "="]:
				return
	get_viewport().set_input_as_handled()
	_press(key)


func _press(key: String) -> void:
	match key:
		"AC":
			_reset()
		"⌫":
			if editing:
				entry = entry.left(-1)
				if entry.is_empty() or entry == "-":
					entry = "0"
		"±":
			if editing or not pending_operator.is_empty() or result == 0.0:
				if not editing:
					entry = "0"
					editing = true
				entry = entry.substr(1) if entry.begins_with("-") else "-" + entry
			elif is_finite(result):
				result = -result
		"+", "−", "×", "÷", "=":
			_apply_operator(key)
		_:
			_append(key)
	_refresh_display()


func _reset() -> void:
	entry = "0"
	result = 0.0
	left_operand = 0.0
	pending_operator = ""
	editing = false


func _append(key: String) -> void:
	if not editing:
		entry = "0"
		editing = true
	if key == ".":
		if not entry.contains("."):
			entry += "."
	elif entry == "0" or entry == "-0":
		entry = "-" + key if entry.begins_with("-") else key
	elif entry.replace("-", "").replace(".", "").length() < DIGIT_LIMIT:
		entry += key


func _apply_operator(key: String) -> void:
	if not pending_operator.is_empty() and editing:
		var right_operand := entry.to_float()
		match pending_operator:
			"+":
				result = left_operand + right_operand
			"−":
				result = left_operand - right_operand
			"×":
				result = left_operand * right_operand
			"÷":
				result = NAN if right_operand == 0.0 else left_operand / right_operand
	elif editing:
		result = entry.to_float()

	editing = false
	pending_operator = ""
	if key != "=" and is_finite(result):
		left_operand = result
		pending_operator = key


func _refresh_display() -> void:
	display.text = entry if editing else _format_result(result)
	_fit_display()
	expression.text = ""
	if not pending_operator.is_empty():
		expression.text = "%s %s" % [_format_result(left_operand), pending_operator]


func _fit_display() -> void:
	if display.size.x <= 0:
		return
	var font := display.get_theme_font(&"font")
	var text_width := font.get_string_size(display.text, HORIZONTAL_ALIGNMENT_LEFT, -1, DISPLAY_FONT_SIZE).x
	var font_size := floori(DISPLAY_FONT_SIZE * display.size.x / maxf(text_width, display.size.x))
	display.add_theme_font_size_override(&"font_size", font_size)


func _format_result(value: float) -> String:
	if not is_finite(value):
		return "Error"
	if value == 0.0:
		return "0"

	var magnitude := absf(value)
	if magnitude >= 1.0e12 or magnitude < 1.0e-6:
		return String.num_scientific(value)

	var decimals := clampi(DIGIT_LIMIT - 1 - floori(log(magnitude) / log(10.0)), 0, 16)
	var formatted := String.num(value, decimals)
	# Rounding can move the value across the scientific notation threshold.
	if absf(formatted.to_float()) >= 1.0e12:
		return String.num_scientific(value)
	return formatted.trim_suffix(".0")
