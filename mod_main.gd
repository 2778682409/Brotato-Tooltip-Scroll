extends Node

var _processed = {}

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 1. 处理宝箱的限高套壳
    if node.name == "ItemDescription":
        if _processed.has(node):
            return
        _processed[node] = true
        
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        
        if is_instance_valid(node):
            var path = str(node.get_path())
            if "Shop" not in path:
                _wrap_and_lock_crate(node)
        return
        
    # 2. 把滚动框里的文字全部变透明，防止它们拦截触摸
    if node is ScrollContainer:
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            _set_mouse_ignore_for_text(node)

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
        
    _set_mouse_ignore_for_text(scroll)

# 只让纯文本和图片忽略触摸，保留按钮的点击功能
func _set_mouse_ignore_for_text(node: Node):
    for child in node.get_children():
        if child is Label or child is RichTextLabel or child is TextureRect:
            child.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _set_mouse_ignore_for_text(child)

# ============ 核心魔法：只要滑，就全部滚！ ============
func _input(event: InputEvent):
    # 监听手机手指拖拽
    if event is InputEventScreenDrag:
        var handled = false
        
        # 暴力找出当前场景树里所有的滚动框
        var all_scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
        
        for scroll in all_scrolls:
            # 只要它在屏幕上露出来了，直接给它滚！
            if is_instance_valid(scroll) and scroll.is_visible_in_tree():
                scroll.scroll_vertical -= event.relative.y
                handled = true
                
        # 如果成功滚动了，就吃掉这个事件，防止底层界面误触
        if handled:
            get_tree().set_input_as_handled()
