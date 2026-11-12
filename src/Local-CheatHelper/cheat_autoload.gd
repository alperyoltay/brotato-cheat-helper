extends Node

# Brotato - Local Cheat Helper (loaded automatically at game start via override.cfg)
#
# Hotkeys (in game):
#   F5  -> +GOLD_BUTTON_AMOUNT materials for every player (wave or shop)
#   F6  -> +STAT_BUTTON_AMOUNT to all primary stats (wave or shop)
#   F7  -> Gain 1 level (during a wave only; pick the upgrade at the end of the wave)
#   F8  -> Toggle the material multiplier on / off
#   F9  -> Cycle the material multiplier (1x, 2x, 3x, 5x, 10x, 25x, 50x, 100x)
#
# Shop: A red X button appears in the top-right corner of every inventory item.
#       Clicking it removes one copy of that item completely (its stats are reverted, no refund).

const META_KEY := "cheat_helper_gold_mult"
const SHOP_SCENES := ["res://ui/menus/shop/shop.tscn", "res://ui/menus/shop/coop_shop.tscn"]
const X_BUTTON_NAME := "CheatXButton"
const X_BUTTON_SIZE := 30

# ---------------- SETTINGS ----------------
const GOLD_BUTTON_AMOUNT := 500
const STAT_BUTTON_AMOUNT := 5
const MULT_STEPS := [1.0, 2.0, 3.0, 5.0, 10.0, 25.0, 50.0, 100.0]
const DEFAULT_MULT_INDEX := 3 # 5x
# ------------------------------------------

var _mult_index: int = DEFAULT_MULT_INDEX
var _enabled := true
var _label: Label
var _label_time := 0.0
var _cleaned_shop_id := 0
var _orphan_sigs = null


func _ready() -> void:
	_install_main_extension()
	_publish_mult()

	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_label = Label.new()
	_label.rect_position = Vector2(24, 24)
	_label.rect_scale = Vector2(2, 2)
	_label.add_color_override("font_color", Color(1.0, 0.85, 0.2))
	_label.add_color_override("font_color_shadow", Color(0, 0, 0))
	_label.visible = false
	layer.add_child(_label)
	_notify("CheatHelper loaded (F5-F9)")


# Replaces the game's res://main.gd script with our extension
# (the same take_over_path technique Godot Mod Loader uses).
func _install_main_extension() -> void:
	var base_dir: String = get_script().resource_path.get_base_dir()
	var ext: Script = load(base_dir.plus_file("extensions/main.gd"))
	if ext == null:
		push_error("[CheatHelper] could not load extensions/main.gd")
		return
	ext.take_over_path("res://main.gd")
	print("[CheatHelper] main.gd extension installed")


func _process(delta: float) -> void:
	if _label and _label.visible:
		_label_time -= delta
		if _label_time <= 0.0:
			_label.visible = false
	_update_shop_delete_buttons()


# ---------------- Shop: item delete (X) buttons ----------------

func _get_shop_scene():
	var scene = get_tree().current_scene
	if scene == null or not (scene.filename in SHOP_SCENES) or not scene.has_method("_get_gear_container"):
		return null
	return scene


func _update_shop_delete_buttons() -> void:
	var scene = _get_shop_scene()
	if scene == null:
		return
	# Once per shop visit: clean up effects left over from previously deleted items
	if scene.get_instance_id() != _cleaned_shop_id:
		_cleaned_shop_id = scene.get_instance_id()
		var total := 0
		for i in RunData.get_player_count():
			total += _cleanup_orphan_effects(i)
		if total > 0:
			_notify("Cleaned up %d effects left by deleted items" % total)
	for i in RunData.get_player_count():
		var gear = scene._get_gear_container(i)
		if gear == null or gear.items_container == null or gear.items_container._elements == null:
			continue
		for element in gear.items_container._elements.get_children():
			if element.has_node(X_BUTTON_NAME) or not _is_deletable(element):
				continue
			_add_x_button(element, i)


func _is_deletable(element) -> bool:
	if not ("item" in element) or element.item == null:
		return false
	if element.get("is_special"):
		return false
	# The character itself also sits in the inventory as an "item"; never delete it
	if element.item is CharacterData:
		return false
	return element.item is ItemData


func _add_x_button(element: Control, player_index: int) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.8, 0.1, 0.1, 0.9)
	normal.set_corner_radius_all(4)
	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.25, 0.25, 1.0)

	var b := Button.new()
	b.name = X_BUTTON_NAME
	b.text = "X"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	b.hint_tooltip = "Delete item"
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0
	b.anchor_bottom = 0.0
	b.margin_left = -X_BUTTON_SIZE - 2
	b.margin_right = -2
	b.margin_top = 2
	b.margin_bottom = X_BUTTON_SIZE + 2
	b.add_stylebox_override("normal", normal)
	b.add_stylebox_override("hover", hover)
	b.add_stylebox_override("pressed", hover)
	b.add_color_override("font_color", Color(1, 1, 1))
	b.add_color_override("font_color_hover", Color(1, 1, 1))
	var font = load("res://resources/fonts/actual/base/font_26_outline.tres")
	if font:
		b.add_font_override("font", font)
	b.connect("pressed", self, "_on_x_pressed", [element, player_index])
	element.add_child(b)


# ---------------- Orphaned effect cleanup ----------------
# Some effects (structures/turrets/landmines/garden, pets, explosions, thorns, burning trail,
# stat conversions) are added to the player's effect list as objects and are looked up
# with erase(self) when removed. In runs resumed from a save these objects are copies,
# so they can't be removed and the effect stays even after the item is gone.
# Here we delete any identical effects beyond what the owned items can provide.

