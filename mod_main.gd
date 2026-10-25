extends Node

var _timer: Timer
var _processed = {}

func _ready():
    _timer = Timer.new()
    _timer.wait_time = 0.5
    _timer.autostart = true
    _timer.connect("timeout", self, "_fix_chest_ui")
    add_child(_timer)

func _fix_chest_ui():
    # 清理已失效的节点
    for key in _processed.keys():
        if not is_instance_valid(key):
            _processed.erase(key)

    var targets = _find_nodes_by_name(get_tree().root, "ItemDescription")
    for target in targets:
        if _processed.has(target):
            continue
            
        var path = str(target.get_path())
        
        # 🚫 核心防御：绝对不碰商店（Shop）的 UI，商店原版是正常的！
        if "Shop" in path or "shop" in path:
            continue

        # 找到原版的滚动条
        var scroll = target.find_node("ScrollContainer", true, false)
        if scroll and scroll.get_child_count() > 0:
            var inner = scroll.get_child(0)
            if inner.rect_size.y <= 0:
                continue
                
            _processed[target] = true
            
            # 设定一个最大允许高度
            var max_h = get_viewport().size.y * 0.45
            
            # 🛠️ 智能修复：如果文字超长了，才限制高度；如果没超长，恢复原版计算！
            if inner.rect_size.y > max_h:
                scroll.rect_min_size = Vector2(scroll.rect_min_size.x, max_h)
                scroll.scroll_vertical_enabled = true
            else:
                # 没超长就让它自己收缩，去掉多余的空白
                scroll.rect_min_size = Vector2(scroll.rect_min_size.x, 0)
                scroll.rect_min_size = Vector2(scroll.rect_min_size.x, inner.rect_size.y)

# 递归找名字匹配的节点
func _find_nodes_by_name(root: Node, target_name: String) -> Array:
    var result = []
    if root.name == target_name:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_nodes_by_name(child, target_name))
    return result
