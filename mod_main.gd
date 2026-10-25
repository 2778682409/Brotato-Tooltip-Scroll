extends Node

var _scan_timer = 0.0
var _has_scanned = false
var _debug_label: Label

func _ready():
    var timer = Timer.new()
    timer.wait_time = 0.5
    timer.autostart = true
    timer.connect("timeout", self, "_check_for_popup")
    add_child(timer)

func _check_for_popup():
    if _has_scanned:
        return
        
    var found_node = _find_trigger_node(get_tree().root)
    if found_node != null:
        _has_scanned = true
        _show_debug_info(found_node)

# 寻找触发节点（找那个高度很大、占满屏幕的容器）
func _find_trigger_node(root: Node) -> Node:
    var stack = [root]
    while stack.size() > 0:
        var node = stack.pop_back()
        if node is Control:
            # 抓取高度大于 250 的大框框
            if node.rect_size.y > 250 and "label" not in node.name.to_lower() and "button" not in node.name.to_lower():
                return node
        for child in node.get_children():
            stack.push_back(child)
    return null

# 在屏幕上展示探针数据
func _show_debug_info(trigger_node: Node):
    var text = "🔍 抓到红框了！请截图！\n\n"
    var current = trigger_node
    
    # 往上找 3 层父节点，看看它到底叫啥
    for i in range(3):
        if current != null:
            text += "【层级 " + str(i) + "】\n名字: " + String(current.name) + "\n类型: " + current.get_class() + "\n高度: " + str(current.rect_size.y) + "\n\n"
            current = current.get_parent()
            
    # 创建一个黑边绿字的巨大标签，盖在屏幕左边
    _debug_label = Label.new()
    _debug_label.text = text
    _debug_label.add_color_override("font_color", Color(0, 1, 0))
    _debug_label.add_color_override("font_outline_color", Color(0, 0, 0))
    _debug_label.add_constant_override("outline_size", 5)
    _debug_label.rect_position = Vector2(30, 150)
    _debug_label.rect_size = Vector2(600, 800)
    get_tree().root.call_deferred("add_child", _debug_label)
