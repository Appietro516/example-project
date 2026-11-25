extends SceneTree

const CALCULATOR_SCENE := preload("res://main.tscn")


func _initialize() -> void:
	_run_test.call_deferred()


func _run_test() -> void:
	var calculator := CALCULATOR_SCENE.instantiate()
	root.add_child(calculator)
	var keypad := calculator.get_node("%Keypad")
	var buttons := {}
	for button: Button in keypad.find_children("*", "Button", true, false):
		buttons[button.text] = button

	for key in ["2", "+", "3", "="]:
		var button: Button = buttons.get(key)
		if button == null:
			printerr("Missing calculator key: %s" % key)
			quit(1)
			return
		button.pressed.emit()

	var display: Label = calculator.get_node("%Display")
	if display.text != "5":
		printerr("Expected 2 + 3 = 5, but the display showed '%s'." % display.text)
		quit(1)
		return

	print("PASS: 2 + 3 = 5")
	quit()
