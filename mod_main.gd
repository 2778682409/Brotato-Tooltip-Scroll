extends Node

var _processed = {}
var _is_sliding := false

# ================= 悬停检测系统 =================
var _hover_timer: Timer = null
var _current_hover_node: Control = null
var _pending_hover_node: Control = null

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")
    call_deferred("_scan_existing_ui")

    # 初始化悬停防抖定时器（防止快速滑动时疯狂闪烁）
    _hover_timer = Timer.new()
    _hover_timer.one_shot = true
    _hover_timer.wait_time = 0.1
    _hover_timer.connect("timeout", self, "_on_hover_timeout")
    add_child(_hover_timer)

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
            if "Shop" in path:
                var scrolls = _find_all_scrolls(node)
                for s in scrolls:
                    _setup_touch_scroll(s)
            elif "CharacterSelection" in path or "MenuCodex" in path:
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

# ================= 触控拦截与分离 =================
func _input(event: InputEvent):
    # 1. 手指按下/移动时
    if event is InputEventScreenTouch and event.pressed:
        # 记录按下坐标，立刻测试悬停
        _update_hover(event.position)
    elif event is InputEventScreenDrag:
        # 💥 核心分离：手指移动时，滚动逻辑由 _on_scroll_gui_input 处理，
        # 但我们要同时用这里的真实坐标去控制悬停。
        _update_hover(event.position)
        
    # 2. 手指抬起时
    elif event is InputEventScreenTouch and not event.pressed:
        _clear_hover_state()

func _update_hover(pos: Vector2):
    var target = _find_item_at_position(pos)
    
    if target != _pending_hover_node:
        _pending_hover_node = target
        _hover_timer.stop()
        
        # 如果移出了当前弹窗的卡片，立刻关闭它
        if _current_hover_node != null and _current_hover_node != target:
            _trigger_hover_exit(_current_hover_node)
            _current_hover_node = null
            
        # 如果碰到了新卡片，启动延迟，防止滑太快闪烁
        if target != null:
            _hover_timer.start()

func _on_hover_timeout():
    if _pending_hover_node != null and is_instance_valid(_pending_hover_node):
        if _current_hover_node != _pending_hover_node:
            _current_hover_node = _pending_hover_node
            _trigger_hover_enter(_current_hover_node)

func _clear_hover_state():
    _hover_timer.stop()
    _pending_hover_node = null
    if _current_hover_node != null and is_instance_valid(_current_hover_node):
        _trigger_hover_exit(_current_hover_node)
    _current_hover_node = null

func _find_item_at_position(pos: Vector2) -> Control:
    for node in get_tree().root.find_children("ShopItem*", "Control", true, false):
        if node.is_visible_in_tree() and node.get_global_rect().has_point(pos):
            return node
            
    for node in get_tree().root.find_children("InventoryElement*", "Control", true, false):
        if node.is_visible_in_tree() and node.get_global_rect().has_point(pos):
            return node
    return null

func _trigger_hover_enter(node: Control):
    if node.has_method("_on_BuyButton_mouse_entered"):
        node._on_BuyButton_mouse_entered()
    elif node.has_method("_on_mouse_entered"):
        node._on_mouse_entered()
    else:
        node.emit_signal("mouse_entered")

func _trigger_hover_exit(node: Control):
    if node.has_method("_on_BuyButton_mouse_exited"):
        node._on_BuyButton_mouse_exited()
    elif node.has_method("_on_mouse_exited"):
        node._on_mouse_exited()
    else:
        node.emit_signal("mouse_exited")

# ============ 宝箱/升级UI限高（保持原样） ============
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

# ============ 滚动与滑动逻辑（保持原样） ============
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
    if event is InputEventScreenDrag or (event is InputEventMouseButton and event.button_mask & BUTTON_MASK_LEFT):
        _is_sliding = true
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
        
    elif event is InputEventScreenTouch or (event is InputEventMouseButton and not event.pressed):
        if _is_sliding:
            scroll.accept_event()
            _is_sliding = false
