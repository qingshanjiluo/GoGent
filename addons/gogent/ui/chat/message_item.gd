@tool
class_name GoGentMessageItem
extends MarginContainer

## 消息项组件
## 显示用户或 AI 的消息

@onready var user_container: PanelContainer = %UserContainer
@onready var user_content: RichTextLabel = %UserContent
@onready var assistant_container: VBoxContainer = %AssistantContainer
@onready var assistant_content: RichTextLabel = %AssistantContent
@onready var thinking_container: VBoxContainer = %ThinkingContainer
@onready var thinking_content: RichTextLabel = %ThinkingContent

enum MessageType {
	USER,
	ASSISTANT,
	SYSTEM
}

var message_type: MessageType = MessageType.USER

func _ready() -> void:
	hide_all()

func hide_all() -> void:
	user_container.hide()
	assistant_container.hide()
	thinking_container.hide()

func set_user_message(text: String) -> void:
	message_type = MessageType.USER
	hide_all()
	user_container.show()
	user_content.text = text

func set_assistant_message(text: String, thinking: String = "") -> void:
	message_type = MessageType.ASSISTANT
	hide_all()
	assistant_container.show()
	assistant_content.text = text
	
	if not thinking.is_empty():
		thinking_container.show()
		thinking_content.text = thinking

func set_system_message(text: String) -> void:
	message_type = MessageType.SYSTEM
	hide_all()
	assistant_container.show()
	assistant_content.text = "[color='#ffeda1']{0}[/color]".format([text])
