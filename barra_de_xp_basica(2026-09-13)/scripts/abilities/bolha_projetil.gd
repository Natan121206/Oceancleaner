extends Area2D
## Projétil de água disparado pela habilidade "Jato de Bolhas".
## Viaja em linha reta e explode ao acertar um inimigo.

var velocity: Vector2 = Vector2.ZERO
var damage: int = 10
var lifetime: float = 2.5


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(_expire)


func _physics_process(delta: float) -> void:
	position += velocity * delta


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("enemies"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_pop()


func _expire() -> void:
	if is_instance_valid(self):
		queue_free()


func _pop() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", scale * 1.5, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
