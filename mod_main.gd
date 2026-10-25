extends Node

var _processed = {}
var debug_label: Label  # 用来在屏幕上显示测试信息的标签

func _ready():
    # 1. 创建一个调试标签，直接贴在屏幕上
    debug_label = Label.new()
    debug_label.text = "✅ TooltipScroll 模组已加载！\n正在寻找超长词条节点..."
    debug_label.add_color_override("font_color", Color(0, 1, 0)) # 绿色
    debug_label.rect_position = Vector2(20, 100) # 屏幕左上角的位置
    # 把这个标签加到游戏的全局 UI 层
    get_tree().root.call_deferred("add_child", debug_label)

func _process(_delta):
    if not is_instance_valid(debug_label):
        return
        
    # 寻找弹窗节点
    var popups = _find_popups(get_tree().root)
    for popup in popups:
        if not is_instance_valid(popup) or _processed.has(popup):
            continue
        _wrap_description(popup)

func _wrap_description(popup_root: Node):
    var longest_text_node = _find_longest_text_node(popup_root)
    if longest_text_node == null:
        return

    # 2. 只要找到了长文本，就在屏幕上显示它的名字和长度
    var node_name = longest_text_node.name
    var text_len = longest_text_node.text.length()
    if is_instance_valid(debug_label):
        debug_label.text = "🔍 发现长文本节点！\n名字: " + node_name + "\n字数: " + str(text_len)

    var parent = longest_text_node.get_parent()
    if parent == null or parent is ScrollContainer:
        return

    var index = longest_text_node.get_index()
    parent.remove_child(longest_text_node)

    var scroll = ScrollContainer.new()
    scroll.name = "ModTooltipScroll"
    var max_height = get_viewport().size.y * 0.5
    scroll.rect_min_size = Vector2(parent.rect_size.x, max_height)
    scroll.scroll_horizontal_enabled = false
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(longest_text_node)

    if longest_text_node is Control:
        longest_text_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    _processed[popup_root] = true

# 逻辑和之前一样，寻找最长文本
func _find_longest_text_node(root: Node) -> Node:
    var best = null
    var best_len = 0
    var stack = [root]
    while stack.size() > 0:
        var node = stack.pop_back()
        # 跳过我们自己创建的调试标签
        if node == debug_label: continue 
        
        if node is Label or node is RichTextLabel:
            var text_len = node.text.length() if "text" in node else 0
            if text_len > best_len:
                best_len = text_len
                best = node
        for child in node.get_children():
            stack.push_back(child)
    
    if best_len < 30:
        return null
    return best

# 逻辑和之前一样，找弹窗
func _find_popups(root: Node) -> Array:
    var result = []
    # 跳过我们自己创建的调试标签
    if root == debug_label: return result
    
    if "popup" in root.name.to_lower() or "description" in root.name.to_lower():
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_popups(child))
    return result
