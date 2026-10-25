extends Node

var _processed = {}
# 用于记录拖拽状态的变量
var _drag_active = false
var _drag_start_y = 0.0
var _drag_start_scroll = 0.0

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    if node.name != "ItemDescription":
        return
        
    if _processed.has(node):
        return
        
    _processed[node] = true
    
    # 等两帧，等 UI 彻底排版出来
    yield(get_tree(), "idle_frame")
    yield(get_tree(), "idle_frame")
    
    if is_instance_valid(node):
        var path = str(node.get_path())
        if "Shop" in path:
            # 商店：不改变大小，只把所有内部的滚动条都装上“触屏补丁”
            var scrolls = _find_all_scrolls(node)
            for scroll in scrolls:
                _setup_touch_scroll(scroll)
        else:
            # 宝箱：套壳限高 + 触屏补丁
            _wrap_and_lock_crate(node)

# ============ 宝箱套壳逻辑 ============
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

# ============ 核心：给滚动框注入触屏滑动 ============
func _setup_touch_scroll(scroll: ScrollContainer):
    # 确保滚动框自己能接收触摸事件
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    
    # 把里面所有的文字、容器全部设置成“无视触摸”，这样手指划在字上，就等于划在框上
    for child in scroll.get_children():
        _set_mouse_ignore(child)
        
    # 监听手指的滑动事件
    if not scroll.is_connected("gui_input", self, "_on_scroll_gui_input"):
        scroll.connect("gui_input", self, "_on_scroll_gui_input", [scroll])

# 递归寻找所有 ScrollContainer
func _find_all_scrolls(root: Node) -> Array:
    var result = []
    if root is ScrollContainer:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_all_scrolls(child))
    return result

# 递归无视触摸（保留滚动条本身响应）
func _set_mouse_ignore(node: Node):
    for child in node.get_children():
        if child is Control and not (child is VScrollBar or child is HScrollBar):
            child.mouse_filter = Control.MOUSE_FILTER_IGNORE
            _set_mouse_ignore(child)

# 模拟手指滑动
func _on_scroll_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenTouch:
        if event.pressed:
            _drag_active = true
            _drag_start_y = event.position.y
            _drag_start_scroll = scroll.scroll_vertical
            scroll.accept_event()
        else:
            _drag_active = false
    elif event is InputEventScreenDrag and _drag_active:
        var diff = event.position.y - _drag_start_y
        scroll.scroll_vertical = _drag_start_scroll - diff
        scroll.accept_event()
