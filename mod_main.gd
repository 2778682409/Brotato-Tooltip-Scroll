extends Node

var _processed = {}

func _ready():
    # 1. 监听后续生成的 UI（比如设置界面、宝箱）
    get_tree().connect("node_added", self, "_on_node_added")
    
    # 2. 延迟一帧，扫描一遍游戏启动时已经存在的主界面 Mod 列表
    call_deferred("_scan_initial_ui")

# 只处理两件事：开关变透明，宝箱限高
func _on_node_added(node: Node):
    # 处理开关
    if node is CheckButton:
        _make_button_slideable(node)
        return

    # 处理宝箱物品描述
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        call_deferred("_process_item_description", node)

func _scan_initial_ui():
    # 把一开始就在树里的开关全抓出来处理掉
    var all_btns = get_tree().root.find_children("*", "CheckButton", true, false)
    for btn in all_btns:
        _make_button_slideable(btn)

# 核心：让开关变透明，允许事件穿透给底下的滚动框
func _make_button_slideable(btn: CheckButton):
    if btn.has_meta("mod_slide_fixed"): return
    btn.set_meta("mod_slide_fixed", true)
    
    # 允许滑动事件穿透
    btn.mouse_filter = Control.MOUSE_FILTER_PASS
    
    # 抄作业：干掉黑色大背景
    var empty_style = StyleBoxEmpty.new()
    btn.add_stylebox_override("normal", empty_style)
    btn.add_stylebox_override("pressed", empty_style)
    btn.add_stylebox_override("focus", empty_style)
    btn.add_stylebox_override("disabled", empty_style)

# 处理宝箱限高
func _process_item_description(node: Node):
    yield(get_tree(), "idle_frame")
    yield(get_tree(), "idle_frame")
    if not is_instance_valid(node): return
    
    var path = str(node.get_path())
    # 只处理不是商店的（宝箱、升级）
    if "Shop" not in path:
        _wrap_and_lock_crate(node)

func _wrap_and_lock_crate(popup_root: Control):
    var parent = popup_root.get_parent()
    if not parent or parent is ScrollContainer:
        return

    var index = popup_root.get_index()
    var orig_pos = popup_root.rect_position
    var orig_width = popup_root.rect_size.x
    
    parent.remove_child(popup_root)

    var scroll = ScrollContainer.new()
    scroll.name = "ModTooltipScroll"
    var fixed_height = 400.0
    
    scroll.rect_position = orig_pos
    scroll.rect_min_size = Vector2(orig_width, fixed_height)
    scroll.rect_size = Vector2(orig_width, fixed_height)
    scroll.scroll_horizontal_enabled = false
    scroll.scroll_vertical_enabled = true
    scroll.clip_contents = true

    parent.add_child(scroll)
    parent.move_child(scroll, index)
    scroll.add_child(popup_root)
    
    if popup_root is Control:
        popup_root.rect_position = Vector2(0, 0)
        popup_root.rect_min_size.x = orig_width
        popup_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
