extends Node

var _timer: Timer
var _has_logged = false
var _status_label: Label

const LOG_DIR = "/storage/emulated/0/Download/Brotato/"
const LOG_FILE = "/storage/emulated/0/Download/Brotato/ui_tree_debug.txt"

func _ready():
    # 1. 创建右上角常驻状态指示灯
    var canvas = CanvasLayer.new()
    canvas.layer = 100 # 确保在最顶层
    add_child(canvas)
    
    _status_label = Label.new()
    _status_label.text = "✅ Tooltip Scroll 运行中"
    _status_label.add_color_override("font_color", Color(0, 1, 0)) # 亮绿色
    _status_label.add_color_override("font_outline_color", Color(0, 0, 0)) # 黑边
    _status_label.add_constant_override("outline_size", 4)
    
    # 定位在右上角
    _status_label.anchor_left = 1.0
    _status_label.anchor_right = 1.0
    _status_label.margin_left = -250
    _status_label.margin_right = -20
    _status_label.margin_top = 20
    _status_label.align = Label.ALIGN_RIGHT
    canvas.add_child(_status_label)

    # 2. 开始定时检测弹窗
    _timer = Timer.new()
    _timer.wait_time = 0.5
    _timer.autostart = true
    _timer.connect("timeout", self, "_check_and_log")
    add_child(_timer)

func _check_and_log():
    if _has_logged: return
    
    var target = _find_target(get_tree().root)
    if target != null:
        _has_logged = true
        _timer.stop()
        _write_to_file(target)

func _find_target(root: Node) -> Node:
    if root.name == "ItemDescription":
        if root is Control and root.is_visible_in_tree() and root.rect_size.y > 100:
            return root
    for child in root.get_children():
        var res = _find_target(child)
        if res != null:
            return res
    return null

func _build_tree_string(node: Node, depth: int) -> String:
    var indent = ""
    for i in range(depth):
        indent += "  "
        
    var info = indent + "|-- [" + node.get_class() + "] " + str(node.name)
    
    if node is Control:
        info += " | 大小: " + str(node.rect_size) + " | 坐标: " + str(node.rect_position)
        
    if (node is Label or node is RichTextLabel) and "text" in node:
        info += " | 字数: " + str(node.text.length())
        
    info += "\n" + indent + "    └ 路径: " + str(node.get_path()) + "\n"
    
    for child in node.get_children():
        info += _build_tree_string(child, depth + 1)
    return info

func _write_to_file(target: Node):
    var full_text = "=== Brotato 物品弹窗全量场景树 ===\n"
    full_text += _build_tree_string(target, 0)

    var dir = Directory.new()
    if not dir.dir_exists(LOG_DIR):
        dir.make_dir_recursive(LOG_DIR)

    var file = File.new()
    var err = file.open(LOG_FILE, File.WRITE)
    
    if err == OK:
        file.store_string(full_text)
        file.close()
        # 写入成功，更新右上角的指示灯
        if is_instance_valid(_status_label):
            _status_label.text = "✅ 日志已成功写入 Download/Brotato"
    else:
        if is_instance_valid(_status_label):
            _status_label.text = "❌ 写入失败，错误码: " + str(err)
            _status_label.add_color_override("font_color", Color(1, 0, 0)) # 变红
