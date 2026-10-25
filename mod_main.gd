extends Node

var _processed = {}

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    if node.name != "ItemDescription":
        return
        
    var path = str(node.get_path())
    if _processed.has(node):
        return
        
    _processed[node] = true
    
    # 等两帧，让 UI 彻底排版出来
    yield(get_tree(), "idle_frame")
    yield(get_tree(), "idle_frame")
    
    if is_instance_valid(node):
        if "Shop" in path:
            _fix_shop_scroll(node)
        else:
            _wrap_and_lock_crate(node)

# ============ 商店专用：只加滑动，不改尺寸 ============
func _fix_shop_scroll(item_node: Node):
    var scroll = item_node.find_node("ScrollContainer", true, false)
    if not scroll: return
    
    # 1. 让里面的所有文字和图标忽略触摸，把事件让给滚动条
    _disable_mouse_in_children(scroll)
    
    # 2. 给滚动条接上手指滑动逻辑（防止重复连接）
    if not scroll.is_connected("gui_input", self, "_on_scroll_drag"):
        scroll.connect("gui_input", self, "_on_scroll_drag", [scroll])

# ============ 宝箱专用：套壳锁死 + 支持滑动 ============
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
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    scroll.clip_contents = true

    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(popup_root)
    
    if popup_root is Control:
        popup_root.rect_position = Vector2(0, 0)
        popup_root.rect_min_size.x = orig_width
        popup_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
        
    # 让里面的文字不拦截触摸，并加上拖拽手势
    _disable_mouse_in_children(scroll)
    scroll.connect("gui_input", self, "_on_scroll_drag", [scroll])

# 核心工具：让所有文字节点无视鼠标/触摸
func _disable_mouse_in_children(node: Node):
    for child in node.get_children():
        if child is Label or child is RichTextLabel or child is TextureRect:
            child.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _disable_mouse_in_children(child)

# 核心工具：手指上下滑动，直接控制滚动条
func _on_scroll_drag(event: InputEvent, scroll: ScrollContainer):
    # 监听手机手指拖拽事件
    if event is InputEventScreenDrag:
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event() # 告诉引擎：我处理了这个事件，别往下传了
    # 顺便兼容一下如果你接了鼠标玩
    elif event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT:
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
