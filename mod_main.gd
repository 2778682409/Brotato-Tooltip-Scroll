extends Node

var _processed = {}
var _scan_timer = 0.0
var _cached_path: NodePath = "" # 记住成功找到的路径，下次直接瞬移过去

func _ready():
    var timer = Timer.new()
    timer.wait_time = 1.0 # 降低频率，1秒扫一次就够了
    timer.autostart = true
    timer.connect("timeout", self, "_scan_for_popups")
    add_child(timer)

func _scan_for_popups():
    # 1. 如果已经记住了路径，直接去那个路径找，0卡顿！
    if _cached_path != "":
        var cached_popup = get_node_or_null(_cached_path)
        if cached_popup != null and not _processed.has(cached_popup):
            _wrap_description(cached_popup)
            return

    # 2. 如果没找到过，或者节点变了，才去扫描。只扫 UI 层！
    var popups = _find_popups_fast(get_tree().root)
    for popup in popups:
        if not is_instance_valid(popup) or _processed.has(popup):
            continue
        _wrap_description(popup)

func _wrap_description(popup_root: Node):
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
    
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS

    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(target_node)

    if target_node is Control:
        target_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    _processed[popup_root] = true
    
    # 核心优化：记住这个弹窗的绝对路径！下次直接找它！
    _cached_path = popup_root.get_path()

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

# 优化扫描：跳过名字带 "Game" 或者 "Entities" 的怪物节点，只找 UI
func _find_popups_fast(root: Node) -> Array:
    var result = []
    # 避开游戏世界实体，极大减少扫描量
    if "entity" in root.name.to_lower() or "game" in root.name.to_lower() or "map" in root.name.to_lower():
        return result
        
    if "popup" in root.name.to_lower() or "description" in root.name.to_lower():
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_popups_fast(child))
    return result
