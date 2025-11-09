//
// ARQUIVO COMPLETO E CORRIGIDO: LessonPageModuloZero.dart
// (100% Focado no iOS - sem Web)
//
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter/foundation.dart' show kIsWeb; // Removido (iOS Apenas)
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';

// import 'src/conditional_html.dart' if (dart.library.html) 'dart:html' as html; // Removido (iOS Apenas)

import '../models/audio_phrase.dart';
import '../widgets/lesson_button.dart';

class LessonPageModuloZero extends StatefulWidget {
  final String title;
  final String jsonPath;

  const LessonPageModuloZero({
    super.key,
    required this.title,
    required this.jsonPath,
  });

  @override
  State<LessonPageModuloZero> createState() => _LessonPageModuloZeroState();
}

class _LessonPageModuloZeroState extends State<LessonPageModuloZero> {
  List<AudioPhrase> itensDaLicao = [];
  bool carregando = true;
  Set<String> botoesConcluidos = {};
  int totalBotoesNaLicao = 0;

  final AudioPlayer audioPlayer = AudioPlayer();
  late SharedPreferences prefs;
  late String progressoKey;

  // Locks de áudio
  final Map<String, String> _audioUrlCache = {};
  final Map<String, Future<String?>> _pendingAudioFetches = {};
  bool _isAudioPlaying = false;

  final Map<String, List<Map<String, String>>> configuracaoLegendas = {
    'assets/data/modulo_zero/licao_a.json': [
      {'letra': 'á-é', 'cor': '#3F51B5'},
      {'letra': 'Á-ÓR', 'cor': '#F44336'},
      {'letra': 'ó', 'cor': '#ff9800'},
      {'letra': 'ei', 'cor': '#9c27b0'},
      {'letra': 'ô', 'cor': '#2196f3'}
    ],
    'assets/data/modulo_zero/licao_e.json': [
      {'letra': 'é', 'cor': '#9c27b0'},
      {'letra': 'ê-ei', 'cor': '#3F51B5'},
      {'letra': 'íí', 'cor': '#2196f3'}
    ],
    'assets/data/modulo_zero/licao_i.json': [
      {'letra': 'i', 'cor': '#3F51B5'},
      {'letra': 'ai', 'cor': '#ff9800'}
    ],
    'assets/data/modulo_zero/licao_o.json': [
      {'letra': 'ó', 'cor': '#3F51B5'},
      {'letra': 'a', 'cor': '#F44336'},
      {'letra': 'ou-ô', 'cor': '#9c27b0'}
    ],
    'assets/data/modulo_zero/licao_u.json': [
      {'letra': 'iu', 'cor': '#3F51B5'},
      {'letra': 'a-ʌ', 'cor': '#F44336'},
      {'letra': 'u', 'cor': '#ff9800'},
      {'letra': 'uu', 'cor': '#9c27b0'},
      {'letra': 'ú', 'cor': '#2196f3'}
    ],
  };