func _eff_sig(e) -> String:
	var script = e.get_script()
	var s: String = script.resource_path if script else e.get_class()
	for prop in ["key_hash", "custom_key_hash", "value", "spawn_cooldown", "tracking_key", "is_pet"]:
		if prop in e:
			s += "|" + str(e.get(prop))
	if "scene" in e and e.get("scene"):
		s += "|" + str(e.get("scene").resource_path)
	return s


# Only effect signatures that exist in the item catalog and NOT on weapons/characters are cleaned up
func _get_orphan_sigs() -> Dictionary:
	if _orphan_sigs != null:
		return _orphan_sigs
	var sigs := {}
	for it in ItemService.items:
		for e in it.effects:
			if e is Object:
				sigs[_eff_sig(e)] = true
	var excluded := []
	if "weapons" in ItemService:
		excluded.append(ItemService.weapons)
	if "characters" in ItemService:
		excluded.append(ItemService.characters)
	for list in excluded:
		for it in list:
			for e in it.effects:
				if e is Object:
					sigs.erase(_eff_sig(e))
	_orphan_sigs = sigs
	return sigs


func _cleanup_orphan_effects(player_index: int) -> int:
	var sigs := _get_orphan_sigs()
	var expected := {}
	for it in RunData.get_player_items(player_index):
		for e in it.effects:
			if e is Object:
				var s := _eff_sig(e)
				if sigs.has(s):
					expected[s] = expected.get(s, 0) + 1

	var effects: Dictionary = RunData.get_player_effects(player_index)
	var removed := 0
	for key in effects.keys():
		var arr = effects[key]
		if not (arr is Array):
			continue
		var seen := {}
		var to_remove := []
		for idx in arr.size():
			var o = arr[idx]
			if not (o is Object) or not is_instance_valid(o):
				continue
			var s := _eff_sig(o)
			if not sigs.has(s):
				continue
			seen[s] = seen.get(s, 0) + 1
			if seen[s] > expected.get(s, 0):
				to_remove.append(idx)
		to_remove.invert()
		for idx in to_remove:
			arr.remove(idx)
		removed += to_remove.size()

	if removed > 0:
		Utils.reset_stat_cache(player_index)
		print("[CheatHelper] Player %d: removed %d orphaned effects" % [player_index, removed])
	return removed


func _on_x_pressed(element, player_index: int) -> void:
	if not is_instance_valid(element) or element.item == null:
		return
	var scene = _get_shop_scene()
	if scene == null:
		return
	var item = element.item

	# apply_replacement = false -> don't swap in another item, remove it entirely
	RunData.remove_item(item, player_index, false, false)
	_cleanup_orphan_effects(player_index)

	scene._get_gear_container(player_index).set_items_data(RunData.get_player_items(player_index))
	if scene.has_method("_update_stats"):
		scene._update_stats(player_index)
	if scene.has_method("_get_item_popup"):
		var popup = scene._get_item_popup(player_index)
		if popup:
			popup.hide()
	var item_name = item.get("name")
	_notify("Deleted: " + (tr(item_name) if item_name is String and item_name != "" else "item"))


func _input(event) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.scancode:
		KEY_F5:
			if _in_run():
				for i in RunData.get_player_count():
					RunData.add_gold(GOLD_BUTTON_AMOUNT, i)
				_notify("+%d materials" % GOLD_BUTTON_AMOUNT)
		KEY_F6:
			if _in_run():
				for i in RunData.get_player_count():
					for key in Utils.get_primary_stat_keys():
						RunData.add_stat(key, STAT_BUTTON_AMOUNT, i)
				_notify("All stats +%d" % STAT_BUTTON_AMOUNT)
		KEY_F7:
			if _in_wave():
				for i in RunData.get_player_count():
					_level_up(i)
				_notify("+1 level (pick the upgrade at the end of the wave)")
		KEY_F8:
			_enabled = not _enabled
			_publish_mult()
			_notify("Material multiplier: %s" % (_mult_text() if _enabled else "OFF"))
		KEY_F9:
			_mult_index = (_mult_index + 1) % MULT_STEPS.size()
			_enabled = true
			_publish_mult()
			_notify("Material multiplier: " + _mult_text())


func _level_up(player_index: int) -> void:
	var need: float = RunData.get_next_level_xp_needed(player_index) - RunData.get_player_xp(player_index)
	# add_xp applies the XP Gain stat; compensate for it
	var factor: float = 1.0 + Utils.get_stat(Keys.xp_gain_hash, player_index) / 100.0
	factor = max(factor, 0.05)
	RunData.add_xp(int(ceil(max(need, 0.0) / factor)) + 1, player_index)


func _publish_mult() -> void:
	Engine.set_meta(META_KEY, MULT_STEPS[_mult_index] if _enabled else 1.0)


func _mult_text() -> String:
	return "%dx" % int(MULT_STEPS[_mult_index])


func _scene_path() -> String:
	var scene = get_tree().current_scene
	return scene.filename if scene else ""


func _in_wave() -> bool:
	return _scene_path() == "res://main.tscn"


func _in_run() -> bool:
	var p := _scene_path()
	return p == "res://main.tscn" or p.begins_with("res://ui/menus/shop/")


func _notify(text: String) -> void:
	print("[CheatHelper] " + text)
	if _label:
		_label.text = text
		_label.visible = true
		_label_time = 2.5
