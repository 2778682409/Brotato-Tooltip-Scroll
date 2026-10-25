extends Node

var _timer: Timer
var _processed = []

func _ready():
    _timer = Timer.new()
    _timer.wait_time = 1.0
    _timer.autostart = true
    _timer.connect("timeout", self, "_fix_scroll_height")
    add_child(_timer)

func _fix_scroll_height():
    # 全图寻找名字叫 ItemDescription 的节点
    var targets = _find_nodes_by_name(get_tree().root, "ItemDescription")
    for target in targets:
        if target in _processed:
            continue
            
        # 在它下面找原生的 ScrollContainer
        var scroll = target.find_node("ScrollContainer", true, false)
        if scroll:
            # 强行限制它的最小高度，且最大不超过 350
            scroll.rect_min_size = Vector2(scroll.rect_size.x, 350)
            scroll.rect_size = Vector2(scroll.rect_size.x, 350)
            # 确保纵向滚动开启
            scroll.scroll_vertical_enabled = true
            _processed.append(target)

# 递归找名字匹配的节点
func _find_nodes_by_name(root: Node, target_name: String) -> Array:
    var result = []
    if root.name == target_name:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_nodes_by_name(child, target_name))
    return result
