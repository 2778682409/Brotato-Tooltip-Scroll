extends Node

var _has_scanned = false
var _timer: Timer

func _ready():
    _timer = Timer.new()
    _timer.wait_time = 0.5
    _timer.autostart = true
    _timer.connect("timeout", self, "_scan_and_show_log")
    add_child(_timer)

func _scan_and_show_log():
    if _has_scanned: return

    # 1. 寻找全屏幕字数最长的节点
    var longest_node = null
    var max_len = 0
    var stack = [get_tree().root]
    while stack.size() > 0:
        var node = stack.pop_back()
        if (node is Label or node is RichTextLabel) and "text" in node:
            if node.text.length() > max_len:
                max_len = node.text.length()
                longest_node = node
        for child in node.get_children():
            stack.push_back(child)

    # 2. 发现长文本，立刻生成“全息日志”
    if max_len > 50 and longest_node != null:
        _has_scanned = true
        _timer.stop()
        _build_holo_console(longest_node, max_len)

func _build_holo_console(target_node: Node, text_len: int):
    # 构建日志文本（类似 print 的格式）
    var log_text = "=== Brotato 全息日志 ===" + "\n\n"
    log_text += "[发现超长文本节点]" + "\n"
    log_text += "名字: " + str(target_node.name) + "\n"
    log_text += "类型: " + str(target_node.get_class()) + "\n"
    log_text += "字数: " + str(text_len) + "\n"
    log_text += "大小: " + str(target_node.rect_size) + "\n"
    log_text += "位置: " + str(target_node.rect_position) + "\n"
    log_text += "完整路径: " + str(target_node.get_path()) + "\n\n"
    
    # 顺便打一下它的父节点信息
    var parent = target_node.get_parent()
    if parent:
        log_text += "[父节点信息]" + "\n"
        log_text += "名字: " + str(parent.name) + "\n"
        log_text += "类型: " + str(parent.get_class()) + "\n"
        log_text += "大小: " + str(parent.rect_size) + "\n"
        log_text += "完整路径: " + str(parent.get_path()) + "\n\n"

    log_text += "[部分文本内容]" + "\n"
    log_text += target_node.text.substr(0, 100) + "..." + "\n"

    # 3. 在屏幕上画出这个日志面板
    var panel = Panel.new()
    panel.rect_size = get_viewport().size * 0.9
    panel.rect_position = get_viewport().size * 0.05
    
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.85) # 半透明黑色背景
    panel.add_stylebox_override("panel", style)

    # 加上滚动条，防止字太多看不过来
    var scroll = ScrollContainer.new()
    scroll.rect_min_size = panel.rect_size
    scroll.rect_size = panel.rect_size
    scroll.scroll_vertical_enabled = true
    scroll.scroll_horizontal_enabled = false
    panel.add_child(scroll)

    var label = RichTextLabel.new()
    label.bbcode_enabled = true
    label.text = log_text
    label.add_color_override("default_color", Color(0, 1, 0)) # 类似终端的绿色文字
    label.rect_min_size = Vector2(panel.rect_size.x - 20, 0)
    label.fit_content_height = true
    scroll.add_child(label)

    get_tree().root.call_deferred("add_child", panel)
