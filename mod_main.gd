extends Node

var _processed = {}
# 记录是否正在滑动
var _is_sliding := false

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")
    call_deferred("_scan_existing_ui")

# 游戏启动时扫描一遍已有的主界面
func _scan_existing_ui():
    var all_scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
    for s in all_scrolls:
        if not _processed.has(s):
            _processed[s] = true
            _setup_touch_scroll(s)

func _on_node_added(node: Node):
    # 1. 处理宝箱和商店的物品弹窗
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
            else:
                _wrap_and_lock_crate(node)
        return
        
    # 2. 处理设置界面等其他滚动条
    if node is ScrollContainer:
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            _setup_touch_scroll(node)

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

# ============ 核心：去黑框 + 挂载拦截 ============
func _setup_touch_scroll(scroll: ScrollContainer):
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _set_mouse_ignore_for_containers(scroll)
    
    var buttons = _find_buttons(scroll)
    for btn in buttons:
        if btn is CheckButton:
            # 抄作业：干掉大黑框
            var empty_style = StyleBoxEmpty.new()
            btn.add_stylebox_override("normal", empty_style)
            btn.add_stylebox_override("pressed", empty_style)
            btn.add_stylebox_override("focus", empty_style)
            btn.add_stylebox_override("disabled", empty_style)
            btn.mouse_filter = Control.MOUSE_FILTER_PASS
        
        # 挂载带拦截功能的 gui_input
        if not btn.is_connected("gui_input", self, "_on_button_gui_input"):
            btn.connect("gui_input", self, "_on_button_gui_input", [scroll])
        
    if not scroll.is_connected("gui_input", self, "_on_scroll_gui_input"):
        scroll.connect("gui_input", self, "_on_scroll_gui_input", [scroll])

func _set_mouse_ignore_for_containers(node: Node):
    for child in node.get_children():
        if child is Control:
            if child is Button or child is ScrollBar:
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

# 监听滚动框本体滑动
func _on_scroll_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT):
        _is_sliding = true # 标记正在滑动
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()

# 💥 核心魔法：在开关上滑动 + 拦截抬起
func _on_button_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT):
        _is_sliding = true
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
        
    # 抄 Touch slide 的绝杀：当手指抬起，且刚才发生了滑动
    elif event is InputEventScreenTouch or (event is InputEventMouseButton and not event.pressed):
        if _is_sliding:
            # 拦截抬起事件！开关接收不到抬起，就不会触发点击！
            scroll.accept_event()
            _is_sliding = false
