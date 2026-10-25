extends Node

var _processed = {}

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 1. 处理宝箱和商店的物品弹窗
    if node.name == "ItemDescription":
        if _processed.has(node):
            return
        _processed[node] = true
        
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        
        if is_instance_valid(node):
            var path = str(node.get_path())
            if "Shop" in path:
                # 商店：找齐所有滚动条，直接注入触摸滑动
                var scrolls = _find_all_scrolls(node)
                for s in scrolls:
                    _setup_touch_scroll(s)
            else:
                # 宝箱：套壳限高
                _wrap_and_lock_crate(node)
        return
        
    # 2. 处理游戏内设置界面等其他滚动条
    if node is ScrollContainer:
        if _processed.has(node):
            return
        _processed[node] = true
        
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            _setup_touch_scroll(node)

# ============ 宝箱限高 ============
func _wrap_and_lock_crate(popup_root: Control):
    var parent = popup_root.get_parent()
    if not parent or parent is ScrollContainer:
        return

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

# ============ 核心：赋予滚动条“触摸滑动”能力 ============
func _setup_touch_scroll(scroll: ScrollContainer):
    # 让滚动框自己完全接管触摸
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    
    # 深度清理：把里面除了按钮和滚动条以外的所有容器、文字全变成“透明”
    _set_mouse_ignore_for_containers(scroll)
        
    # 连接触摸滑动逻辑
    if not scroll.is_connected("gui_input", self, "_on_scroll_gui_input"):
        scroll.connect("gui_input", self, "_on_scroll_gui_input", [scroll])

# 核心辅助：穿透触摸（保留按钮和滚动条）
func _set_mouse_ignore_for_containers(node: Node):
    for child in node.get_children():
        if child is Control:
            # 如果是按钮，或者滚动条本身，保留它的触摸响应
            if child is Button or child is ScrollBar:
                pass # 不修改它，也不往下遍历了
            else:
                # 容器、文字、图片，全部设为忽略，让事件穿透到 scroll 上
                child.mouse_filter = Control.MOUSE_FILTER_IGNORE
                _set_mouse_ignore_for_containers(child)
        else:
            _set_mouse_ignore_for_containers(child)

# 核心辅助：找齐内部所有的 ScrollContainer
func _find_all_scrolls(root: Node) -> Array:
    var result = []
    if root is ScrollContainer:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_all_scrolls(child))
    return result

# 监听手指滑动
func _on_scroll_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag:
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
    elif event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT:
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
