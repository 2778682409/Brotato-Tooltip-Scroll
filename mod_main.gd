extends Node

var _processed = {}
var _known_popups = {}

func _ready():
    var timer = Timer.new()
    timer.wait_time = 0.5
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
    # 只找纯文本节点，不找容器
    var target_node = _find_longest_text(popup_root)
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

# 精准抓取文本：只找 Label 或 RichTextLabel，且字数必须超过 20 个字
func _find_longest_text(root: Node) -> Node:
    var best = null
    var best_len = 0
    var stack = [root]
    while stack.size() > 0:
        var node = stack.pop_back()
        if node is RichTextLabel or node is Label:
            var text_len = node.text.length() if "text" in node else 0
            if text_len > best_len:
                best_len = text_len
                best = node
        for child in node.get_children():
            stack.push_back(child)
            
    if best_len < 20:
        return null
    return best

# 严格匹配弹窗名字，绝不让商店卡片混进来
func _find_popups_fast(root: Node) -> Array:
    var result = []
    var r_name = root.name.to_lower()
    
    # 只认这三个精准的名字
    if "item_popup" in r_name or "item_description" in r_name or "tooltip" in r_name:
        result.append(root)
        
    for child in root.get_children():
        result.append_array(_find_popups_fast(child))
    return result
