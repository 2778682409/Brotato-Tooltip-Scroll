extends Node

var _processed = {}

# 触摸滑动判定变量
var _touch_start_pos = Vector2.ZERO
var _is_dragging = false
var _active_scroll = null
const DRAG_THRESHOLD = 15.0 # 滑动阈值：超过 15 像素才算滑动，防止误触开关

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 只处理宝箱界面的限高套壳，彻底无视其他所有 UI！
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        
        if is_instance_valid(node):
            # 只要不是商店，就套壳
            if "Shop" not in str(node.get_path()):
                _wrap_and_lock_crate(node)

# ============ 宝箱限高（保持之前的完美状态） ============
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

# ============ 透明守门员：全局滑动接管 ============
func _input(event: InputEvent):
    # 1. 手指按下时，记录初始位置，并寻找按下的位置有没有滚动条
    if event is InputEventScreenTouch and event.pressed:
        _touch_start_pos = event.position
        _is_dragging = false
        _active_scroll = _find_scroll_at_pos(event.position)
        
    # 2. 手指移动时
    elif event is InputEventScreenDrag:
        # 如果还没判定为滑动，先算算距离
        if not _is_dragging:
            if event.position.distance_to(_touch_start_pos) > DRAG_THRESHOLD:
                _is_dragging = true
        
        # 如果判定为滑动，且有激活的滚动条，立刻接管！
        if _is_dragging and is_instance_valid(_active_scroll):
            # 灵敏度微调：乘以 1.5 倍手感更好
            _active_scroll.scroll_vertical -= event.relative.y * 1.5
            # 💥 核心：吃掉事件！告诉游戏“这是一个滑动，千万别触发底下的按钮”
            get_tree().set_input_as_handled()
            
    # 3. 手指松开，重置状态
    elif event is InputEventScreenTouch and not event.pressed:
        _is_dragging = false
        _active_scroll = null

# ============ 辅助：找出触摸点底下的 ScrollContainer ============
func _find_scroll_at_pos(pos: Vector2) -> ScrollContainer:
    var scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
    # 倒序遍历，优先找最顶层的
    for i in range(scrolls.size() - 1, -1, -1):
        var s = scrolls[i]
        if is_instance_valid(s) and s.is_visible_in_tree():
            if s.get_global_rect().has_point(pos):
                return s
    return null