  // ✅ CÓDIGO NOVO CORRIGIDO
  @override
  void initState() {
    super.initState();
    progressoKey =
    'progresso_${widget.jsonPath.replaceAll('/', '_').replaceAll('.', '_')}';

    // ✅ CORREÇÃO: Listener para liberar o "lock" (sem .error)
    audioPlayer.onPlayerStateChanged.listen((PlayerState s) {
      if (s == PlayerState.completed || s == PlayerState.stopped) {
        if (mounted) {
          setState(() {
            _isAudioPlaying = false;
          });
        }
      }
    });

    _carregarDadosIniciais();
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosIniciais() async {
    await _carregarLicaoDoJson();
    await _carregarProgressoSalvo();
    if (mounted) setState(() => carregando = false);
  }

  Future<void> _carregarLicaoDoJson() async {
    try {
      final jsonString = await rootBundle.loadString(widget.jsonPath);
      final List<dynamic> jsonResponse = json.decode(jsonString);
      final frases = jsonResponse
          .where((item) => item['tipo'] == 'button')
          .map((item) => AudioPhrase.fromJson(item))
          .toList();

      setState(() {
        itensDaLicao = frases;
        totalBotoesNaLicao = frases.length;
      });
    } catch (e) {
      developer.log("❌ ERRO AO CARREGAR JSON: $e", name: 'LessonLoadError');
    }
  }

  Future<void> _carregarProgressoSalvo() async {
    prefs = await SharedPreferences.getInstance();
    final savedProgress = prefs.getStringList(progressoKey);
    if (savedProgress != null) {
      setState(() => botoesConcluidos = savedProgress.toSet());
    }
  }

  void _onIconTapped(AudioPhrase item) async {
    final id = item.phraseId;
    final isConcluido = botoesConcluidos.contains(id);
    setState(() =>
    isConcluido ? botoesConcluidos.remove(id) : botoesConcluidos.add(id));
    await prefs.setStringList(progressoKey, botoesConcluidos.toList());
  }

  // ✅ CORREÇÃO: Função de buscar URL simplificada (Sem Web) e com "lock"
  Future<String?> _getAudioUrlWithCache(String storagePath) async {
    // 1. Checa o cache de RAM
    if (_audioUrlCache.containsKey(storagePath)) {
      return _audioUrlCache[storagePath];
    }
    // 2. Checa se já está buscando (Lock de download)
    if (_pendingAudioFetches.containsKey(storagePath)) {
      return _pendingAudioFetches[storagePath];
    }

    // 3. Cria um novo pedido
    final completer = Completer<String?>();
    _pendingAudioFetches[storagePath] = completer.future;

    String? url;
    try {
      // 📱 Apenas lógica de iOS/Mobile
      final ref = FirebaseStorage.instance.ref(storagePath);
      url = await ref.getDownloadURL();

      if (url.isNotEmpty) {
        _audioUrlCache[storagePath] = url; // Salva no cache
        completer.complete(url);
      } else {
        completer.complete(null);
      }
    } catch (e) {
      developer.log("❌ ERRO Firebase Storage '$storagePath': $e",
          name: 'FirebaseAudioError');
      completer.complete(null);
    } finally {
      // 4. Remove o lock de download
      _pendingAudioFetches.remove(storagePath);
    }
    return completer.future;
  }

  // ✅ CORREÇÃO: _onBotaoTapped atualizado com "lock" de play
  Future<void> _onBotaoTapped(AudioPhrase item) async {

    // 1. VERIFICA O "LOCK" DE PLAY
    if (_isAudioPlaying) {
      developer.log("Bloqueado: Áudio já está tocando.", name: 'AudioLock');
      return; // Sai se já estiver tocando
    }

    // 2. ATIVA O "LOCK"
    if (mounted) setState(() => _isAudioPlaying = true);

    // 3. Busca a URL
    final String? url = await _getAudioUrlWithCache(item.audioPath);

    if (url == null || url.isEmpty) {
      developer.log("❌ Falha ao obter URL para '${item.audioPath}'", name: 'AudioError');
      // 4. LIBERA O "LOCK" EM CASO DE ERRO
      if (mounted) setState(() => _isAudioPlaying = false);
      return;
    }

    // 5. Toca o áudio
    try {
      // 📱 Apenas lógica de iOS/Mobile (audioplayers)
      // O listener no initState vai liberar o lock

      // ✅ CORREÇÃO: Verifica o estado antes de dar stop
      if (audioPlayer.state == PlayerState.playing) {
        await audioPlayer.stop();
      }
      await audioPlayer.play(UrlSource(url));

    } catch (e) {
      developer.log("❌ Erro ao TOCAR áudio '$url': $e", name: 'AudioError');
      // 4. LIBERA O "LOCK" EM CASO DE ERRO
      if (mounted) setState(() => _isAudioPlaying = false);
    }

    // 6. Salva o progresso
    if (!botoesConcluidos.contains(item.phraseId)) {
      setState(() => botoesConcluidos.add(item.phraseId));
      await prefs.setStringList(progressoKey, botoesConcluidos.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    double progressoAtual = totalBotoesNaLicao > 0
        ? botoesConcluidos.length / totalBotoesNaLicao
        : 0.0;
    final legendas = configuracaoLegendas[widget.jsonPath] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: progressoAtual,
                  backgroundColor: Colors.blue[100],
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                ),
                const SizedBox(height: 4),
                Text(
                  '${botoesConcluidos.length}/$totalBotoesNaLicao Concluídos',
                  style: const TextStyle(color: Colors.white, fontSize: 22),
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: const Color(0xFFD7E8C7),
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          if (legendas.isNotEmpty) _buildLegenda(legendas),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: itensDaLicao.map((item) {
                  return _buildBotaoLicao(item);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoLicao(AudioPhrase item) {
    final concluido = botoesConcluidos.contains(item.phraseId);
    final Color corBotao =
    concluido ? _hexToColor(item.corToque) : _hexToColor(item.corPadrao);
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = (screenWidth - 16 * 2 - 12) / 2;

    return LessonButton(
      textEn: item.textEn,
      textPt: item.textPt,
      color: corBotao,
      isCompleted: concluido,
      isLocked: false,
      width: buttonWidth,
      onPressed: () => _onBotaoTapped(item),
      onIconPressed: () => _onIconTapped(item),
    );
  }

  Widget _buildLegenda(List<Map<String, String>> legendas) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10.0,
        runSpacing: 10.0,
        children: legendas.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _hexToColor(item['cor']!),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item['letra']!,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 26),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Função de cor (Seu código original, está correto)
  Color _hexToColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey.shade400;
    final cleanHex = hex.length == 7 ? hex.substring(1) : hex;
    try {
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (e) {
      developer.log("❌ Erro ao converter Hex '$hex': $e",
          name: 'HexColorError');
      return Colors.red;
    }
  }
}