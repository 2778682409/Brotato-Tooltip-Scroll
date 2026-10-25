extends Node

var _timer: Timer
var _has_shown_for_current_popup = false

func _ready():
    _timer = Timer.new()
    _timer.wait_time = 0.5
    _timer.autostart = true
    _timer.connect("timeout", self, "_scan_and_show_log")
    add_child(_timer)

func _scan_and_show_log():
    var longest_node = null
    var max_len = 0
    var stack = [get_tree().root]
    
    # 找全屏最长文本
    while stack.size() > 0:
        var node = stack.pop_back()
        if (node is Label or node is RichTextLabel) and "text" in node:
            if node.text.length() > max_len:
                max_len = node.text.length()
                longest_node = node
        for child in node.get_children():
            stack.push_back(child)

    # 如果找到长文本
    if max_len > 50 and longest_node != null:
        var path = str(longest_node.get_path())
        
        # 🚫 防骗机制：如果路径里带有 TitleScreen（主菜单）或者 Credits（制作人），直接忽略！
        if "TitleScreen" in path or "Credits" in path or "Names" == longest_node.name:
            return
            
        # 🛑 防止重复弹窗：如果当前已经弹了，就不重复弹了
        if not _has_shown_for_current_popup:
            _has_shown_for_current_popup = true
            _build_holo_console(longest_node, max_len)
            
    else:
        # 如果没找到长文本（比如关掉弹窗了），重置状态，准备抓下一个
        _has_shown_for_current_popup = false

func _build_holo_console(target_node: Node, text_len: int):
    var log_text = "=== 抓到目标！请截图！ ===" + "\n\n"
    log_text += "名字: " + str(target_node.name) + "\n"
    log_text += "类型: " + str(target_node.get_class()) + "\n"
    log_text += "字数: " + str(text_len) + "\n"
    log_text += "大小: " + str(target_node.rect_size) + "\n"
    log_text += "完整路径: " + str(target_node.get_path()) + "\n\n"
    
    var parent = target_node.get_parent()
    if parent:
        log_text += "[父节点]" + "\n"
        log_text += "名字: " + str(parent.name) + "\n"
        log_text += "类型: " + str(parent.get_class()) + "\n"
        log_text += "完整路径: " + str(parent.get_path()) + "\n\n"

    log_text += "[文本内容]" + "\n"
    log_text += target_node.text.substr(0, 100) + "..." + "\n"

    # 画板子
    var panel = Panel.new()
    panel.rect_size = get_viewport().size * 0.9
    panel.rect_position = get_viewport().size * 0.05
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0, 0, 0, 0.85)
    panel.add_stylebox_override("panel", style)

    # 套滚动条
    var scroll = ScrollContainer.new()
    scroll.rect_min_size = panel.rect_size
    scroll.rect_size = panel.rect_size
    scroll.scroll_vertical_enabled = true
    scroll.scroll_horizontal_enabled = false
    panel.add_child(scroll)

    var label = RichTextLabel.new()
    label.bbcode_enabled = true
    label.text = log_text
    label.add_color_override("default_color", Color(0, 1, 0))
    label.rect_min_size = Vector2(panel.rect_size.x - 20, 0)
    label.fit_content_height = true
    scroll.add_child(label)

    # 加个按钮把它关掉（方便你继续玩游戏）
    var close_btn = Button.new()
    close_btn.text = "关闭日志"
    close_btn.rect_position = Vector2(panel.rect_size.x - 120, 10)
    close_btn.connect("pressed", panel, "queue_free")
    panel.add_child(close_btn)

    get_tree().root.call_deferred("add_child", panel)
