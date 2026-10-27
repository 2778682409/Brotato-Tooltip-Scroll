extends Node

var _processed = {}
var _is_sliding := false

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")
    call_deferred("_scan_existing_ui")

func _scan_existing_ui():
    var all_scrolls = get_tree().root.find_children("*", "ScrollContainer", true, false)
    for s in all_scrolls:
        if not _processed.has(s):
            _processed[s] = true
            _setup_touch_scroll(s)

func _on_node_added(node: Node):
    # 1. 处理宝箱和商店的物品弹窗
    if node.name == "ItemDescription":
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            var path = str(node.get_path())
            if "Shop" in path:
                var scrolls = _find_all_scrolls(node)
                for s in scrolls:
                    _setup_touch_scroll(s)
            else:
                _wrap_and_lock_crate(node)
        return
        
    # 2. 处理设置界面等其他滚动条
    if node is ScrollContainer:
        if _processed.has(node): return
        _processed[node] = true
        yield(get_tree(), "idle_frame")
        if is_instance_valid(node):
            _setup_touch_scroll(node)
            
    # 3. 💥 处理升级界面的卡片
    if node is PanelContainer and "UpgradeUI" in node.name:
        if _processed.has(node): return
        _processed[node] = true
        
        # 监听尺寸变化，当游戏刷新文字导致卡片尺寸改变时，立刻重新强制限高
        if not node.is_connected("resized", self, "_on_upgrade_card_resized"):
            node.connect("resized", self, "_on_upgrade_card_resized", [node])
            
        # 延迟一帧处理，等内部数据排版完毕
        call_deferred("_fix_upgrade_card", node)

func _on_upgrade_card_resized(card: Control):
    # 防止设置 rect_min_size 导致无限递归触发 resized
    if card.get_meta("is_fixing", false): return
    card.set_meta("is_fixing", true)
    _fix_upgrade_card(card)
    card.set_meta("is_fixing", false)

func _fix_upgrade_card(card: Control):
    if not is_instance_valid(card): return
    
    # 💥 强行锁定卡片本身的高度（可根据你的屏幕比例微调 220.0 ~ 250.0）
    var card_height = 230.0
    card.rect_min_size.y = card_height
    
    # 找到卡片里的原生滚动框
    var scroll = card.find_node("ScrollContainer", true, false)
    if scroll:
        scroll.scroll_vertical_enabled = true
        scroll.scroll_horizontal_enabled = false
        
        # 💥 核心：让它填满卡片剩余空间，不要往外撑破卡片，超出部分裁剪
        scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL 
        scroll.clip_contents = true
        
        # 注入触摸滑动
        _setup_touch_scroll(scroll)
    else:
        # 如果原版卡片内部没有 ScrollContainer，直接开启卡片裁剪，防止文字溢出
        card.clip_contents = true

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
        
    _setup_touch_scroll(scroll)

# ============ 核心：赋予滚动条能力 + 暗中劫持按钮 ============
func _setup_touch_scroll(scroll: ScrollContainer):
    scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    
    # 1. 文字容器透明化
    _set_mouse_ignore_for_containers(scroll)
    
    # 2. 找出所有按钮（开关等）
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
        
    if not scroll.is_connected("gui_input", self, "_on_scroll_gui_input"):
        scroll.connect("gui_input", self, "_on_scroll_gui_input", [scroll])

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

# 监听滚动框本体滑动
func _on_scroll_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT):
        _is_sliding = true
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()

# 在开关上滑动 + 拦截抬起
func _on_button_gui_input(event: InputEvent, scroll: ScrollContainer):
    if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT):
        _is_sliding = true
        scroll.scroll_vertical -= event.relative.y
        scroll.accept_event()
        
    elif event is InputEventScreenTouch or (event is InputEventMouseButton and not event.pressed):
        if _is_sliding:
            scroll.accept_event()
            _is_sliding = false
