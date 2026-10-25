extends Node

var _processed = {}

# Touch Slide 核心状态变量
var _mouse_pressed: bool = false
var _mouse_moved: bool = false
var _mouse_moved_and_up: bool = false
var _mouse_displacement: Vector2 = Vector2(0, 0)
var _old_scroll: Vector2 = Vector2(0, 0)
var _active_scroll: ScrollContainer = null

func _ready():
    # 1. 监听新节点
    get_tree().connect("node_added", self, "_on_node_added")
    
    # 2. 延迟一帧，把游戏一开始就有的主界面列表、设置全扫一遍
    call_deferred("_scan_existing_ui")

func _scan_existing_ui():
    var all_controls = get_tree().root.find_children("*", "Control", true, false)
    for c in all_controls:
        _process_node(c)

func _on_node_added(node: Node):
    if node is Control:
        _process_node(node)

# ============ 核心节点处理逻辑 ============
func _process_node(node: Node):
    if _processed.has(node): return
    _processed[node] = true
    
    # 1. 给所有控件挂载防误触监听 (Touch Slide 逻辑)
    if not node.is_connected("gui_input", self, "_on_gui_input"):
        node.connect("gui_input", self, "_on_gui_input", [node])
        
    # 2. 干掉开关的黑长条 (ModOptions 修复补丁逻辑)
    if node is CheckButton:
        _fix_check_button_style(node)
        
    # 3. 宝箱限高 (咱们自己的逻辑)
    if node.name == "ItemDescription":
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            if "Shop" not in str(node.get_path()):
                _wrap_and_lock_crate(node)

# ============ 模块 A：去黑框 ============
func _fix_check_button_style(btn: CheckButton):
    var empty_style = StyleBoxEmpty.new()
    btn.add_stylebox_override("normal", empty_style)
    btn.add_stylebox_override("pressed", empty_style)
    btn.add_stylebox_override("focus", empty_style)
    btn.add_stylebox_override("disabled", empty_style)

# ============ 模块 B：宝箱限高 ============
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

# ============ 模块 C：全局滑动与防误触 (Touch Slide 逻辑) ============
func _input(event):
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if event.pressed:
                _mouse_moved_and_up = false
                _active_scroll = _get_scroll_container(event.position)
            else:
                if _mouse_moved:
                    _mouse_moved_and_up = true
                _active_scroll = null
                _mouse_moved = false
                _mouse_pressed = false

    if event is InputEventMouseMotion:
        if _mouse_pressed and _active_scroll != null:
            _mouse_displacement += event.relative
            if _mouse_moved:
                # 强制驱动滚动条
                var vbar = _active_scroll.get_v_scrollbar()
                if vbar:
                    vbar.value = _old_scroll.y - _mouse_displacement.y
            else:
                # 阈值判断：滑动超过 10 像素才算真正的滑动
                if _mouse_displacement.length() > 10:
                    _mouse_moved = true
                    _mouse_displacement = Vector2(0, 0)
                    var hbar = _active_scroll.get_h_scrollbar()
                    var vbar = _active_scroll.get_v_scrollbar()
                    _old_scroll = Vector2(hbar.value if hbar else 0, vbar.value if vbar else 0)

func _on_gui_input(event: InputEvent, node: Control):
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if event.pressed:
                # 只要按在滚动区域内，且不是滑块/颜色选择器，就激活状态
                if not _mouse_pressed and not _is_ignore_control(node):
                    if _get_scroll_container(event.position) != null:
                        _mouse_pressed = true
            else:
                # 💥 核心防误触：如果刚才滑动了，吃掉这个抬起事件，不让按钮点击生效！
                if _mouse_moved_and_up:
                    node.accept_event()
                    _mouse_moved_and_up = false

# ============ 辅助函数 ============
func _get_scroll_container(pos: Vector2) -> ScrollContainer:
    var scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
    # 倒序找最顶层的
    for i in range(scrolls.size() - 1, -1, -1):
        var s = scrolls[i]
        if s.is_visible_in_tree() and s.get_global_rect().has_point(pos):
            return s
    return null

func _is_ignore_control(node: Control) -> bool:
    return (node is Slider) or (node is ScrollBar) or (node is ColorPicker)
