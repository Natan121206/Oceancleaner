extends Control

const CENA_JOGO := "res://scenes/maps/testmapa.tscn"
const CENA_MENU := "res://scenes/ui/start_screen.tscn"


func _ready() -> void:
	%RetryButton.pressed.connect(_on_retry_pressed)
	%MenuButton.pressed.connect(_on_menu_pressed)
	%RetryButton.grab_focus()
	
	MusicaFundo.stream_paused = true

	# Recupera os resultados da partida anterior.
	_update_match_results()


func _update_match_results() -> void:
	var total_kills: int = get_tree().get_meta("inimigos_derrotados", 0)
	var survival_time: float = get_tree().get_meta("tempo_sobrevivido", 0.0)

	# Mostra a quantidade de inimigos derrotados com texto explicativo.
	%NumeroKills.text = "Inimigos derrotados: %d" % total_kills

	# Converte o tempo sobrevivido para minutos e segundos.
	var total_seconds: int = int(survival_time)
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60

	# Mostra o tempo sobrevivido com texto explicativo.
	%TempoFinal.text = "Tempo sobrevivido: %02d:%02d" % [minutes, seconds]


func _on_retry_pressed() -> void:
	# Remove os resultados da partida anterior.
	get_tree().remove_meta("inimigos_derrotados")
	get_tree().remove_meta("tempo_sobrevivido")
	
	MusicaFundo.stream_paused = false

	get_tree().change_scene_to_file(CENA_JOGO)


func _on_menu_pressed() -> void:
	# Remove os resultados da partida anterior.
	get_tree().remove_meta("inimigos_derrotados")
	get_tree().remove_meta("tempo_sobrevivido")

	get_tree().change_scene_to_file(CENA_MENU)
