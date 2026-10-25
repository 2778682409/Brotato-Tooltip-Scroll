extends Node

var _processed = {}
var _status_label: Label

func _ready():
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    
    _status_label = Label.new()
    _status_label.text = "模组运行中 (精准套壳)"
    _status_label.add_color_override("font_color", Color(0, 1, 0))
    _status_label.add_color_override("font_outline_color", Color(0, 0, 0))
    _status_label.add_constant_override("outline_size", 4)
    _status_label.anchor_left = 1.0
    _status_label.anchor_right = 1.0
    _status_label.margin_left = -300
    _status_label.margin_right = -20
    _status_label.margin_top = 20
    _status_label.align = Label.ALIGN_RIGHT
    canvas.add_child(_status_label)

    # 监听新节点诞生
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 名字不对直接滚
    if node.name != "ItemDescription":
        return
        
    var path = str(node.get_path())
    
    # 绝对不碰商店！只要不是 WeaponSelection，直接放行！
    if "WeaponSelection" not in path:
        return
        
    if _processed.has(node):
        return
        
    _processed[node] = true
    
    # 等两帧，让引擎算好它的初始大小和位置
    yield(get_tree(), "idle_frame")
    yield(get_tree(), "idle_frame")
    
    if is_instance_valid(node):
        _wrap_it_safely(node)

func _wrap_it_safely(item_node: Node):
    var parent = item_node.get_parent()
    if not parent or parent is ScrollContainer:
        return
        
    # 记录它此时此刻的真实位置和大小
    var index = item_node.get_index()
    var orig_size = item_node.rect_size
    var orig_pos = item_node.rect_position
    
    # 拔出来
    parent.remove_child(item_node)
    
    # 造一个新外壳
    var scroll = ScrollContainer.new()
    scroll.name = "ModTooltipScroll"
    
    # 继承原来的一切
    scroll.rect_size = orig_size
    scroll.rect_position = orig_pos
    scroll.scroll_horizontal_enabled = false
    scroll.scroll_vertical_enabled = true
    scroll.mouse_filter = Control.MOUSE_FILTER_PASS
    
    # 关键限制：高度如果超过屏幕的一半，就强制砍断
    var max_h = get_viewport().size.y * 0.5
    if scroll.rect_size.y > max_h:
        scroll.rect_size.y = max_h
        scroll.rect_min_size.y = max_h
    
    # 把新外壳塞回原位
    parent.add_child(scroll)
    parent.move_child(scroll, index)
    
    # 把原框塞进新外壳里
    scroll.add_child(item_node)
    
    # 修正原框在壳里的位置，让它铺满
    if item_node is Control:
        item_node.rect_position = Vector2(0, 0)
        item_node.rect_min_size.x = scroll.rect_size.x
        
    if is_instance_valid(_status_label):
        _status_label.text = "成功包裹宝箱框"
