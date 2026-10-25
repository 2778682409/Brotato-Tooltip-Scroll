extends Node

var _processed = {}

func _ready():
    # 1. 游戏启动时，先主动扫一遍已经存在的 UI（解决主界面 Mod 列表滑不动）
    call_deferred("_scan_existing_ui")
    
    # 2. 监听后续动态生成的 UI
    get_tree().connect("node_added", self, "_on_node_added")

func _scan_existing_ui():
    var scrolls = _find_all_scrolls(get_tree().root)
    for s in scrolls:
        _setup_native_scroll(s)

func _on_node_added(node: Node):
    # 1. 处理宝箱的物品描述框限高
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
        
    # 2. 处理新生成的滚动框
    if node is ScrollContainer:
        if _processed.has(node): return
        _processed[node] = true
        
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            _setup_native_scroll(node)

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
        
    _setup_native_scroll(scroll)

# ============ 核心：纯原生“清理路障” ============
func _setup_native_scroll(scroll: ScrollContainer):
    # 确保滚动框接收触摸，并且允许事件穿透给它
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    
    # 调用补丁作者的绝招：把内部的按钮和文字清理干净
    _clean_up_children(scroll)

func _clean_up_children(node: Node):
    for child in node.get_children():
        if child is Control:
            # 1. 如果遇到开关 (CheckButton)
            if child is CheckButton:
                # 抄作业：干掉黑色大背景，变成透明，防止视觉变丑
                var empty_style = StyleBoxEmpty.new()
                child.add_stylebox_override("normal", empty_style)
                child.add_stylebox_override("pressed", empty_style)
                child.add_stylebox_override("focus", empty_style)
                child.add_stylebox_override("disabled", empty_style)
                
                # 允许事件向下传递（滑动的关键）
                child.mouse_filter = Control.MOUSE_FILTER_PASS
                
            # 2. 如果是普通按钮
            elif child is Button:
                child.mouse_filter = Control.MOUSE_FILTER_PASS
                
            # 3. 如果是文字、图片、或者普通容器
            elif child is Label or child is RichTextLabel or child is TextureRect or child is Container:
                # 设为穿透，让手指滑动时直接穿透给底下的 ScrollContainer
                child.mouse_filter = Control.MOUSE_FILTER_IGNORE
                # 继续往下扒
                _clean_up_children(child)
        else:
            _clean_up_children(child)

# ============ 辅助函数 ============
func _find_all_scrolls(root: Node) -> Array:
    var result = []
    if root is ScrollContainer:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_all_scrolls(child))
    return result
