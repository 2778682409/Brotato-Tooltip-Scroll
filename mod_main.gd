extends Node

var _processed = {}

# 用于判断滑动的状态
var _touch_start_pos = Vector2.ZERO
var _is_dragging = false
const DRAG_THRESHOLD = 10.0 # 滑动阈值：手指移动超过 10 像素才算滑动，防止误触按钮

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 1. 处理宝箱套壳
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        
        if is_instance_valid(node):
            if "Shop" not in str(node.get_path()):
                _wrap_and_lock_crate(node)
        return
        
    # 2. 修复被异常拉伸的 UI 白条
    yield(get_tree(), "idle_frame")
    if is_instance_valid(node) and node is Control:
        _fix_ui_glitches(node)

# ============ 宝箱限高 ============
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

# ============ UI 修复术：把奇怪的大白条缩回去 ============
func _fix_ui_glitches(node: Node):
    for child in node.get_children():
        # 如果发现开关（CheckButton）或者普通按钮被异常拉得巨长（大于 150）
        if child is CheckButton or child is Button:
            if child.rect_size.x > 150:
                # 强制让它靠右对齐，并且固定大小，不再被父容器拉伸
                child.size_flags_horizontal = Control.SIZE_SHRINK_END
                if child.rect_min_size.x < 50:
                    child.rect_min_size = Vector2(50, 40)
        _fix_ui_glitches(child)

# ============ 终极全局滑动（不卡顿，绝不误触） ============
func _input(event: InputEvent):
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_start_pos = event.position
            _is_dragging = false
            
    elif event is InputEventScreenDrag:
        # 如果还没有判定为滑动，先计算移动距离
        if not _is_dragging:
            if event.position.distance_to(_touch_start_pos) > DRAG_THRESHOLD:
                _is_dragging = true
                
        # 一旦确认是滑动，就直接接管！
        if _is_dragging:
            # 找到手指正下方的滚动框
            var mouse_pos = get_viewport().get_mouse_position()
            var scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
            
            for scroll in scrolls:
                if is_instance_valid(scroll) and scroll.is_visible_in_tree() and scroll.get_global_rect().has_point(mouse_pos):
                    # 直接滚动，用乘法提高灵敏度
                    scroll.scroll_vertical -= event.relative.y * 2.5
                    # 吃掉事件，防止底层按钮被触发
                    get_tree().set_input_as_handled()
                    break
