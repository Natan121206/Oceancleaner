extends Area2D
## Respingo de suco disparado pela caixinha. Voa em linha reta e fere o tubarão.

var velocity: Vector2 = Vector2.ZERO
var damage: int = 8
var lifetime: float = 3.0

# A arte do respingo aponta para cima-direita (~35 graus).
# Se ele sair "de lado" no jogo, ajuste este valor.
const ROTACAO_OFFSET_GRAUS: float = 35.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	rotation = velocity.angle() + deg_to_rad(ROTACAO_OFFSET_GRAUS)


func _physics_process(delta: float) -> void:
	position += velocity * delta

	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if body.has_method("take_damage"):
		body.take_damage(damage)

	set_physics_process(false)
	set_deferred("monitoring", false)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", scale * 1.4, 0.12)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.set_parallel(false)
	tw.tween_callback(queue_free)
