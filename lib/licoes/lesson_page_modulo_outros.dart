//
// ARQUIVO COMPLETO E CORRIGIDO: LessonPageModuloOutros.dart
// (100% Focado no iOS - sem Web)
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:developer' as developer;

// Imports de Web REMOVIDOS
// import 'src/conditional_html.dart' if (dart.library.html) 'dart:html' as html;
// import 'package:flutter/foundation.dart' show kIsWeb;

class LessonPageModuloOutros extends StatefulWidget {
  final String title;
  final String jsonPath;
  final List<int>? range;

  const LessonPageModuloOutros({
    super.key,
    required this.title,
    required this.jsonPath,
    this.range,
  });

  @override
  LessonPageModuloOutrosState createState() => LessonPageModuloOutrosState();
}

class LessonPageModuloOutrosState extends State<LessonPageModuloOutros> {
  // Dados e estado
  List<dynamic> _itensDaLicao = [];
  bool _carregando = true;
  late String _progressoKey;
  Set<String> _botoesConcluidos = {};
  int _totalBotoesNaLicao = 0;

  // Exibição local
  final Map<String, bool> _estadoExibicaoLocal = {};

  // Player e cache
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Map<String, String> _audioUrlCache = {};
  final Map<String, Future<String?>> _pendingAudioFetches = {};

  // Controles do topo
  bool _mostrarInglesGlobal = false;
  int _repeticoesGlobais = 1;
  double _velocidade = 1.0; // 1.0x / 1.25x / 1.5x

  // Sequenciador
  bool _isPlayingAll = false; // mutex
  bool _stopRequested = false; // cancelamento
  int _currentIndex = 0; // índice (PERSISTS p/ retomar)

  // Scroll
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {}; // phrase_id -> key

