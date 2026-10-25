extends Node

var _processed = {}

# Touch slide 核心变量
var _mouse_pressed: bool = false
var _mouse_moved: bool = false
var _mouse_moved_and_up: bool = false
var _mouse_displacement: Vector2 = Vector2(0, 0)
var _old_scroll: Vector2 = Vector2(0, 0)
var _active_scroll: ScrollContainer = null

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")
    # 启动时主动扫描一遍已有的 UI（解决主界面 Mod 列表滑不动）
    call_deferred("_scan_existing_ui")

func _scan_existing_ui():
    var all_scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
    for s in all_scrolls:
        if not _processed.has(s):
            _processed[s] = true
            _setup_scroll_node(s)

func _on_node_added(node: Node):
    # 1. 处理宝箱和商店的物品弹窗
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            if "Shop" not in str(node.get_path()):
                _wrap_and_lock_crate(node)
            else:
                var scrolls = _find_all_scrolls(node)
                for s in scrolls:
                    _setup_scroll_node(s)
        return
        
    # 2. 处理设置界面等其他滚动条
    if node is ScrollContainer:
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            _setup_scroll_node(node)

# ============ 宝箱限高 ============
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
        
    _setup_scroll_node(scroll)

# ============ 核心：赋予滚动条能力 + 去黑框 ============
func _setup_scroll_node(scroll: ScrollContainer):
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    _set_mouse_ignore_for_containers(scroll)
    
    var buttons = _find_buttons(scroll)
    for btn in buttons:
        if btn is CheckButton:
            var empty_style = StyleBoxEmpty.new()
            btn.add_stylebox_override("normal", empty_style)
            btn.add_stylebox_override("pressed", empty_style)
            btn.add_stylebox_override("focus", empty_style)
            btn.add_stylebox_override("disabled", empty_style)
            btn.mouse_filter = Control.MOUSE_FILTER_PASS
        
        if not btn.is_connected("gui_input", self, "_on_button_gui_input"):
            btn.connect("gui_input", self, "_on_button_gui_input", [scroll])

func _set_mouse_ignore_for_containers(node: Node):
    for child in node.get_children():
        if child is Control:
            if child is Button or child is ScrollBar:
                pass 
            else:
                child.mouse_filter = Control.MOUSE_FILTER_IGNORE
                _set_mouse_ignore_for_containers(child)
        else:
            _set_mouse_ignore_for_containers(child)

func _find_buttons(root: Node) -> Array:
    var result = []
    if root is Button:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_buttons(child))
    return result

func _find_all_scrolls(root: Node) -> Array:
    var result = []
    if root is ScrollContainer:
        result.append(root)
    for child in root.get_children():
        result.append_array(_find_all_scrolls(child))
    return result

# ============ 抄 Touch slide：全局滑动与防误触 ============
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
                var vbar = _active_scroll.get_v_scrollbar()
                if vbar:
                    vbar.value = _old_scroll.y - _mouse_displacement.y
            else:
                if _mouse_displacement.length() > 10:
                    _mouse_moved = true
                    _mouse_displacement = Vector2(0, 0)
                    var hbar = _active_scroll.get_h_scrollbar()
                    var vbar = _active_scroll.get_v_scrollbar()
                    _old_scroll = Vector2(hbar.value if hbar else 0, vbar.value if vbar else 0)

# 按钮的触摸事件（用于防误触）
func _on_button_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if event.pressed:
                if not _mouse_pressed:
                    _mouse_pressed = true
            else:
                if _mouse_moved_and_up:
                    event.accept_event()
                    _mouse_moved_and_up = false

# 辅助函数
func _get_scroll_container(pos: Vector2) -> ScrollContainer:
    var scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
    for i in range(scrolls.size() - 1, -1, -1):
        var s = scrolls[i]
        if s.is_visible_in_tree() and s.get_global_rect().has_point(pos):
            return s
    return null
