extends Node

var _processed = {}
var _is_sliding := false
var _last_hover_pos = Vector2.ZERO
var _current_hover_node: Control = null
var _last_check_time := 0.0

func _ready():
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    
    get_tree().connect("node_added", self, "_on_node_added")
    call_deferred("_scan_existing_ui")
    set_process_input(true)

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

# ============ 幽灵鼠标 & 暴力悬停核心逻辑 ============
func _input(event):
    # 监听手指滑动或鼠标拖拽
    if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT):
        var global_pos = event.position
        
        # 1. 将真实鼠标指针传送到手指的位置
        Input.warp_mouse_position(global_pos)
        
        # 2. 伪造一个“鼠标左键未按下”的移动事件（用 Input.parse_input_event 才能喂给底层）
        var fake_motion = InputEventMouseMotion.new()
        fake_motion.position = global_pos
        fake_motion.global_position = global_pos
        fake_motion.relative = event.relative
        fake_motion.button_mask = 0 
        Input.parse_input_event(fake_motion)
        
        # 3. 暴力计算当前手指是否在物品上，并强制触发悬停
        _bruteforce_hover(global_pos)
        
    # 监听手指或鼠标抬起
    elif event is InputEventScreenTouch and not event.pressed or (event is InputEventMouseButton and not event.pressed and event.button_index == BUTTON_LEFT):
        # 抬起时清理悬停状态
        _clear_hover()

# 暴力强制悬停逻辑（无视拖拽屏蔽）
func _bruteforce_hover(pos: Vector2):
    # 节流：100ms 检查一次，防止滑动时卡顿
    var now = OS.get_ticks_msec()
    if now - _last_check_time < 100:
        return
    _last_check_time = now
    
    # 如果位置没怎么变，跳过
    if pos.distance_squared_to(_last_hover_pos) < 100:
        return
    _last_hover_pos = pos
    
    var target = _find_item_at_position(pos)
    
    if target == _current_hover_node:
        return
        
    # 退出旧的节点
    if _current_hover_node and is_instance_valid(_current_hover_node):
        _current_hover_node.notification(NOTIFICATION_MOUSE_EXIT)
        _current_hover_node.emit_signal("mouse_exited")
        if _current_hover_node.has_method("_on_mouse_exited"):
            _current_hover_node._on_mouse_exited()
            
    _current_hover_node = target
    
    # 进入新的节点（强行发送底层通知和信号）
    if _current_hover_node and is_instance_valid(_current_hover_node):
        _current_hover_node.notification(NOTIFICATION_MOUSE_ENTER)
        _current_hover_node.emit_signal("mouse_entered")
        
        if _current_hover_node.has_method("_on_BuyButton_mouse_entered"):
            _current_hover_node._on_BuyButton_mouse_entered()
        elif _current_hover_node.has_method("_on_mouse_entered"):
            _current_hover_node._on_mouse_entered()

func _clear_hover():
    if _current_hover_node and is_instance_valid(_current_hover_node):
        _current_hover_node.notification(NOTIFICATION_MOUSE_EXIT)
        _current_hover_node.emit_signal("mouse_exited")
        if _current_hover_node.has_method("_on_mouse_exited"):
            _current_hover_node._on_mouse_exited()
    _current_hover_node = null
    _last_hover_pos = Vector2.ZERO

# 寻找鼠标/手指底下的物品卡片
func _find_item_at_position(pos: Vector2) -> Control:
    for node in get_tree().root.find_children("ShopItem*", "Control", true, false):
        if node.is_visible_in_tree() and node.get_global_rect().has_point(pos):
            return node
            
    for node in get_tree().root.find_children("InventoryElement*", "Control", true, false):
        if node.is_visible_in_tree() and node.get_global_rect().has_point(pos):
            return node
            
    return null

# ============ 滑动逻辑 ============
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

func _on_scroll_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT):
        _is_sliding = true
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
        
    elif event is InputEventScreenTouch or (event is InputEventMouseButton and not event.pressed):
        _is_sliding = false

func _on_button_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT):
        _is_sliding = true
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
        
    elif event is InputEventScreenTouch or (event is InputEventMouseButton and not event.pressed):
        if _is_sliding:
            scroll.accept_event()
            _is_sliding = false

# ============ 宝箱与升级UI限高 ============
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
