extends Node

var _timer: Timer
var _processed = []
var _status_label: Label

func _ready():
    # 右上角指示灯
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    _status_label = Label.new()
    _status_label.text = "✅ 模组已运行 (修剪模式)"
    _status_label.add_color_override("font_color", Color(0, 1, 0))
    _status_label.add_color_override("font_outline_color", Color(0, 0, 0))
    _status_label.add_constant_override("outline_size", 4)
    _status_label.anchor_left = 1.0
    _status_label.anchor_right = 1.0
    _status_label.margin_left = -250
    _status_label.margin_right = -20
    _status_label.margin_top = 20
    _status_label.align = Label.ALIGN_RIGHT
    canvas.add_child(_status_label)

    _timer = Timer.new()
    _timer.wait_time = 0.5
    _timer.autostart = true
    _timer.connect("timeout", self, "_trim_scroll")
    add_child(_timer)

func _trim_scroll():
    var targets = _find_nodes_by_name(get_tree().root, "ItemDescription")
    
    for target in targets:
        if target in _processed: continue
        var path = str(target.get_path())
        
        # 绝对不碰商店，商店原版就是完美的
        if "Shop" in path:
            continue
            
        # 找到它里面的原生滚动条
        var scroll = target.find_node("ScrollContainer", true, false)
        if scroll:
            _processed.append(target)
            
            # 设定一个安全高度（比如 350 像素，可以根据你手机屏幕自己调）
            var safe_height = 350.0
            
            # 只有当内容高度超过安全高度时，才去限制它
            var inner_vbox = scroll.get_child(0)
            if inner_vbox and inner_vbox.rect_size.y > safe_height:
                scroll.rect_min_size = Vector2(scroll.rect_size.x, safe_height)
                scroll.rect_size = Vector2(scroll.rect_size.x, safe_height)
                scroll.scroll_vertical_enabled = true
                
                if is_instance_valid(_status_label):
                    _status_label.text = "✅ 已成功折叠超长词条！"

func _find_nodes_by_name(root: Node, target_name: String) -> Array:
    var result = []
    if root.name == target_name:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_nodes_by_name(child, target_name))
    return result
