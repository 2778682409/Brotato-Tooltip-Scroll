extends Node

func _ready():
    # 这个是最基础的节点，只要脚本跑了，它绝对会出现
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    
    var label = Label.new()
    label.text = "✅ 基础测试通过"
    label.add_color_override("font_color", Color(0, 1, 0))
    label.rect_position = Vector2(50, 50)
    canvas.add_child(label)
    
    # 顺便在后台打印一句
    print("✅ 脚本成功运行！")
