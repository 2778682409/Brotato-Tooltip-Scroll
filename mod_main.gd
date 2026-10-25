extends Node

var _processed = set()

func _ready():
    # 监听场景树中所有新生成的节点
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 1. 处理物品描述框（宝箱限高 + 商店/其他滑动）
    if node.name == "ItemDescription":
        if node in _processed:
            return
        _processed.add(node)
        
        # 等两帧，让游戏把基础排版算好
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        
        if is_instance_valid(node):
            var path = str(node.get_path())
            if "Shop" in path:
                # 商店：原版尺寸不变，只注入触摸滑动
                var scrolls = _find_all_scrolls(node)
                for scroll in scrolls:
                    _setup_touch_scroll(scroll)
            else:
                # 宝箱：套壳限高，防止溢出
                _wrap_and_lock_crate(node)
        return

    # 2. 处理其他所有滚动框（比如设置界面、角色选择等）
    if node is ScrollContainer:
        if node in _processed:
            return
        _processed.add(node)
        
        # 延迟一帧等子节点加载完，再注入滑动逻辑
        yield(get_tree(), "idle_frame")
        
        if is_instance_valid(node):
            _setup_touch_scroll(node)

# ============ 宝箱专用：套壳限高 ============
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
    # 限制宝箱高度为 400
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
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    
    # 递归把文字和图标的触摸屏蔽，只让按钮和滚动条响应触摸
    _set_mouse_ignore_for_text(scroll)
        
    if not scroll.is_connected("gui_input", self, "_on_scroll_gui_input"):
        scroll.connect("gui_input", self, "_on_scroll_gui_input", [scroll])

# 递归寻找所有内部 ScrollContainer
func _find_all_scrolls(root: Node) -> Array:
    var result = []
    if root is ScrollContainer:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_all_scrolls(child))
    return result

# 只让纯文本和图片忽略触摸，保留按钮的点击功能！
func _set_mouse_ignore_for_text(node: Node):
    for child in node.get_children():
        if child is Label or child is RichTextLabel or child is TextureRect:
            child.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _set_mouse_ignore_for_text(child)

# 使用相对位移模拟滑动（比记录起点更稳定，完美兼容设置界面和商店）
func _on_scroll_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag:
        # 手指向上滑，内容向上滚
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
    elif event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT:
        # 兼容鼠标左键拖拽
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