  String get _labelIdiomaTopo => _mostrarInglesGlobal ? 'Português' : 'Inglês';
  bool get _todosEstaoMarcados =>
      _totalBotoesNaLicao > 0 &&
          _botoesConcluidos.length >= _totalBotoesNaLicao;

// ✅ CÓDIGO NOVO CORRIGIDO
  @override
  void initState() {
    super.initState();
    _progressoKey =
    'progresso_licao_outros_${widget.jsonPath.replaceAll('/', '').replaceAll(
        '.', '')}';
    _audioPlayer.setReleaseMode(ReleaseMode.stop);

    // ✅ CORREÇÃO: Listener para liberar o "lock" do PlayAll (sem .error)
    _audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if ((s == PlayerState.completed || s == PlayerState.stopped) &&
          _isPlayingAll) {
        // Isso é para o _playAndWait, não precisa de setState
      }
      else if (s == PlayerState.completed || s == PlayerState.stopped) {
        if (mounted) setState(() => _isPlayingAll = false);
      }
    });

    _carregarDados();
  }

  @override
  void dispose() {
    _stopRequested = true;
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // =========================
  // Carregamento e progresso
  // =========================

  Future<void> _carregarDados() async {
    try {
      await _carregarLicao(range: widget.range);
    } catch (e) {
      developer.log("❌ ERRO AO CARREGAR O JSON (${widget.jsonPath}): $e",
          name: 'LessonLoadError');
    }
    try {
      await _carregarProgresso();
    } catch (e) {
      developer.log("❌ ERRO AO CARREGAR O PROGRESSO: $e",
          name: 'ProgressLoadError');
    }
    if (mounted) {
      setState(() => _carregando = false);
    }
  }

  Future<void> _carregarLicao({List<int>? range}) async {
    final String jsonString = await rootBundle.loadString(widget.jsonPath);
    final List<dynamic> jsonResponse = json.decode(jsonString);

    List<dynamic> itensFiltrados = jsonResponse;

    if (range != null && range.length == 2) {
      int start = range[0] - 1; // 0-based
      int end = range[1]; // exclusivo
      if (start < 0) start = 0;
      if (end > jsonResponse.length) end = jsonResponse.length;
      if (start < end) {
        itensFiltrados = jsonResponse.sublist(start, end);
      }
    }

    int countBotoes = 0;
    final Map<String, bool> novoEstado = {};
    for (var raw in itensFiltrados) {
      final map = (raw as Map).cast<String, dynamic>();
      final tipo = _getTipo(map);
      if (tipo == 'botao' || tipo == 'button') {
        final String? id = map['phrase_id'] as String?;
        if (id != null && id.isNotEmpty) {
          countBotoes++;
          novoEstado.putIfAbsent(id, () => false);
        }
      }
    }

    if (mounted) {
      setState(() {
        _itensDaLicao = itensFiltrados;
        _totalBotoesNaLicao = countBotoes;
        _estadoExibicaoLocal
          ..clear()
          ..addAll(novoEstado);
      });
    }
  }

  Future<void> _carregarProgresso() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? saved = prefs.getStringList(_progressoKey);
    if (mounted) {
      setState(() {
        _botoesConcluidos = saved?.toSet() ?? {};
      });
    }
  }

  Future<void> _salvarProgresso(String id, {required bool isConcluido}) async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        if (isConcluido) {
          _botoesConcluidos.add(id);
        } else {
          _botoesConcluidos.remove(id);
        }
      });
    }
    await prefs.setStringList(_progressoKey, _botoesConcluidos.toList());
  }

  // =========================
  // Idioma e check globais
  // =========================
  void _toggleIdiomaGlobal() {
    setState(() {
      _mostrarInglesGlobal = !_mostrarInglesGlobal;
      for (final id in _estadoExibicaoLocal.keys) {
        _estadoExibicaoLocal[id] = _mostrarInglesGlobal;
      }
    });
  }

  Future<void> _toggleCheckGlobal() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_todosEstaoMarcados) {
        _botoesConcluidos.clear();
      } else {
        final allIds = <String>[];
        for (final raw in _itensDaLicao) {
          final map = (raw as Map).cast<String, dynamic>();
          final tipo = _getTipo(map);
          if (tipo == 'botao' || tipo == 'button') {
            final String? id = map['phrase_id'] as String?;
            if (id != null && id.isNotEmpty) allIds.add(id);
          }
        }
        _botoesConcluidos = allIds.toSet();
      }
    });
    await prefs.setStringList(_progressoKey, _botoesConcluidos.toList());
  }

  // =========================
  // Handlers de item único
  // =========================

  // ✅ CORREÇÃO: Adicionado 'lock' para não tocar áudio se "Play All" estiver ativo
  Future<void> _handleButtonPress(dynamic rawItem) async {
    // Se o "Play All" estiver rodando, ignora o toque no botão
    if (_isPlayingAll) return;

    final item = (rawItem as Map).cast<String, dynamic>();
    final String? phraseId = item['phrase_id'] as String?;
    if (phraseId == null || phraseId.isEmpty) return;

    if (!_botoesConcluidos.contains(phraseId)) {
      await _salvarProgresso(phraseId, isConcluido: true);
    }

    final bool novoMostrarIngles =
    !(_estadoExibicaoLocal[phraseId] ?? _mostrarInglesGlobal);
    if (mounted) {
      setState(() {
        _estadoExibicaoLocal[phraseId] = novoMostrarIngles;
      });
    }

    final String? storagePath = novoMostrarIngles
        ? (item['audio_en_storage_path'] as String?) ??
        (item['audio_pt_storage_path'] as String?)
        : (item['audio_pt_storage_path'] as String?) ??
        (item['audio_en_storage_path'] as String?);

    if (storagePath == null || storagePath.isEmpty) {
      return;
    }

    final String? audioUrl = await _getAudioUrlFromFirebase(storagePath);
    if (audioUrl == null) {
      developer.log("Falha ao obter URL, pulando play.");
      return;
    }

    try {
      // ✅ LÓGICA iOS APENAS
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(_velocidade); // Aplica velocidade
      await _audioPlayer.play(UrlSource(audioUrl));

    } catch (e) {
      developer.log("❌ ERRO AO TOCAR O ÁUDIO '$audioUrl': $e",
          name: 'AudioPlaybackError');
    }
  }

  Future<void> _handleCheckmarkToggle(dynamic rawItem) async {
    final item = (rawItem as Map).cast<String, dynamic>();
    final String? phraseId = item['phrase_id'] as String?;
    if (phraseId != null && phraseId.isNotEmpty) {
      final bool isCurrentlyConcluido = _botoesConcluidos.contains(phraseId);
      await _salvarProgresso(phraseId, isConcluido: !isCurrentlyConcluido);
    }
  }

  // =========================
  // Utilidades
  // =========================
  Color _hexToColor(String? hexString) {
    if (hexString == null || hexString.isEmpty) return Colors.grey[400]!;
    final hex = hexString.replaceAll('#', '');
    String argb;
    if (hex.length == 3) {
      final r = hex[0] * 2, g = hex[1] * 2, b = hex[2] * 2;
      argb = 'FF$r$g$b';
    } else if (hex.length == 6) {
      argb = 'FF$hex';
    } else if (hex.length == 8) {
      argb = hex;
    } else {
      return Colors.red;
    }
    try {
      return Color(int.parse(argb, radix: 16));
    } catch (_) {
      return Colors.red;
    }
  }

  String _getTipo(Map<String, dynamic> item) {
    return item['tipo']?.toString().toLowerCase() ??
        item['TIPO']?.toString().toLowerCase() ??
        '';
  }

  // ✅ CORREÇÃO: Função de áudio 100% iOS/Mobile com "lock"
  Future<String?> _getAudioUrlFromFirebase(String storagePath) async {
    // 1. Checa o cache de RAM (O mais rápido)
    if (_audioUrlCache.containsKey(storagePath)) {
      return _audioUrlCache[storagePath];
    }

    // 2. Checa se já está buscando (O "Lock")
    if (_pendingAudioFetches.containsKey(storagePath)) {
      return _pendingAudioFetches[storagePath];
    }

    // 3. Não está no cache e não está buscando. Crie um novo pedido.
    final completer = Completer<String?>();
    _pendingAudioFetches[storagePath] = completer.future;

    String? url;

    try {
      // 📱 MOBILE / MACOS: Usa o SDK
      final ref = FirebaseStorage.instance.ref(storagePath);
      url = await ref.getDownloadURL();

      if (url.isNotEmpty) {
        // Sucesso: Salva no cache de RAM
        _audioUrlCache[storagePath] = url;
        completer.complete(url);
      } else {
        completer.complete(null);
      }
    } catch (e) {
      developer.log("❌ ERRO Firebase Storage '$storagePath': $e",
          name: 'FirebaseAudioError');
      completer.complete(null); // Falha
    } finally {
      // 4. Remove o "lock"
      _pendingAudioFetches.remove(storagePath);
    }

    return completer.future;
  }

  // =========================
  // Scroll helper
  // =========================
  Future<void> _scrollToPhraseId(String? id) async {
    if (id == null) return;
    final key = _itemKeys[id];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 400),
      alignment: 0.2,
      curve: Curves.easeInOut,
    );
  }

  // =========================
  // Sequenciador determinístico (Play All)
  // =========================
  Future<String?> _resolverUrlAudio(Map<String, dynamic> item) async {
    String? preferida = _mostrarInglesGlobal
        ? item['audio_en_storage_path'] as String?
        : item['audio_pt_storage_path'] as String?;
    String? alternativa = _mostrarInglesGlobal
        ? item['audio_pt_storage_path'] as String?
        : item['audio_en_storage_path'] as String?;

    String? path = (preferida?.isNotEmpty == true)
        ? preferida
        : (alternativa?.isNotEmpty == true)
        ? alternativa
        : null;
    if (path == null) return null;

    // Reusa a função de cache/download (iOS-only)
    return _getAudioUrlFromFirebase(path);
  }

  // Helper _playWebAudioAndWait REMOVIDO (iOS Apenas)

  // ✅ CORREÇÃO: _playAndWait (iOS Apenas)
  Future<void> _playAndWait(String url,
      {int repeat = 1, Duration? timeout}) async {
    if (_stopRequested) return;

    for (int i = 0; i < repeat; i++) {
      if (_stopRequested) return;

      // 📱 Lógica 100% audioplayers
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(_velocidade); // Aplica velocidade
      await _audioPlayer.play(UrlSource(url));

      try {
        // Aguarda o listener no initState liberar o lock
        final fut = _audioPlayer.onPlayerComplete.first;
        if (timeout != null) {
          await fut.timeout(timeout);
        } else {
          await fut;
        }
      } on TimeoutException {
        developer.log("⏰ Timeout aguardando fim do áudio",
            name: 'PlayTimeout');
      }

      if (_stopRequested) return;
    }
  }

  List<Map<String, dynamic>> _buildLinearPlaylist() {
    final List<Map<String, dynamic>> playlist = [];
    for (final raw in _itensDaLicao) {
      final map = (raw as Map).cast<String, dynamic>();
      final tipo = _getTipo(map);
      if (tipo == 'botao' || tipo == 'button') {
        final hasPt =
            (map['audio_pt_storage_path'] as String?)?.isNotEmpty == true;
        final hasEn =
            (map['audio_en_storage_path'] as String?)?.isNotEmpty == true;
        if (hasPt || hasEn) playlist.add(map);
      }
    }
    return playlist;
  }

  Future<void> _reproduzirTodosComRepeticao() async {
    if (_isPlayingAll || _itensDaLicao.isEmpty) return;

    _stopRequested = false;
    _isPlayingAll = true;

    final playlist = _buildLinearPlaylist();
    if (playlist.isEmpty) {
      _isPlayingAll = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum áudio disponível nesta lição.')),
        );
        setState(() {});
      }
      return;
    }

    if (_currentIndex < 0 || _currentIndex >= playlist.length) {
      _currentIndex = 0;
    }
    if (mounted) setState(() {}); // atualiza botões

    bool terminouTudo = false;

    try {
      while (!_stopRequested && _currentIndex < playlist.length) {
        final item = playlist[_currentIndex];
        final String? phraseId = item['phrase_id'] as String?;

        await _scrollToPhraseId(phraseId);

        if (phraseId != null &&
            phraseId.isNotEmpty &&
            !_botoesConcluidos.contains(phraseId)) {
          await _salvarProgresso(phraseId, isConcluido: true);
        }

        final url = await _resolverUrlAudio(item);
        if (url == null) {
          developer.log("⚠ Sem URL no índice $_currentIndex",
              name: 'PlaylistSkip');
          _currentIndex++;
          continue;
        }

        // ✅ CHAMA A FUNÇÃO (iOS Apenas)
        await _playAndWait(
          url,
          repeat: _repeticoesGlobais,
          timeout: const Duration(seconds: 30),
        );

        if (_stopRequested) break;

        _currentIndex++;
      }

      terminouTudo = !_stopRequested && _currentIndex >= playlist.length;

      if (terminouTudo && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🎉 Áudios concluídos!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e, st) {
      developer.log("❌ Erro no sequenciador: $e\n$st", name: 'PlayAllError');
    } finally {
      _isPlayingAll = false;
      _stopRequested = false;
      if (terminouTudo) {
        _currentIndex = 0;
      }
      if (mounted) setState(() {});
    }
  }

  // =========================
  // Build
  // =========================
  @override
  Widget build(BuildContext context) {
    final double progressoAtual = _totalBotoesNaLicao > 0
        ? _botoesConcluidos.length / _totalBotoesNaLicao
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFD7E8C7),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(160), // Mantém altura
          child: Column(
            children: [
              // Linha 1: (Sua UI original)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.translate, size: 18),
                        label: Text(_labelIdiomaTopo,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        onPressed: _toggleIdiomaGlobal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          _todosEstaoMarcados ? Colors.teal : Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                          _todosEstaoMarcados
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          size: 18,
                        ),
                        label: Text(
                            _todosEstaoMarcados ? 'Desmarcar' : 'Marcar',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        onPressed: _toggleCheckGlobal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          _isPlayingAll ? Colors.green : Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          minimumSize: const Size(0, 40),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: Icon(
                            _isPlayingAll ? Icons.pause : Icons.play_arrow,
                            size: 18),
                        label: Text(_isPlayingAll ? 'Pausar' : 'Play',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        onPressed: () async {
                          if (_isPlayingAll) {
                            // Pausar
                            _stopRequested = true;
                            await _audioPlayer.stop(); // Apenas iOS
                            if (mounted) setState(() => _isPlayingAll = false);
                          } else {
                            // Play
                            await _reproduzirTodosComRepeticao();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Linha 2: (Sua UI original com Velocidade)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text("Velocidade:",
                            style:
                            TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(width: 8),
                        DropdownButton<double>(
                          value: _velocidade,
                          underline: const SizedBox.shrink(),
                          iconEnabledColor: Colors.white, // Ícone do dropdown
                          dropdownColor: Colors.blueAccent,
                          style: const TextStyle(color: Colors.white),
                          items: const [
                            DropdownMenuItem(
                              value: 1.0,
                              child: Text('1.0x'),
                            ),
                            DropdownMenuItem(
                              value: 1.25,
                              child: Text('1.25x'),
                            ),
                            DropdownMenuItem(
                              value: 1.5,
                              child: Text('1.5x'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _velocidade = v);
                          },
                        ),
                        const Spacer(),
                        const Text("Repetições:",
                            style:
                            TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Slider(
                            value: _repeticoesGlobais.toDouble(),
                            min: 1.0,
                            max: 5.0,
                            divisions: 4,
                            label: _repeticoesGlobais.toString(),
                            activeColor: Colors.greenAccent,
                            onChanged: (value) => setState(
                                    () => _repeticoesGlobais = value.round()),
                          ),
                        ),
                      ],
                    ),
                    LinearProgressIndicator(
                      value: progressoAtual,
                      minHeight: 5,
                      color: Colors.lightGreenAccent,
                      backgroundColor: Colors.white24,
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_botoesConcluidos.length} / $_totalBotoesNaLicao',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _itensDaLicao.length,
        itemBuilder: (context, index) {
          final raw = _itensDaLicao[index];
          final map = (raw as Map).cast<String, dynamic>();
          final String tipoItem = _getTipo(map);

          if (tipoItem == 'explicacao') {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                map['frase'] ?? 'Texto não encontrado.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18, fontStyle: FontStyle.italic),
              ),
            );
          } else if (tipoItem == 'botao' || tipoItem == 'button') {
            final String? id = map['phrase_id'] as String?;
            if (id == null || id.isEmpty) return const SizedBox.shrink();

            final key = _itemKeys.putIfAbsent(id, () => GlobalKey());
            final bool isConcluido = _botoesConcluidos.contains(id);
            final bool mostrarIngles =
                _estadoExibicaoLocal[id] ?? _mostrarInglesGlobal;

            final Color corDoBotao = mostrarIngles
                ? _hexToColor(map['corToque'] as String?)
                : _hexToColor(map['corPadrao'] as String?);

            return Container(
              key: key,
              margin: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleButtonPress(map),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: corDoBotao,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 12),
                    minimumSize: const Size(0, 44), // compacto
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          mostrarIngles
                              ? (map['text_en'] ?? 'N/A')
                              : (map['text_pt'] ?? 'N/A'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: mostrarIngles
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 34,
                        child: Tooltip(
                          message: isConcluido ? 'Desmarcar' : 'Marcar',
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _handleCheckmarkToggle(raw),
                            icon: Icon(
                              isConcluido
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isConcluido
                                  ? Colors.greenAccent
                                  : Colors.white70,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}