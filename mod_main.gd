extends Node

var _processed = {}

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 1. 找回宝箱限高
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        
        if is_instance_valid(node):
            var path = str(node.get_path())
            # 排除商店，其他全部套壳
            if "Shop" not in path:
                _wrap_and_lock_crate(node)
        return
        
    # 2. 处理所有滚动框（商店、设置等）
    if node is ScrollContainer:
        if _processed.has(node): return
        _processed[node] = true
        
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            _setup_smart_scroll(node)

# ============ 宝箱套壳限高 ============
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
        
    _setup_smart_scroll(scroll)

# ============ 精准劫持：让滑动与点击互不干扰 ============
func _setup_smart_scroll(scroll: ScrollContainer):
    # 1. 让背景和文字变成透明，让手指滑动直接穿透过去
    _set_text_ignore(scroll)
    
    # 2. 顺藤摸瓜，找出里面所有的按钮和开关
    var buttons = _find_all_buttons(scroll)
    for btn in buttons:
        # 如果还没绑定过，就绑定触摸滑动
        if not btn.is_connected("gui_input", self, "_on_button_gui_input"):
            btn.connect("gui_input", self, "_on_button_gui_input", [btn, scroll])

# 把所有纯文本和普通容器设为忽略触摸
func _set_text_ignore(node: Node):
    for child in node.get_children():
        if child is Control:
            if not (child is Button or child is ScrollBar):
                child.mouse_filter = Control.MOUSE_FILTER_IGNORE
                _set_text_ignore(child)

# 找出所有按钮（包括 CheckButton 开关）
func _find_all_buttons(root: Node) -> Array:
    var result = []
    if root is Button:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_all_buttons(child))
    return result

# 核心：在按钮上滑动时，劫持事件去滚动！
func _on_button_gui_input(event: InputEvent, btn: Control, scroll: ScrollContainer):
    if event is InputEventScreenDrag:
        # 手指在按钮上滑动，强行让外层滚动条滚动
        scroll.scroll_vertical -= event.relative.y * 1.5
        # 吃掉事件，这样按钮就不会被触发点击！
        btn.accept_event()
    elif event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT:
        scroll.scroll_vertical -= event.relative.y * 1.5
        btn.accept_event()
