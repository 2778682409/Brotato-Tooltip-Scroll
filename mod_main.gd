extends Node

var _processed = {}
var _is_sliding := false

# ================= 暴力弹窗系统 =================
var _last_hover_node: Control = null

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")
    call_deferred("_scan_existing_ui")

func _scan_existing_ui():
    var all_scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
    for s in all_scrolls:
        if not _processed.has(s):
            _processed[s] = true
            _setup_touch_scroll(s)

func _on_node_added(node: Node):
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            var path = str(node.get_path())
            if "Shop" in path or "CharacterSelection" in path or "MenuCodex" in path:
                var scrolls = _find_all_scrolls(node)
                for s in scrolls:
                    _setup_touch_scroll(s)
            else:
                _wrap_and_lock_crate(node)
        return
        
    if node is ScrollContainer:
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            _setup_touch_scroll(node)

    if node is PanelContainer and "UpgradeUI" in node.name:
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            var desc = node.find_node("UpgradeDescription", true, false)
            if desc:
                _wrap_and_lock_upgrade(desc)
        return

# ================= 💥 核心：暴力接管弹窗 =================
func _input(event: InputEvent):
    # 手指拖拽滑动时
    if event is InputEventScreenDrag:
        _force_show_popup(event.position)
    # 手指抬起时
    elif event is InputEventScreenTouch and not event.pressed:
        # 用户说松手后如果停在物品上，弹窗保留。所以这里不隐藏弹窗，直接清空引用
        _last_hover_node = null

func _force_show_popup(pos: Vector2):
    var target = _find_item_at_position(pos)
    
    # 如果手指滑到了新物品上
    if target != null and target != _last_hover_node:
        _last_hover_node = target
        var item_data = null
        
        # 尝试从商店卡片或背包元素中拿到 item_data
        if "item_data" in target:
            item_data = target.item_data
        elif "item" in target:
            item_data = target.item
            
        if item_data != null:
            # 寻找当前场景里的弹窗节点 (原版叫 ItemPopup)
            var popup = get_tree().root.find_node("ItemPopup", true, false)
            if popup != null and popup.has_method("display_item_data"):
                # 强行命令弹窗显示！传入数据、锚点(卡片自身)、是否在背包
                var is_inventory = "InventoryElement" in target.name
                popup.display_item_data(item_data, target, is_inventory)
                
    # 如果手指滑到了空白处
    elif target == null and _last_hover_node != null:
        _last_hover_node = null
        var popup = get_tree().root.find_node("ItemPopup", true, false)
        if popup != null:
            popup.hide()

func _find_item_at_position(pos: Vector2) -> Control:
    for node in get_tree().root.find_children("ShopItem*", "Control", true, false):
        if node.is_visible_in_tree() and node.get_global_rect().has_point(pos):
            return node
            
    for node in get_tree().root.find_children("InventoryElement*", "Control", true, false):
        if node.is_visible_in_tree() and node.get_global_rect().has_point(pos):
            return node
    return null

# ============ 宝箱限高 ============
func _wrap_and_lock_crate(popup_root: Control):
    var parent = popup_root.get_parent()
    if not parent or parent is ScrollContainer: return
    var index = popup_root.get_index()
    var orig_pos = popup_root.rect_position
    var orig_width = popup_root.rect_size.x
    
    parent.remove_child(popup_root)
    var scroll = ScrollContainer.new()
    scroll.name = "ModTooltipScroll"
    var fixed_height = 400.0
    scroll.rect_position = orig_pos
    scroll.rect_min_size = Vector2(orig_width, fixed_height)
    scroll.rect_size = Vector2(orig_width, fixed_height)
    scroll.scroll_horizontal_enabled = false
    scroll.scroll_vertical_enabled = true
    scroll.clip_contents = true

    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(popup_root)
    
    if popup_root is Control:
        popup_root.rect_position = Vector2(0, 0)
        popup_root.rect_min_size.x = orig_width
        popup_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    _setup_touch_scroll(scroll)

# ============ 升级卡片限高 ============
func _wrap_and_lock_upgrade(desc_node: Control):
    var parent = desc_node.get_parent()
    if not parent or parent is ScrollContainer: return
    var index = desc_node.get_index()
    parent.remove_child(desc_node)
    var scroll = ScrollContainer.new()
    scroll.name = "ModUpgradeScroll"
    var fixed_height = 180.0 
    scroll.rect_min_size = Vector2(0, fixed_height)
    scroll.rect_size = Vector2(desc_node.rect_size.x, fixed_height)
    scroll.scroll_horizontal_enabled = false
    scroll.scroll_vertical_enabled = true
    scroll.clip_contents = true

    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(desc_node)
    
    if desc_node is Control:
        desc_node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    _setup_touch_scroll(scroll)

# ============ 触摸滑动（完美保留） ============
func _setup_touch_scroll(scroll: ScrollContainer):
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _set_mouse_ignore_for_containers(scroll)
    
    var buttons = _find_buttons(scroll)
    for btn in buttons:
        if btn is CheckButton:
            var empty_style = StyleBoxEmpty.new()
            btn.add_stylebox_override("normal", empty_style)
            btn.add_stylebox_override("pressed", empty_style)
            btn.add_stylebox_override("focus", empty_style)
            btn.add_stylebox_override("disabled", empty_style)
            btn.mouse_filter = Control.MOUSE_FILTER_PASS
        
        if not btn.is_connected("gui_input", self, "_on_button_gui_input"):
            btn.connect("gui_input", self, "_on_button_gui_input", [scroll])
        
    if not scroll.is_connected("gui_input", self, "_on_scroll_gui_input"):
        scroll.connect("gui_input", self, "_on_scroll_gui_input", [scroll])

func _set_mouse_ignore_for_containers(node: Node):
    for child in node.get_children():
        if child is Control:
            if child is BaseButton or child is ScrollBar or child is Slider or child is OptionButton or child is LineEdit or child is ColorPicker:
                pass 
            else:
                child.mouse_filter = Control.MOUSE_FILTER_IGNORE
                _set_mouse_ignore_for_containers(child)
        else:
            _set_mouse_ignore_for_containers(child)

func _find_buttons(root: Node) -> Array:
    var result = []
    if root is Button:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_buttons(child))
    return result

func _find_all_scrolls(root: Node) -> Array:
    var result = []
    if root is ScrollContainer:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_all_scrolls(child))
    return result

func _on_scroll_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT):
        _is_sliding = true
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()

func _on_button_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT):
        _is_sliding = true
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
        
    elif event is InputEventScreenTouch or (event is InputEventMouseButton and not event.pressed):
        if _is_sliding:
            scroll.accept_event()
            _is_sliding = false
