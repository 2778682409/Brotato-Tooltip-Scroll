extends Node

var _processed = {}

func _process(_delta):
    # 寻找名字里带 "popup" 或 "description" 的节点
    var popups = _find_popups(get_tree().root)
    for popup in popups:
        if not is_instance_valid(popup) or _processed.has(popup):
            continue
        _wrap_description(popup)

func _wrap_description(popup_root: Node):
    # 寻找弹窗里那个最长的文本节点（也就是撑爆屏幕的罪魁祸首）
    var longest_text_node = _find_longest_text_node(popup_root)
    if longest_text_node == null:
        return

    var parent = longest_text_node.get_parent()
    if parent == null or parent is ScrollContainer:
        return # 已经包裹过或者没父节点就跳过

    # 记录原位置，准备替换
    var index = longest_text_node.get_index()
    parent.remove_child(longest_text_node)

    # 创建滚动容器
    var scroll = ScrollContainer.new()
    scroll.name = "ModTooltipScroll"
    
    # ⚠️ 关键：限制最大高度（屏幕的50%），这样就不会超出屏幕了
    var max_height = get_viewport().size.y * 0.5
    scroll.rect_min_size = Vector2(parent.rect_size.x, max_height)
    scroll.scroll_horizontal_enabled = false
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

    # 把滚动条塞回原位，把文本塞进滚动条
    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(longest_text_node)

    # 让文本填满宽度
    if longest_text_node is Control:
        longest_text_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    _processed[popup_root] = true
    print("[TooltipScroll] 成功为物品描述添加了滚动条！")

# 在节点树中寻找最长的文本
func _find_longest_text_node(root: Node) -> Node:
    var best = null
    var best_len = 0
    var stack = [root]
    while stack.size() > 0:
        var node = stack.pop_back()
        if node is Label or node is RichTextLabel:
            var text_len = node.text.length() if "text" in node else 0
            if text_len > best_len:
                best_len = text_len
                best = node
        for child in node.get_children():
            stack.push_back(child)
    
    # 如果文本太短（比如只有物品名字），就认为没找到
    if best_len < 30:
        return null
    return best

# 寻找所有弹窗节点
func _find_popups(root: Node) -> Array:
    var result = []
    if "popup" in root.name.to_lower() or "description" in root.name.to_lower():
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_popups(child))
    return result
