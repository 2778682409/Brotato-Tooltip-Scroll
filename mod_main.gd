extends Node

var _processed = {}

func _ready():
    # 💥 存活指示灯：如果游戏左上角没出现这行绿字，说明模组根本没加载！
    _add_debug_label("✅ 终极滑动补丁已加载")
    
    # 延迟扫描主界面的 Mod 列表
    call_deferred("_scan_all_scrolls")
    
    # 监听后续生成的 UI
    get_tree().connect("node_added", self, "_on_node_added")

func _add_debug_label(text: String):
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    var label = Label.new()
    label.text = text
    label.add_color_override("font_color", Color(0, 1, 0))
    label.add_color_override("font_outline_color", Color(0, 0, 0))
    label.add_constant_override("outline_size", 4)
    label.rect_position = Vector2(20, 20)
    canvas.add_child(label)

func _scan_all_scrolls():
    # 解决主界面列表滑不动：开局把所有 ScrollContainer 都找出来挂上滑动
    var all_scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
    for s in all_scrolls:
        _setup_scroll(s)

func _on_node_added(node: Node):
    # 1. 宝箱限高
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            if "Shop" not in str(node.get_path()):
                _wrap_and_lock_crate(node)
        return
        
    # 2. 其他新生成的滚动框
    if node is ScrollContainer:
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            _setup_scroll(node)

# ============ 核心配置 ============
func _setup_scroll(scroll: ScrollContainer):
    # 让滚动框接收触摸
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    
    # 找出所有的开关（CheckButton）
    var buttons = scroll.find_children("*", "CheckButton", true, false)
    for btn in buttons:
        # 抄补丁作者的作业：干掉黑框，允许穿透
        var empty_style = StyleBoxEmpty.new()
        btn.add_stylebox_override("normal", empty_style)
        btn.add_stylebox_override("pressed", empty_style)
        btn.add_stylebox_override("focus", empty_style)
        btn.add_stylebox_override("disabled", empty_style)
        
        # 必须给 PASS，否则滑动事件下传不了
        btn.mouse_filter = Control.MOUSE_FILTER_PASS
        
        # 修复误触：直接挂上咱们自己的事件监听，如果滑动，就吃掉事件，不让按钮点击
        if not btn.is_connected("gui_input", self, "_on_btn_gui_input"):
            btn.connect("gui_input", self, "_on_btn_gui_input", [scroll, btn])

# 处理误触：当在按钮上拖动时，取消点击
func _on_btn_gui_input(event: InputEvent, scroll: ScrollContainer, btn: CheckButton):
    if event is InputEventScreenDrag:
        # 强行滚动
        scroll.scroll_vertical -= event.relative.y
        # 取消掉按钮的按下状态，这样松手时就不会触发 toggle 了
        if btn.pressed:
            btn.pressed = true 
        else:
            btn.pressed = false
        scroll.accept_event()

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
    _setup_scroll(scroll)
