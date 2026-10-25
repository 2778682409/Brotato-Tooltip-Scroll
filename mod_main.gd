extends Node

var _processed = {}

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")
    call_deferred("_scan_initial_ui")

# 扫描一遍游戏启动时已经存在的 UI
func _scan_initial_ui():
    var all_btns = get_tree().root.find_children("*", "CheckButton", true, false)
    for btn in all_btns:
        _make_button_pass(btn)

func _on_node_added(node: Node):
    # 1. 处理开关（去掉黑框，允许事件穿透）
    if node is CheckButton:
        _make_button_pass(node)
        return

    # 2. 处理宝箱限高（绝对不碰商店）
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        call_deferred("_process_item_description", node)

# 核心：干掉大黑框，让事件能传给原生滚动条
func _make_button_pass(btn: CheckButton):
    if btn.has_meta("mod_slide_fixed"): return
    btn.set_meta("mod_slide_fixed", true)
    
    # 允许事件传给底层的 ScrollContainer
    btn.mouse_filter = Control.MOUSE_FILTER_PASS
    
    # 抄补丁作者的绝招：干掉黑色大背景
    var empty_style = StyleBoxEmpty.new()
    btn.add_stylebox_override("normal", empty_style)
    btn.add_stylebox_override("pressed", empty_style)
    btn.add_stylebox_override("focus", empty_style)
    btn.add_stylebox_override("disabled", empty_style)
    
    # 连接鼠标悬停高亮（补丁作者连这个都做了）
    var hover_style = btn.get_stylebox("hover")
    if hover_style != null:
        btn.add_stylebox_override("hover_pressed", hover_style)
        btn.connect("mouse_entered", self, "_on_btn_entered", [btn, hover_style])
        btn.connect("mouse_exited", self, "_on_btn_exited", [btn, empty_style])

func _on_btn_entered(btn: CheckButton, hover_style: StyleBox):
    if btn.pressed:
        btn.add_stylebox_override("pressed", hover_style)

func _on_btn_exited(btn: CheckButton, empty_style: StyleBox):
    btn.add_stylebox_override("pressed", empty_style)

# ============ 宝箱限高 ============
func _process_item_description(node: Node):
    yield(get_tree(), "idle_frame")
    yield(get_tree(), "idle_frame")
    if not is_instance_valid(node): return
    if "Shop" not in str(node.get_path()):
        _wrap_and_lock_crate(node)

func _wrap_and_lock_crate(popup_root: Control):
    var parent = popup_root.get_parent()
    if not parent or parent is ScrollContainer: return
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
