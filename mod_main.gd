extends Node

var _processed = {}

func _ready():
    # 关键手术1：扔掉定时器，改为监听引擎的“节点诞生”信号
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 只要新出来的节点名字不叫 ItemDescription，直接放行
    if node.name != "ItemDescription":
        return
        
    var path = str(node.get_path())
    
    # 关键手术2：绝对不碰商店！
    # 只有路径里包含 WeaponSelection（宝箱），且不包含 Shop（商店）才处理
    if "WeaponSelection" not in path or "Shop" in path:
        return
        
    if _processed.has(node):
        return
        
    _processed[node] = true
    
    # 等两帧，让游戏把它的基础坐标和大小算出来，防止偏移
    yield(get_tree(), "idle_frame")
    yield(get_tree(), "idle_frame")
    
    if is_instance_valid(node):
        _wrap_description(node)

func _wrap_description(popup_root: Node):
    # 原封不动保留你喜欢的：找高度最长的那个节点
    var target_node = _find_tallest_node(popup_root)
    if target_node == null:
        return

    var parent = target_node.get_parent()
    if parent == null or parent is ScrollContainer:
        return

    # 记录它原本的位置和尺寸，防止套壳后偏移
    var index = target_node.get_index()
    var orig_pos = target_node.rect_position
    
    parent.remove_child(target_node)

    var scroll = ScrollContainer.new()
    scroll.name = "ModTooltipScroll"
    
    # 锁定高度为屏幕的 45%
    var max_height = get_viewport().size.y * 0.45
    var max_width = parent.rect_size.x if parent.rect_size.x > 0 else 400
    scroll.rect_min_size = Vector2(max_width, max_height)
    
    # 继承原来的位置（防止偏移）
    scroll.rect_position = orig_pos
    scroll.scroll_horizontal_enabled = false
    scroll.scroll_vertical_enabled = true
    
    # 允许触摸滑动
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS

    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(target_node)

    if target_node is Control:
        target_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        target_node.rect_position = Vector2(0, 0) # 内容归零

# 原封不动保留你的找高个子逻辑
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
