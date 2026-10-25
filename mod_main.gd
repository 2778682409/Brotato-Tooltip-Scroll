extends Node

var _processed = {}
var _scan_timer = 0.0

func _ready():
    # 用定时器，每 0.5 秒才扫描一次，彻底解决卡顿！
    var timer = Timer.new()
    timer.wait_time = 0.5
    timer.autostart = true
    timer.connect("timeout", self, "_scan_for_popups")
    add_child(timer)

func _scan_for_popups():
    var popups = _find_popups(get_tree().root)
    for popup in popups:
        if not is_instance_valid(popup) or _processed.has(popup):
            continue
        _wrap_description(popup)

func _wrap_description(popup_root: Node):
    # 找高度最长的那个节点（包含词条的容器）
    var target_node = _find_tallest_node(popup_root)
    if target_node == null:
        return

    var parent = target_node.get_parent()
    if parent == null or parent is ScrollContainer:
        return

    var index = target_node.get_index()
    parent.remove_child(target_node)

    var scroll = ScrollContainer.new()
    scroll.name = "ModTooltipScroll"
    
    # 锁定高度为屏幕的 45%
    var max_height = get_viewport().size.y * 0.45
    var max_width = parent.rect_size.x if parent.rect_size.x > 0 else 400
    scroll.rect_min_size = Vector2(max_width, max_height)
    scroll.scroll_horizontal_enabled = false
    scroll.scroll_vertical_enabled = true
    
    # 关键：允许触摸滑动
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS

    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(target_node)

    if target_node is Control:
        target_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    _processed[popup_root] = true

# 专门找高度超过 300 的大容器，不管它叫什么名字
func _find_tallest_node(root: Node) -> Node:
    var best = null
    var max_height = 0
    var stack = [root]
    while stack.size() > 0:
        var node = stack.pop_back()
        if node is Control:
            if node.rect_size.y > max_height and node.rect_size.y > 300:
                max_height = node.rect_size.y
                best = node
        for child in node.get_children():
            stack.push_back(child)
    return best

func _find_popups(root: Node) -> Array:
    var result = []
    if "popup" in root.name.to_lower() or "description" in root.name.to_lower():
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_popups(child))
    return result
