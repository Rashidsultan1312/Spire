extends CanvasLayer

signal closed

@onready var panel: PanelContainer = $Panel
@onready var bg: ColorRect = $BG
@onready var back_btn: Button = $Panel/VBox/BackBtn
@onready var wallet_label: Label = $Panel/VBox/WalletRow/WalletValue
@onready var hint_btn: Button = $Panel/VBox/Items/HintCard/HBox/Right/HintBtn
@onready var shield_btn: Button = $Panel/VBox/Items/ShieldCard/HBox/Right/ShieldBtn
@onready var luck_btn: Button = $Panel/VBox/Items/LuckCard/HBox/Right/LuckBtn
@onready var hint_count: Label = $Panel/VBox/Items/HintCard/HBox/Right/Count
@onready var shield_count: Label = $Panel/VBox/Items/ShieldCard/HBox/Right/Count
@onready var luck_count: Label = $Panel/VBox/Items/LuckCard/HBox/Right/Count

@onready var hint_card: PanelContainer = $Panel/VBox/Items/HintCard
@onready var shield_card: PanelContainer = $Panel/VBox/Items/ShieldCard
@onready var luck_card: PanelContainer = $Panel/VBox/Items/LuckCard

func _ready():
	back_btn.pressed.connect(_close)
	hint_btn.pressed.connect(func(): _buy("hint"))
	shield_btn.pressed.connect(func(): _buy("shield"))
	luck_btn.pressed.connect(func(): _buy("luck"))
	hint_card.gui_input.connect(func(e: InputEvent): _card_input(e, "hint"))
	shield_card.gui_input.connect(func(e: InputEvent): _card_input(e, "shield"))
	luck_card.gui_input.connect(func(e: InputEvent): _card_input(e, "luck"))
	visible = false

func _card_input(event: InputEvent, item_id: String):
	if event is InputEventMouseButton and event.pressed:
		_buy(item_id)

func open():
	visible = true
	_update_ui()
	panel.scale = Vector2(0.85, 0.85)
	panel.modulate = Color(1, 1, 1, 0)
	panel.pivot_offset = panel.size / 2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "scale", Vector2(1, 1), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(bg, "color:a", 0.5, 0.2)

func _close():
	SoundManager.play("click")
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.15)
	tw.tween_property(bg, "color:a", 0.0, 0.15)
	tw.tween_callback(func(): visible = false; closed.emit())

func _buy(item_id: String):
	if GameManager.buy_item(item_id):
		SoundManager.play("purchase")
		_update_ui()
	else:
		SoundManager.play("error")

func _update_ui():
	wallet_label.text = "%d" % GameManager.wallet
	hint_count.text = "x%d" % GameManager.items["hint"]
	shield_count.text = "x%d" % GameManager.items["shield"]
	luck_count.text = "x%d" % GameManager.items["luck"]
	hint_btn.disabled = GameManager.wallet < GameManager.ITEM_PRICES["hint"]
	shield_btn.disabled = GameManager.wallet < GameManager.ITEM_PRICES["shield"]
	luck_btn.disabled = GameManager.wallet < GameManager.ITEM_PRICES["luck"]
