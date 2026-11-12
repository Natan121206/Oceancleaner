extends AudioStreamPlayer
## Música de fundo (autoload). O MP3 importado não repete por padrão,
## então a música tocava uma vez e parava. Aqui garantimos o loop.


func _ready() -> void:
	_ativar_loop()
	# Plano B: se o loop do arquivo falhar, recomeça quando terminar
	finished.connect(play)


# Recomeça a música do começo (usado ao iniciar ou reiniciar a partida).
# Só despausar faria ela continuar de onde parou.
func reiniciar() -> void:
	stream_paused = false
	stop()
	play(0.0)


func _ativar_loop() -> void:
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
