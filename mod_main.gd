extends Node

var _processed = {}
var _status_label: Label

func _ready():
    # 1. 设置右上角状态指示灯
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    
    _status_label = Label.new()
    _status_label.text = "✅ 模组已运行 (监听模式)"
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

    # 2. 连接核心信号：只要场景树有新节点诞生，就通知我们
    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 引擎每秒会生成无数节点（子弹、怪物等），咱们用最快的速度过滤
    if node.name != "ItemDescription":
        return
        
    var path = str(node.get_path())
    
    # 精准判定：必须是宝箱/选武器界面 (WeaponSelection)
    if "WeaponSelection" not in path:
        return
        
    if _processed.has(node):
        return
        
    _processed[node] = true
    
    # 刚刚出生的节点，UI 还没排版好，等一帧再动手
    yield(get_tree(), "idle_frame")
    
    if is_instance_valid(node):
        _fix_the_box(node)

func _fix_the_box(item_node: Node):
    # 在刚诞生的 ItemDescription 里找自带的滚动条
    var scroll = item_node.find_node("ScrollContainer", true, false)
    
    if scroll:
        # 直接写死尺寸，完全照抄商店的 321 x 265
        scroll.rect_min_size = Vector2(321, 265)
        scroll.rect_size = Vector2(321, 265)
        
        # 关键：把垂直扩展关掉，防止被外面的父节点撑大
        scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
        scroll.scroll_vertical_enabled = true
        
        if is_instance_valid(_status_label):
            _status_label.text = "✅ 已锁定宝箱物品框尺寸!"
