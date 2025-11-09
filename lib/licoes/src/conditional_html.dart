// lib/licoes/src/conditional_html.dart
// Stub seguro do AudioElement para plataformas sem suporte a dart:html (Android, iOS, macOS)

class AudioElement {
  // Construtor opcional — aceita ou não um src (para compatibilidade com o código Web)
  AudioElement([String? src]);

  // Atributos simulados
  bool autoplay = false;
  bool controls = false;
  double playbackRate = 1.0;

  // Métodos simulados
  void play() {}
  void pause() {}
  void load() {}

  // Propriedades simuladas (só para evitar erro de compilação)
  String? src;
  String? preload;
  double currentTime = 0.0;

  // Streams simuladas
  Stream<void> get onEnded => const Stream.empty();
  Stream<void> get onError => const Stream.empty();
}
