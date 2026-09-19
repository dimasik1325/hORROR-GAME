@tool
class_name ItemData
extends Resource

## Ресурс данных предмета для игры "Эхо Чащи" (Godot 4.6-dev)
## Определяет физические, визуальные и логические свойства инвентарного объекта.

enum ItemType {
	CONSUMABLE,
	BATTERY,
	NOTE,
	KEY,
	TOOL,
	SANITY_DRAIN
}

@export_group("Идентификация")
## Уникальный строковый ID предмета (например, "battery_lithium_9v", "cabin_key_rusty")
@export var id: StringName = &"item_default"
## Отображаемое имя в интерфейсе
@export var display_name: String = "Неизвестный предмет"
## Подробное описание при осмотре
@export_multiline var description: String = "Старый предмет, найденный в чаще леса."
## Иконка для инвентаря и подсказок UI
@export var icon: Texture2D

@export_group("Параметры Предмета")
## Категория предмета
@export var item_type: ItemType = ItemType.CONSUMABLE
## Предел стекирования в ячейке инвентаря
@export_range(1, 99, 1) var stack_limit: int = 1
## Вес предмета в кг (влияет на инерцию и расход стамины)
@export_range(0.0, 20.0, 0.05) var weight: float = 0.25
## Расходуется ли предмет при использовании
@export var is_consumed_on_use: bool = true
## Является ли предмет ключевым для сюжета (нельзя выбросить)
@export var is_quest_item: bool = false

@export_group("3D Репрезентация")
## 3D-меш для отображения лежащего предмета в мире
@export var world_mesh: Mesh
## 3D-сцена для детального интерактивного осмотра в руках
@export var inspection_scene: PackedScene

@export_group("Аудио Данные")
## Звук подбора предмета
@export var pickup_sound: AudioStream
## Звук применения предмета
@export var use_sound: AudioStream
## Звук падения/выбрасывания предмета
@export var drop_sound: AudioStream

@export_group("Специфические Данные Батареи")
## Количество восполняемого заряда фонарика (в процентах от 0.0 до 100.0)
@export_range(0.0, 100.0, 1.0) var battery_charge_amount: float = 45.0

@export_group("Специфические Данные Записки")
## Текст записки/документа с поддержкой BBCode
@export_multiline var note_text: String = ""
## Автор записки (для сюжетных триггеров идентификации почерка Уэйна)
@export var note_author: String = "Неизвестный"
## Номер акта расследования, к которому относится документ
@export_range(1, 3, 1) var story_act: int = 1

@export_group("Специфические Данные Рассудка")
## Величина восстановления (положительное) или падения (отрицательное) рассудка
@export_range(-100.0, 100.0, 0.5) var sanity_impact: float = 15.0


## Метод валидации ресурса в редакторе Godot
func _validate_property(property: Dictionary) -> void:
	if property.name == "battery_charge_amount" and item_type != ItemType.BATTERY:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if (property.name == "note_text" or property.name == "note_author" or property.name == "story_act") and item_type != ItemType.NOTE:
		property.usage = PROPERTY_USAGE_NO_EDITOR


## Базовый метод использования предмета
func use(user_node: Node) -> bool:
	match item_type:
		ItemType.BATTERY:
			if user_node.has_method("restore_flashlight_battery"):
				var success: bool = user_node.call("restore_flashlight_battery", battery_charge_amount)
				return success
			return false

		ItemType.CONSUMABLE:
			if sanity_impact != 0.0 and user_node.has_node("/root/SanityGlobalManager"):
				var sanity_mgr = user_node.get_node("/root/SanityGlobalManager")
				sanity_mgr.modify_sanity(sanity_impact)
				return true
			return false

		ItemType.NOTE:
			# Записки открываются в UI ридере и не расходуются
			return true

		_:
			return false
