extends Node

var _processed = {}
var _known_popups = {}

func _ready():
    var timer = Timer.new()
    timer.wait_time = 1.0 # 1秒扫一次，绝对不卡
    timer.autostart = true
    timer.connect("timeout", self, "_scan_for_popups")
    add_child(timer)

func _scan_for_popups():
    for popup in _known_popups.keys():
        if is_instance_valid(popup) and not _processed.has(popup):
            _wrap_description(popup)
            
    var popups = _find_popups_fast(get_tree().root)
    for popup in popups:
        if not is_instance_valid(popup) or _processed.has(popup):
            continue
        _wrap_description(popup)

func _wrap_description(popup_root: Node):
    # 恢复抓取“高度大于250的大容器”逻辑（宝箱完美生效的版本）
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
    
    var max_height = get_viewport().size.y * 0.45
    var max_width = parent.rect_size.x if parent.rect_size.x > 0 else 400
    scroll.rect_min_size = Vector2(max_width, max_height)
    scroll.scroll_horizontal_enabled = false
    scroll.scroll_vertical_enabled = true
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS

    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(target_node)

    if target_node is Control:
        target_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    _processed[popup_root] = true
    _known_popups[popup_root] = true

func _find_tallest_node(root: Node) -> Node:
    var best = null
    var max_height = 0
    var stack = [root]
    while stack.size() > 0:
        var node = stack.pop_back()
        if node is Control:
            if node.rect_size.y > max_height and node.rect_size.y > 250:
                max_height = node.rect_size.y
                best = node
        for child in node.get_children():
            stack.push_back(child)
    return best

func _find_popups_fast(root: Node) -> Array:
    var result = []
    var r_name = root.name.to_lower()
    
    # ⚠️ 核心防误伤：只要名字里带 shop，直接跳过整个节点及其子节点！
    if "shop" in r_name:
        return result
        
    # 名字条件放宽，确保宝箱能被抓到
    if "pop" in r_name or "desc" in r_name or "tooltip" in r_name:
        result.append(root)
        
    for child in node_children(root):
        result.append_array(_find_popups_fast(child))
    return result

# 辅助函数，兼容不同Godot版本的获取子节点方法
func node_children(node: Node) -> Array:
    return node.get_children()
