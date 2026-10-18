@tool
extends EditorPlugin


func _enter_tree() -> void:
	call_deferred("_configure_preview")


func _build() -> bool:
	_configure_preview()
	return true


func _configure_preview() -> void:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_EMBEDDING):
		return
	# Updating the file alone leaves GameView's cached mode unchanged. Use the
	# editor's menu signal so its live sizing mode and saved metadata both update.
	# Godot 4.7 has no public EditorInterface API for embedded viewport sizing.
	var popup: PopupMenu = _find_sizing_menu(get_tree().root)
	if popup == null:
		push_warning("HexElim: set Game Window Options > Stretch to Fit to scale the embedded preview.")
		return
	var sizing_items: Array[int] = []
	for index: int in range(popup.item_count):
		if popup.is_item_radio_checkable(index):
			sizing_items.append(index)
	# The three GameView choices in Godot 4.7 are Fixed, Keep Aspect, Stretch.
	if sizing_items.size() != 3:
		push_warning("HexElim: unrecognized embedded preview sizing menu; select Stretch to Fit manually.")
		return
	var stretch_index: int = sizing_items[2]
	if not popup.is_item_checked(stretch_index):
		popup.id_pressed.emit(popup.get_item_id(stretch_index))


func _find_sizing_menu(node: Node) -> PopupMenu:
	if node is MenuButton:
		var popup: PopupMenu = node.get_popup()
		# Godot stores these source labels unchanged; translation happens at draw time.
		var labels: Array[String] = []
		for index: int in range(popup.item_count):
			labels.append(popup.get_item_text(index))
		if labels.has("Fixed Size") and labels.has("Keep Aspect Ratio") and labels.has("Stretch to Fit"):
			return popup
	for child: Node in node.get_children(true):
		var result: PopupMenu = _find_sizing_menu(child)
		if result != null:
			return result
	return null
