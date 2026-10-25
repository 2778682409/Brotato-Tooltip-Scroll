extends Node

var _processed = {}

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 1. 处理开关（去掉黑框，允许穿透）
    if node is CheckButton:
        if _processed.has(node): return
        _processed[node] = true
        _process_check_button(node)
        return

    # 2. 处理文字（完全穿透，不拦截触摸）
    if node is Label or node is RichTextLabel:
        node.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return

    # 3. 处理宝箱限高（完全不碰商店）
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        
        if is_instance_valid(node):
            var path = str(node.get_path())
            if "Shop" not in path:
                _wrap_and_lock_crate(node)
        return

# ============ 抄作业：开关去黑框 ============
func _process_check_button(btn: CheckButton):
    var empty_style = StyleBoxEmpty.new()
    btn.add_stylebox_override("normal", empty_style)
    btn.add_stylebox_override("pressed", empty_style)
    btn.add_stylebox_override("focus", empty_style)
    btn.add_stylebox_override("disabled", empty_style)
    
    # 允许事件传递给底层的 ScrollContainer
    btn.mouse_filter = Control.MOUSE_FILTER_PASS

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
