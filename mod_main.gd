extends Node

var _has_logged = false
var _timer: Timer

func _ready():
    _timer = Timer.new()
    _timer.wait_time = 0.5
    _timer.autostart = true
    _timer.connect("timeout", self, "_scan_and_log")
    add_child(_timer)

func _scan_and_log():
    if _has_logged:
        return
        
    # 只要发现有高度超过 250 的界面元素，说明宝箱弹出来了
    var target = _find_long_node(get_tree().root)
    if target != null:
        _has_logged = true
        _timer.stop()
        _write_to_file()

func _find_long_node(root: Node) -> Node:
    var stack = [root]
    while stack.size() > 0:
        var node = stack.pop_back()
        if node is Control:
            # 避开按钮和普通文字，找那种大容器
            if node.rect_size.y > 250 and "label" not in node.name.to_lower() and "button" not in node.name.to_lower():
                return node
        for child in node.get_children():
            stack.push_back(child)
    return null

func _write_to_file():
    var log_text = "=== Brotato UI 节点日志 ===\n\n"
    var stack = [get_tree().root]
    
    # 把长文本、弹窗相关的节点信息全抓出来
    while stack.size() > 0:
        var node = stack.pop_back()
        if node is Control:
            var n_name = String(node.name).to_lower()
            if node.rect_size.y > 150 or "pop" in n_name or "desc" in n_name or "tooltip" in n_name:
                log_text += "名字: " + String(node.name) + " | 类型: " + node.get_class() + " | 高度: " + str(node.rect_size.y) + " | 路径: " + str(node.get_path()) + "\n"
        for child in node.get_children():
            stack.push_back(child)
            
    var file = File.new()
    # 写入到 user:// 目录
    var err = file.open("user://brotato_ui_debug.txt", File.WRITE)
    if err == OK:
        file.store_string(log_text)
        file.close()
        
        # 屏幕左上角给个微小的提示，证明写成功了
        var label = Label.new()
        label.text = "✅ 日志已写入！"
        label.add_color_override("font_color", Color(0, 1, 0))
        label.rect_position = Vector2(10, 10)
        get_tree().root.call_deferred("add_child", label)
