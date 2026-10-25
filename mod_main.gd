extends Node

var _processed = {}
var _status_label: Label

func _ready():
    # 右上角指示灯
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    _status_label = Label.new()
    _status_label.text = "✅ 模组运行中 (直接限高)"
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
    if node.name != "ItemDescription":
        return
        
    # 只要场景里有 WeaponSelection 根节点，就说明是宝箱
    if get_node_or_null("/root/WeaponSelection") == null:
        return
        
    if _processed.has(node):
        return
        
    _processed[node] = true
    
    # 等两帧，等 UI 彻底排版完毕，再砍它！
    yield(get_tree(), "idle_frame")
    yield(get_tree(), "idle_frame")
    
    if is_instance_valid(node):
        _force_limit_height(node)

func _force_limit_height(item_node: Control):
    # 强制把高度砍到 320（你可以自己改这个数值）
    var limit_h = 320.0 
    
    item_node.rect_min_size.y = limit_h
    item_node.rect_size.y = limit_h
    
    # 关键防御：禁止这个框被父节点自动拉伸
    item_node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    
    if is_instance_valid(_status_label):
        _status_label.text = "✅ 已直接切断宝箱框高度!"
