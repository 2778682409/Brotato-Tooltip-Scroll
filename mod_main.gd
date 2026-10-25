extends Node

var _timer: Timer
var _processed = {}

func _ready():
    _timer = Timer.new()
    _timer.wait_time = 0.5
    _timer.autostart = true
    _timer.connect("timeout", self, "_force_fix_ui")
    add_child(_timer)

func _force_fix_ui():
    # 清理已销毁的节点
    for key in _processed.keys():
        if not is_instance_valid(key):
            _processed.erase(key)

    # 全图精准搜索 ItemDescription
    var targets = _find_nodes_by_name(get_tree().root, "ItemDescription")
    
    for target in targets:
        if _processed.has(target):
            continue
            
        var path = str(target.get_path())
        
        # 依旧不碰商店
        if "Shop" in path or "shop" in path:
            continue
            
        # 只要是宝箱界面的弹窗，咱们直接暴力修改它的外壳尺寸
        _processed[target] = true
        
        # 强行把整个弹窗的高度锁死在屏幕的 45%
        var max_h = get_viewport().size.y * 0.45
        target.rect_min_size = Vector2(target.rect_min_size.x, max_h)
        target.rect_size = Vector2(target.rect_size.x, max_h)
        
        # 确保里面的滚动容器是开启状态
        var scroll = target.find_node("ScrollContainer", true, false)
        if scroll:
            scroll.scroll_vertical_enabled = true
            # 撑满整个弹窗
            scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

# 递归找节点
func _find_nodes_by_name(root: Node, target_name: String) -> Array:
    var result = []
    if root.name == target_name:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_nodes_by_name(child, target_name))
    return result
