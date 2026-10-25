extends Node

var _processed = {}

func _ready():
    # 进游戏给个指示灯，证明它活着
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    var label = Label.new()
    label.text = "✅ 终极原生滑动已加载"
    label.add_color_override("font_color", Color(0, 1, 0))
    label.add_color_override("font_outline_color", Color(0, 0, 0))
    label.add_constant_override("outline_size", 4)
    label.rect_position = Vector2(20, 20)
    canvas.add_child(label)
    
    # 监听新生成的界面
    get_tree().connect("node_added", self, "_on_node_added")
    # 启动时主动扫描一遍已有的主界面列表
    call_deferred("_scan_existing_scrolls")

func _scan_existing_scrolls():
    var all_scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
    for s in all_scrolls:
        _setup_native_scroll(s)

func _on_node_added(node: Node):
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            if "Shop" not in str(node.get_path()):
                _wrap_and_lock_crate(node)
        return
        
    if node is ScrollContainer:
        if _processed.has(node): return
        _processed[node] = true
        _setup_native_scroll(node)

# ============ 核心：全量打通事件，交给原生引擎！ ============
func _setup_native_scroll(scroll: ScrollContainer):
    if not is_instance_valid(scroll): return
    # 确保滚动框自己完全接管触摸
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _process_children(scroll)

func _process_children(node: Node):
    for child in node.get_children():
        if child is Control:
            # 1. 文字和图片直接设为透明（无视触摸）
            if child is Label or child is RichTextLabel or child is TextureRect:
                child.mouse_filter = Control.MOUSE_FILTER_IGNORE
                
            # 2. 滚动条自己保留
            elif child is ScrollBar:
                pass
                
            # 3. 按钮和【所有容器】全部设为 PASS，让事件能穿透到底层！
            else:
                child.mouse_filter = Control.MOUSE_FILTER_PASS
                
            # 如果是开关，干掉它丑陋的大黑框
            if child is CheckButton:
                var empty_style = StyleBoxEmpty.new()
                child.add_stylebox_override("normal", empty_style)
                child.add_stylebox_override("pressed", empty_style)
                child.add_stylebox_override("focus", empty_style)
                child.add_stylebox_override("disabled", empty_style)

            _process_children(child)

# ============ 宝箱套壳限高 ============
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
        
    _setup_native_scroll(scroll)
