extends Control

func _ready() -> void:
	call_deferred("_on_boot_ready")

func _on_boot_ready() -> void:
	AppRouter.boot()
