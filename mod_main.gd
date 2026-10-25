extends Node

var _processed = {}

func _ready():
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    if node.name != "ItemDescription":
        return
        
    var path = str(node.get_path())
    
    # 🚫 唯一防线：只要路径里有 Shop，绝对不碰！
    if "Shop" in path:
        return
        
    if _processed.has(node):
        return
        
    _processed[node] = true
    
    # 等两帧，让游戏算好基础尺寸
    yield(get_tree(), "idle_frame")
    yield(get_tree(), "idle_frame")
    
    if is_instance_valid(node):
        _wrap_and_lock(node)

func _wrap_and_lock(popup_root: Control):
    var parent = popup_root.get_parent()
    if not parent or parent is ScrollContainer:
        return

    var index = popup_root.get_index()
    
    # 记录它原本的大致位置和宽度
    var orig_pos = popup_root.rect_position
    var orig_width = popup_root.rect_size.x
    
    # 拔出来
    parent.remove_child(popup_root)

    # 造一个无敌外壳
    var scroll = ScrollContainer.new()
    scroll.name = "ModTooltipScroll"
    
    # 💥 核心绝招：高度直接锁死在 400（差不多占屏幕一半），绝不妥协！
    var fixed_height = 400.0
    
    scroll.rect_position = orig_pos
    scroll.rect_min_size = Vector2(orig_width, fixed_height)
    scroll.rect_size = Vector2(orig_width, fixed_height)
    
    scroll.scroll_horizontal_enabled = false
    scroll.scroll_vertical_enabled = true
    # 允许手指拖动
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    # 物理裁剪，超出部分直接切掉，强迫滚动
    scroll.clip_contents = true

    # 把壳放回原位
    parent.add_child(scroll)
    parent.move_child(scroll, index)
    
    # 把原框塞进壳里
    scroll.add_child(popup_root)
    
    # 告诉原框：你在壳里乖乖待着，不要试图撑大外壳！
    if popup_root is Control:
        popup_root.rect_position = Vector2(0, 0)
        popup_root.rect_min_size.x = orig_width
        popup_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
