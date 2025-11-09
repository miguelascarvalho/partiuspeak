//
// PÁGINA CORRIGIDA: lib/pages/meus_textos.dart
// (Focada 100% no iOS, imports corrigidos)
//
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';
import 'dart:developer' as developer;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';

// ✅ IMPORTS CORRIGIDOS E ADICIONADOS
import 'dart:io'; // Para 'Platform' e 'File'/'Directory'
import 'package:path_provider/path_provider.dart'; // Para 'getApplicationDocumentsDirectory'
import 'package:flutter/foundation.dart' show kIsWeb; // Para checar se NÃO é web

// Imports internos
import 'package:partiuspeak/pages/saved_texts_page.dart';
// 🔹 NOTA: O 'file_helpers.dart' não é mais necessário,
//    pois 'dart:io' e 'path_provider' já foram importados aqui.
// import 'package:partiuspeak/services/file_helpers.dart';


/// Enum para representar o estado do Text-to-Speech (TTS).
enum TtsState { playing, paused, stopped }

/// Um StatefulWidget que exibe e traduz texto,
/// com funcionalidade de leitura sincronizada.
class MeusTextosPage extends StatefulWidget {
  const MeusTextosPage({super.key});

  @override
  State<MeusTextosPage> createState() => _MeusTextosPageState();
}

class _MeusTextosPageState extends State<MeusTextosPage> {
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _englishTextController = TextEditingController();
  final GoogleTranslator _translator = GoogleTranslator();

  final ScrollController _englishScrollController = ScrollController();
  final ScrollController _portugueseScrollController = ScrollController();

  List<GlobalKey> _englishSentenceKeys = [];
  List<GlobalKey> _portugueseSentenceKeys = [];

  String _portugueseText = "";
  List<String> _englishSentences = [];
  List<String> _portugueseSentences = [];

  TtsState _ttsState = TtsState.stopped;
  int _currentSentenceIndex = -1;
  bool _isTranslating = false;

  // DEFAULTS: velocidade natural 1.0, pitch 1.0
  double _speechRate = 1.0;
  double _pitch = 1.0;
  String _currentTtsLanguage = "en-US";

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadSavedState();
    _englishTextController.addListener(() {
      setState(() {});
    });

    // Apenas execute em plataformas móveis (NÃO na web)
    if (!kIsWeb) {
      // Chamada para copiar textos de EXEMPLO para a pasta local
      _copyInitialTextsIfNeeded();
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _englishTextController.dispose();
    _englishScrollController.dispose();
    _portugueseScrollController.dispose();
    _saveState(); // Salva o estado ao sair
    super.dispose();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('savedEnglishText', _englishTextController.text);
    await prefs.setString('savedPortugueseText', _portugueseText);
    await prefs.setInt('savedIndex', _currentSentenceIndex);
    await prefs.setDouble('savedSpeechRate', _speechRate);
    await prefs.setDouble('savedPitch', _pitch);
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEnglishText = prefs.getString('savedEnglishText') ??
        "Welcome! Paste your text here and press translate.";
    final savedPortugueseText = prefs.getString('savedPortugueseText') ??
        "Bem-vindo! Cole seu texto aqui e pressione traduzir.";
    final savedIndex = prefs.getInt('savedIndex') ?? -1;
    final savedSpeechRate = prefs.getDouble('savedSpeechRate') ?? 1.0;
    final savedPitch = prefs.getDouble('savedPitch') ?? 1.0;

    _englishTextController.text = savedEnglishText;
    _portugueseText = savedPortugueseText;
    _currentSentenceIndex = savedIndex;
    _speechRate = savedSpeechRate;
    _pitch = savedPitch;

    if (savedIndex != -1) {
      _ttsState = TtsState.paused;
    }
    _prepareTextsFromState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (savedIndex != -1) {
        _scrollToSentence(savedIndex, animate: false);
      }
    });
  }

  void _prepareTextsFromState() {
    if (mounted) {
      setState(() {
        _englishSentences =
            _englishTextController.text.split(RegExp(r'(?<=[.!?])\s*'));
        _portugueseSentences = _portugueseText.split(RegExp(r'(?<=[.!?])\s*'));

        _englishSentences.removeWhere((s) => s.trim().isEmpty);
        _portugueseSentences.removeWhere((s) => s.trim().isEmpty);

        _englishSentenceKeys =
            List.generate(_englishSentences.length, (_) => GlobalKey());
        _portugueseSentenceKeys =
            List.generate(_portugueseSentences.length, (_) => GlobalKey());
      });
    }
  }

  // ✅ _initTts SIMPLIFICADA (sem lógica Web)
  Future<void> _initTts() async {

    await _checkLanguageSupport();

    _flutterTts.setCompletionHandler(() {
      if (_ttsState == TtsState.playing) {
        if (_currentSentenceIndex < _englishSentences.length - 1) {
          _speakSentence(_currentSentenceIndex + 1);
        } else {
          _stop();
        }
      }
    });

    _flutterTts.setErrorHandler((msg) {
      developer.log("❌ Erro de TTS: $msg", name: 'TTS');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erro ao reproduzir áudio: $msg"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });
  }

  Future<void> _checkLanguageSupport() async {
    try {
      final languages = await _flutterTts.getLanguages;
      developer.log("Idiomas disponíveis para TTS: $languages", name: 'TTS');
      if (languages.contains("en-US")) {
        _currentTtsLanguage = "en-US";
      } else if (languages.contains("en-GB")) {
        _currentTtsLanguage = "en-GB";
      } else {
        final englishLocale = languages.firstWhere(
              (lang) => lang.toString().startsWith('en'),
          orElse: () => '',
        );
        if (englishLocale.toString().isNotEmpty) {
          _currentTtsLanguage = englishLocale.toString();
        } else {
          _currentTtsLanguage = "en-US";
          developer.log("Nenhum idioma inglês disponível no dispositivo!",
              name: 'TTS');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      "Aviso: Nenhuma voz em inglês encontrada. O áudio pode não funcionar corretamente.")),
            );
          }
        }
      }

      await _flutterTts.setLanguage(_currentTtsLanguage);
      developer.log("Idioma TTS definido para '$_currentTtsLanguage'.",
          name: 'TTS');

      // ✅ ERRO 'Platform' CORRIGIDO (import 'dart:io' foi adicionado no topo)
      if (Platform.isIOS || Platform.isMacOS) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    "Nota: em iOS/macOS a velocidade máxima prática do TTS é 1.0. Valores acima serão limitados.")),
          );
        }
      }

      try {
        final voices = await _flutterTts.getVoices;
        developer.log("Voices disponíveis: $voices", name: 'TTS');
        if (voices is List) {
          for (var v in voices) {
            try {
              if (v is Map) {
                final locale = (v['locale'] ?? '').toString();
                if (locale.startsWith('en')) {
                  final Map<String, String> voiceMap = v.map((key, value) =>
                      MapEntry(key.toString(),
                          value == null ? '' : value.toString()));
                  await _flutterTts.setVoice(voiceMap);
                  developer.log(
                      "Voice escolhida: ${voiceMap['name'] ?? voiceMap['voice'] ?? voiceMap['id']} (locale: $locale)",
                      name: 'TTS');
                  break;
                }
              } else if (v is String) {
                if (v.contains('en') || v.contains('EN')) {
                  try {
                    await _flutterTts.setVoice({'name': v});
                    developer.log("Voice escolhida (string): $v", name: 'TTS');
                    break;
                  } catch (_) {
                    // ignore
                  }
                }
              }
            } catch (e) {
              developer.log("Erro ao tentar setVoice para item: $v -> $e",
                  name: 'TTS_VoiceSelection');
            }
          }
        }
      } catch (e) {
        developer.log("Erro ao selecionar voice: $e",
            name: 'TTS_VoiceSelection');
      }
    } catch (e) {
      developer.log("Erro ao verificar idiomas do TTS: $e", name: 'TTS_Error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao configurar voz: $e")),
        );
      }
    }
  }

  // ✅ _mapSpeechRate SIMPLIFICADO (sem Web)
  double _mapSpeechRate(double uiRate) {
    // No Mobile, a escala é diferente.
    // Mapeia o valor da UI (0.5 a 2.0) para uma escala de plataforma (0.1 a 1.2)
    // O valor 1.0 (natural na UI) se traduz para 0.5 (natural no mobile).
    // O valor 2.0 (rápido na UI) se traduz para 1.0 (rápido no mobile).
    double platformRate = (uiRate - 0.5) * 0.4 + 0.1;
    return platformRate.clamp(0.1, 1.2);
  }

  // ✅ _translateAndPrepareTexts SIMPLIFICADO (sem Web)
  Future<void> _translateAndPrepareTexts() async {
    if (_englishTextController.text.trim().isEmpty) return;
    setState(() => _isTranslating = true);

    // Lógica original (Mobile)
    try {
      final originalText = _englishTextController.text;

      final Translation englishTranslationAttempt =
      await _translator.translate(originalText, to: 'en');

      String finalPortugueseText = "";
      String textForEnglishAudioBox = originalText;

      bool originalIsEnglish = originalText.toLowerCase().trim() ==
          englishTranslationAttempt.text.toLowerCase().trim();

      if (originalIsEnglish) {
        final portugueseTranslation =
        await _translator.translate(originalText, from: 'en', to: 'pt');
        finalPortugueseText = portugueseTranslation.text;
      } else {
        textForEnglishAudioBox = englishTranslationAttempt.text;
        final portugueseTranslation =
        await _translator.translate(originalText, to: 'pt');
        finalPortugueseText = portugueseTranslation.text;
      }

      if (!mounted) return;

      _englishTextController.text = textForEnglishAudioBox;
      _portugueseText = finalPortugueseText;
      _currentSentenceIndex = -1;
      _prepareTextsFromState();
      await _saveState();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erro na tradução: $e")));
      developer.log("Erro na tradução ou detecção: $e",
          name: 'Translation_Error');
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }


  Future<void> _play() async {
    if (_englishSentences.isEmpty || _ttsState == TtsState.playing) return;

    final platformRate = _mapSpeechRate(_speechRate);

    developer.log(
        "UI rate: $_speechRate -> Platform rate (enviado para o TTS): $platformRate",
        name: 'TTS_Rate');

    await _flutterTts.setSpeechRate(platformRate);
    await _flutterTts.setPitch(_pitch);
    await _flutterTts.setLanguage(_currentTtsLanguage);

    if (mounted) {
      setState(() => _ttsState = TtsState.playing);
    }

    int startIndex = (_currentSentenceIndex != -1) ? _currentSentenceIndex : 0;
    _speakSentence(startIndex);
  }

  Future<void> _pause() async {
    await _flutterTts.pause();
    if (mounted) setState(() => _ttsState = TtsState.paused);
    await _saveState();
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
    if (mounted) {
      setState(() {
        _ttsState = TtsState.stopped;
        _currentSentenceIndex = -1;
      });
    }
    await _saveState();
  }

  Future<void> _speakSentence(int index) async {
    if (index >= _englishSentences.length) {
      _stop();
      return;
    }

    if (!mounted) return;

    setState(() {
      _currentSentenceIndex = index;
    });
    _scrollToSentence(index);

    final sentence = _englishSentences[index];
    await _flutterTts.setLanguage(_currentTtsLanguage);
    await _flutterTts.speak(sentence);
  }


  void _scrollToSentence(int index, {bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final duration =
      animate ? const Duration(milliseconds: 600) : Duration.zero;
      const curve = Curves.easeInOut;

      if (index < _englishSentenceKeys.length &&
          _englishSentenceKeys[index].currentContext != null) {
        Scrollable.ensureVisible(
          _englishSentenceKeys[index].currentContext!,
          duration: duration,
          curve: curve,
          alignment: 0.5,
        );
      }

      if (index < _portugueseSentenceKeys.length &&
          _portugueseSentenceKeys[index].currentContext != null) {
        Scrollable.ensureVisible(
          _portugueseSentenceKeys[index].currentContext!,
          duration: duration,
          curve: curve,
          alignment: 0.5,
        );
      }
    });
  }

  // ✅ ERRO 'getApplicationDocumentsDirectory' CORRIGIDO
  // (import 'package:path_provider/path_provider.dart' foi adicionado no topo)
  Future<String> _getAppTextsDirectoryPath() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/meus_textos_salvos';

    // ✅ ERRO 'Directory' CORRIGIDO (import 'dart:io' foi adicionado no topo)
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<void> _uploadAudioToFirebase(
      String assetPath, String storagePath) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        developer.log(
            "Erro: Usuário não logado. Não é possível fazer upload de áudio para '$storagePath'.",
            name: 'UploadAudio');
        return;
      }

      final byteData = await rootBundle.load(assetPath);
      final Uint8List bytes = byteData.buffer.asUint8List();

      final storageRef = FirebaseStorage.instance.ref(storagePath);

      await storageRef.putData(bytes);
      developer.log(
          "Upload do áudio '$assetPath' para '$storagePath' concluído com sucesso!",
          name: 'UploadAudio');
    } catch (e) {
      developer.log(
          "Erro ao fazer upload do áudio '$assetPath' para '$storagePath': $e",
          name: 'UploadAudioError');
    }
  }

  Future<void> _copyInitialTextsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool alreadyCopiedAndUploaded =
        prefs.getBool('initialTextsCopiedAndUploaded') ?? false;

    if (!alreadyCopiedAndUploaded) {
      try {
        final String appTextsDir = await _getAppTextsDirectoryPath();

        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          developer.log(
              "AVISO: Usuário não logado ao tentar copiar/uploadar dados iniciais. Tente novamente após o login.",
              name: 'InitialDataWarning');
          return;
        }

        // --- LISTA COMPLETA DE TEXTOS E ÁUDIOS INICIAIS ---
        final List<Map<String, String>> initialContent = [
          {
            'filename': 'Meu Primeiro Dia na Escola.txt',
            'content': '''Hoje foi meu primeiro dia na escola!
Acordei cedo, vesti meu uniforme azul e comi pão com manteiga.
Minha mochila estava pesada, mas eu gostei.
Lá na escola tinha um monte de criança.
Fiquei com vergonha no começo.
A professora se chama Tia Lúcia.
Ela é muito legal.
Ela me deu massinha pra brincar.
Depois fizemos um desenho com lápis de cor.
Tinha lápis de todas as cores!
Conheci um menino chamado João.
Ele me emprestou uma cola.
A gente brincou de carrinho no recreio.
Tinha escorregador e gangorra!
Comi biscoito e suco na lancheira.
Saí com vontade de voltar amanhã.
Minha mãe disse que fui corajoso.
Eu achei que seria difícil.
Mas foi bem legal.
A escola é divertida!
A professora disse que amanhã vai ter história.
Eu quero ir logo!
Vou levar meu caderno novo.
E desenhar um foguete.
A escola tem cheiro de lápis novo.
E barulho de criança rindo.
Gostei muito!
Quero ir todos os dias!''',
            'audio_asset_path': 'assets/audio/meu_primeiro_dia_na_escola.mp3',
            'storage_path': 'audios/meu_primeiro_dia_na_escola.mp3'
          },
          // ... (O resto da sua lista de textos) ...
          {
            'filename': 'Minha Primeira Viagem de Carro.txt',
            'content': '''Eu fui viajar com meu pai e minha mãe.
A gente colocou mala no carro.
Eu levei meu travesseiro e meu dinossauro de pelúcia.
Fiquei na cadeirinha, com cinto.
Papai ligou o rádio e tocou música animada.
A estrada era comprida.
Tinha vaca, cavalo, árvore...
Passamos por uma ponte bem grandona!
Parei de contar os carros porque cansei.
A gente parou num posto pra lanchar.
Eu comi coxinha e suco de caixinha.
Depois dormi um pouquinho.
Quando acordei, já estava chegando.
A casa era da minha tia.
Tinha um cachorro que correu atrás de mim.
Eu ri muito!
Dormimos em um quarto com colchão no chão.
Vi estrela no céu à noite.
De manhã, fui ver galinha no quintal.
Ganhei um ovo quentinho.
Foi minha primeira viagem.
Gostei de ver o mundo pela janela.
No caminho de volta, cantei alto.
Quero viajar de novo!
Quero ir de avião agora!''',
            'audio_asset_path':
            'assets/audio/minha_primeira_viagem_de_carro.mp3',
            'storage_path': 'audios/minha_primeira_viagem_de_carro.mp3'
          },
          {
            'filename': 'Meu Primeiro Jogo de Futebol no Estádio.txt',
            'content': '''Papai me levou no estádio pela primeira vez.
Eu vesti a camisa do nosso time.
Fiquei todo animado!
A gente pegou ônibus cheio de torcedores.
Todo mundo cantava.
Quando cheguei, vi aquele gramado grandão.
Parecia um campo de mentira!
Tinha muita gente gritando.
Comprei pipoca e refrigerante.
Papai me botou nos ombros dele.
Vi os jogadores entrando!
Pareciam heróis!
Quando o time fez gol, todo mundo pulou.
Eu quase caí de tanto pular!
Tinha bandeira, buzina e gente pintada.
Foi muito barulhento, mas muito legal.
Eu gritei: "Vai time!"
Queria entrar no campo também.
Ganhei um bandeirinha do moço do lado.
Ficamos até o final.
Nosso time ganhou!
Voltei feliz da vida.
Agora quero ir sempre!
Futebol ao vivo é muito melhor!''',
            'audio_asset_path':
            'assets/audio/meu_primeiro_jogo_de_futebol_no_estadio.mp3',
            'storage_path': 'audios/meu_primeiro_jogo_de_futebol_no_estadio.mp3'
          },
          {
            'filename': 'Minha Primeira Festa Junina.txt',
            'content': '''Hoje teve festa junina na escola!
Eu fui de camisa xadrez e chapéu de palha.
Minha mãe pintou bigode em mim.
Tinha bandeirinhas coloridas por todo lado!
A gente dançou quadrilha.
Eu fiquei de par com a Luiza.
A professora falava: “Olha o túnel!”
A gente ria e dançava de mãos dadas.
Tinha barraquinha de pescaria e argola.
Ganhei uma escova de dente!
Comi milho, pipoca e doce de abóbora.
Também tinha maçã do amor, mas gruda no dente.
Vi um menino tropeçar no pé de moleque.
Teve fogueira (de mentira).
Cantamos músicas juninas bem alto.
Todo mundo batia palma.
Papai tirou uma foto minha dançando.
Depois sentei cansado, mas feliz.
Foi muito legal!
Eu quero outra festa logo.
Vou guardar meu chapéu pra próxima.
Ah, e teve correio elegante!
Recebi um bilhetinho que dizia: "Você é legal".
Eu amei!''',
            'audio_asset_path': 'assets/audio/minha_primeira_festa_junina.mp3',
            'storage_path': 'audios/minha_primeira_festa_junina.mp3'
          },
          {
            'filename': 'Meu Primeiro Natal com a Família Toda.txt',
            'content': '''Foi a noite mais brilhante do ano!
Tinha luzes coloridas na casa da vovó.
A árvore de Natal era cheia de bolas vermelhas.
Eu ajudei a colocar o pisca-pisca.
Tinha presente embaixo da árvore!
Minha prima veio com um vestido com laço.
Comemos muitas comidas gostosas.
Rabanada, arroz com passas, farofa!
Mas eu só queria saber do presente.
Quando deu meia-noite, todo mundo gritou: “Feliz Natal!”
Papai Noel apareceu!
Era meu tio disfarçado, mas eu fingi que não percebi.
Ganhei um carrinho de controle remoto!
Eu quase chorei de alegria.
A gente tirou muitas fotos.
Eu e meus primos brincamos até dormir.
Dormimos no colchão na sala.
Tinha cheiro de canela e rabanada no ar.
Foi mágico.
Eu amo o Natal!
Já quero o próximo!''',
            'audio_asset_path':
            'assets/audio/meu_primeiro_natal_com_a_familia_toda.mp3',
            'storage_path': 'audios/meu_primeiro_natal_com_a_familia_toda.mp3'
          },
          {
            'filename': 'Médico.txt',
            'content':
            '''A medicina é a profissão dedicada ao diagnóstico, prevenção e tratamento de doenças.
Existem dezenas de especializações: clínica geral, cardiologia, neurologia, pediatria, ortopedia, dermatologia, psiquiatria, entre outras.
Cada especialidade exige formação adicional, como residência médica e, muitas vezes, mestrado ou doutorado.
O ambiente de trabalho pode variar: hospitais públicos e privados, clínicas, ambulatórios, unidades de saúde da família, instituições de pesquisa e universidades.
Um cardiologista, por exemplo, realiza eletrocardiogramas, ecocardiogramas, ajusta medicações para pressão, e acompanha cirurgias cardíacas em centro cirúrgico.
Já um pediatra faz consultas de rotina, vacinações, avalia desenvolvimento infantil, orienta mães e acompanha doenças respiratórias e gastrointestinais.
Em termos de atividades “grandes”, há plantões hospitalares, cirurgias eletivas e de emergência, administração de unidades de terapia intensiva.
Atividades “pequenas” incluem preencher prontuário, receituário, solicitar exames laboratoriais, medir pressão e orientar paciente e familiares.
A rotina médica exige uso de ferramentas como estetoscópio, tensiômetro, otoscópio, ultrassom portátil, softwares de prontuário eletrônico e sistemas de prescrição eletrônica.
Médicos interagem com enfermeiros, fisioterapeutas, técnicos de laboratório, farmacêuticos, psicólogos, assistentes sociais, respondendo por trabalho em equipe.
Em hospitais, participam de rounds clínicos, auditorias, protocolos de segurança e reuniões de comissões técnicas.
Na atenção primária, fortificam vínculo médico-paciente, promovem campanhas de saúde, realizam prevenção de doenças crônicas e educam a comunidade.
A pesquisa médica envolve estudos clínicos, ensaios e publicações científicas, exigindo análise estatística e conhecimento em bioética.
Os desafios incluem carga de trabalho intensa, gestão de situações de vida ou morte, atualização constante e estresse emocional.
Há também atuação em locais não tradicionais: medicina esportiva, medicina do trabalho, medicina forense e telemedicina.
Médicos de família lidam com pacientes de todas as idades, coordenam cuidados integrados e acompanham doenças crônicas ao longo da vida.
Na emergência, o médico de pronto-socorro precisa priorizar casos, realizar ressuscitação, intubação, suturas e trauma imediato.
Cirurgiões — seja geral, ortopédico, vascular ou plástico — operam em salas cirúrgicas com equipe multi disciplinar, usando bisturi, eletrocautério, e equipamentos robóticos, e respondem por esterilização e manipulação de instrumentos.
Médicos anestesistas garantem a analgesia segura durante os procedimentos, dosando remédios e monitorando sinais vitais em tempo real.
A docência médica envolve ministrar aulas, supervisionar residentes, orientar TCCs.
A telemedicina, em ascensão, amplia acesso e facilita consultas à distância, exigindo segurança de dados e videoconferência.
Em contextos humanitários, médicos atuam com urgência em cenários de guerra, desastres naturais ou epidemias.
No setor corporativo, médicos ocupam cargos de gestão, compliance ou consultoria em saúde pública.
O ritmo da medicina exige plantões madrugada adentro, disponibilidade para atendimento urgente, e turnos rotativos.
A atualização contínua se dá por congressos, cursos, jornadas e leitura de periódicos.
Responsabilidades éticas envolvem sigilo profissional, consentimento do paciente, decisões sobre fim de vida e conflitos de interesse.
Muitas vezes, é necessária coordenação com vigilância epidemiológica, seguradoras e autoridades sanitárias.
A remuneração varia muito: médicos de plantão, por procedimentos, por sistema público ou conveniado.
A estabilidade em serviço público costuma ser alta, mas a iniciativa privada pode oferecer ganhos superiores.
O médico também pode atuar em pesquisa farmacêutica, desenvolvimento de vacinas, patentes de tecnologia médica.
Ele participa de campanhas de prevenção, organizes programas de saúde escolar, vacinação e controle de endemias.
A medicina preventiva foca em checkups, rastreamento e exames de imagem.
Há também a medicina integrativa: uso de abordagens complementares como acupuntura, nutrição funcional e terapias mente-corpo.
Médicos gestores assumem chefias e direção de hospitais, planejamento estratégico, alocação de recursos e gestão de equipe.
Na área esportiva, medico acompanha atletas, avalia condicionamento físico, lesões e retorna ao esporte.
Em suma, o médico vai do exame clínico simples ao tratamento cirúrgico complexo, com múltiplas variações de rotina.
Seu foco é a saúde humana, impacto social e científico, equilibra emoções, habilidades técnicas e sensibilidade.
A profissão exige empatia, senso de urgência, resiliência, e capacidade de tomada de decisões sob pressão.
É uma carreira das mais abrangentes, com possibilidade de atender desde uma consulta simples até liderar projetos globais de saúde.
Se você busca uma profissão que combine ciência, ajuda ao próximo e constante aprendizado, a medicina oferece esse caminho.''',
            'audio_asset_path': 'assets/audio/medico.mp3',
            'storage_path': 'audios/medico.mp3'
          },
          {
            'filename': 'Advogado.txt',
            'content':
            '''A advocacia é a profissão jurídica responsável por representar clientes em processos judiciais ou extrajudiciais.
Há inúmeras áreas de atuação: trabalhista, cível, penal, tributária, empresarial, previdenciária, ambiental, família e sucessões, consumidor, entre outras.
Cada área exige conhecimentos específicos: por exemplo, o advogado trabalhista precisa dominar a CLT e a jurisprudência sobre relações de emprego; o penal estuda leis penais, direito processual penal, prisão e penas.
Ele pode atuar individualmente, em pequenas bancas ou em grandes escritórios de advocacia.
O ambiente de trabalho varia: escritórios, fóruns, tribunais, delegacias, empresas (como advogado in-house), órgãos públicos e organizações sem fins lucrativos.
Em casos cíveis, o advogado elabora petições iniciais, contestações, recursos, realiza audiências de conciliação e produz provas, como documentos ou testemunhas.
No penal, faz defesa em audiência, sustentações orais, entrevistas com clientes detidos e acompanha diligências.
Em direito empresarial, presta consultoria a empresas, realiza contratos, reorganizações societárias, recuperação judicial e due diligence em fusões.
No ambiental, fiscaliza licenças, ações civis públicas por dano ambiental, e acompanha perícias técnicas.
Ferramentas de trabalho incluem código civil, penal, CLT, softwares jurídicos (Peticiona, SAJ, Legal One), ferramentas de pesquisa jurisprudencial (LexML, JusBrasil, Google), e sistemas de processo eletrônico (PJE, e‑proc).
Atividades “pequenas” do dia a dia incluem responder e‑mails de clientes, atualizar planilhas de prazos, protocolar petições eletrônicas e efetuar pagamento de despesas processuais.
Atividades “grandes” envolvem audiências complexas, sustentação oral em tribunais superiores, elaboração de laudos jurídicos e coordenação de grandes ações coletivas.
Advogados precisam interagir com juízes, promotores, procuradores, peritos, contadores, administradores judiciais, servidores e estagiários.
Também fazem negociação direta ou conduzida em mediação, conciliação ou arbitragem.
O cotidiano exige gestão do tempo para atender prazos processuais, audiências marcadas e atendimento à clientela.
As especializações podem ser formalizadas por meio de pós-graduação (LL.M.), mestrado ou doutorado, e obtenção de certificações da OAB.
O advogado tributarista, por exemplo, atua em planejamento tributário, consultoria em legislação fiscal e contencioso tributário.
Já o advogado previdenciário orienta sobre aposentadorias, benefícios e defende em juízo contra o INSS.
O salário e honorários variam por tipo de atuação: sucesso em causas, honorários advocatícios, contratos fixos, ou atuação pública (magistratura, promotoria, defensoria).
Advogados públicos (estaduais ou federais) podem atuar como procuradores, promotores ou defensores públicos, com estabilidade e remuneração adequada.
Eles elaboram pareceres jurídicos, que são estudos técnicos utilizados para fundamentar decisões de empresas ou órgãos.
No direito de família, lidam com divórcios, guarda, pensão alimentícia, e inventários.
Já no consumidor, defendem clientes em conflitos com empresas, abusos contratuais ou defeitos de produtos.
O advogado também pode atuar como facilitador em cursos, palestras, elaboração de manuais, compliance e auditoria legal.
Ele precisa lidar com pressão – prazos, exigências judiciais, emocional dos clientes.
A rotina inclui leituras contínuas, atualização legislativa e jurisprudencial (diários oficiais).
Advogados criminais podem atuar 24 horas em plantão, especialmente nos casos de flagrante.
Se envolverem em arbitragem, atuam em câmaras privadas, criando petição inicial arbitral e sendo assistente em tribunal arbitral.
Em grandes bancas internacionais, trabalham em fusões e aquisições, IPOs e financiamento estruturado.
Em consultoria corporativa, elaboram políticas internas e termos de compliance anticorrupção.
Também fazem due diligence em transações empresariais e análise de contratos.
Em causas coletivas, tratam da defesa de grupos afetados por dano ambiental, financeiro ou consumidor – mobilizam grande volume de documentação.
Advogados professores ministram aulas em faculdades de direito e orientam estudantes.
Empresarialmente, podem abrir bancos de currículo vertical especializado, gerenciamento de equipe e marketing jurídico digital.
A profissão exige postura ética segundo o Estatuto da OAB, com sigilo profissional, diligência, respeito aos prazos e responsabilidade técnica.
O advogado deve aperfeiioar habilidades de oratória, redação jurídica, argumentação, poder de persuasão e interpretação normativa.
Ele enfrenta concorrência alta, remuneração irregular em escritórios pequenos e necessidade de marketing pessoal.
As inscrições em cadastros jurídicos e a atuação em redes de escritórios facilitam participação em redes de mercado.
Pode haver trabalho em áreas inovadoras como legaltechs, que oferecem automação contratual, inteligência artificial jurídica e consultoria externa.
Em resumo, a advocacia é uma profissão rica em variações técnicas, desafios processuais, interações interdisciplinares e impacto direto na vida e direitos das pessoas.''',
            'audio_asset_path': 'assets/audio/advogado.mp3',
            'storage_path': 'audios/advogado.mp3'
          },
          {
            'filename': 'Motorista Profissional.txt',
            'content':
            '''O motorista profissional é o responsável por conduzir veículos de pequeno, médio ou grande porte para transporte de pessoas, cargas, máquinas ou insumos.
Essa é uma profissão muito ampla, com categorias variadas: motorista de transporte urbano, rodoviário, interestadual, internacional, motorista de aplicativo, de ambulância, de caminhão, de ônibus, de carreta, entre outros.
A habilitação legal depende da categoria exigida pelo veículo: B (automóveis), C (caminhões), D (ônibus), E (carretas e veículos articulados).
Também é comum que o motorista precise de cursos complementares como transporte de cargas perigosas (MOPP), transporte escolar, coletivo de passageiros ou cargas indivisíveis.
As funções diárias vão muito além de apenas dirigir: envolvem planejamento de rotas, verificação das condições do veículo, preenchimento de diários de bordo, emissão de documentos de transporte (CT-e, MDF-e, DANFE).
Um motorista de ônibus deve cumprir itinerários definidos, seguir horários rígidos, zelar pelo conforto e segurança dos passageiros e manter postura cordial.
Já o de transporte de cargas pesadas precisa verificar o carregamento adequado, acompanhar o descarregamento, amarrar corretamente as cargas e respeitar limites de peso e altura.
O motorista de ambulância deve saber conduzir em situações de emergência, respeitando o Código de Trânsito Brasileiro e priorizando o bem-estar do paciente.
Há também motoristas de máquinas pesadas como retroescavadeiras, tratores, rolos compactadores e guindastes, que exigem treinamento específico e atuação em obras, mineração ou agroindústria.
A jornada de trabalho pode ser diurna ou noturna, em regime de turnos, plantões, escalas semanais ou longas viagens interestaduais.
Profissionais que trabalham com transporte interestadual enfrentam dias ou semanas fora de casa, dormindo em cabines, hotéis de estrada ou pontos de apoio para caminhoneiros.
É comum que trabalhem com dispositivos de rastreamento, monitoramento de jornada (via tacógrafo) e aplicativos de transporte e logística.
Em empresas grandes, o motorista atua em conjunto com a equipe de logística, manutenção, segurança do trabalho e operações.
Em transportadoras, o motorista precisa cumprir regras rígidas de tempo de descanso, direção contínua, pontos de parada obrigatória e procedimentos em caso de sinistro.
A profissão exige cuidados constantes com o estado físico e mental, visto que longas jornadas, estresse, sono e más condições de estrada afetam diretamente a segurança.
O motorista autônomo, que possui seu próprio veículo, gerencia sua própria clientela, negocia fretes, lida com burocracia e precisa controlar custos como combustível, pedágio, pneus e manutenção.
Com a digitalização, muitos motoristas utilizam aplicativos de transporte de passageiros (como Uber e 99) ou de frete (FreteBras, TruckPad).
A remuneração varia muito: pode ser fixa (CLT), variável (por quilômetro rodado), ou comissão sobre entregas ou viagens.
O ambiente de trabalho também varia: estradas, rodovias, áreas urbanas, portos, aeroportos, centros de distribuição, obras ou áreas rurais.
O motorista pode ser vinculado a empresas de transporte, companhias de logística, prefeituras, órgãos públicos, cooperativas, ONGs ou ser autônomo.
No caso de motoristas escolares, há exigência de conduta ética, curso especializado e vistoria veicular semestral.
O uso de EPIs (Equipamentos de Proteção Individual), como cintos de segurança, coletes refletivos e rádios comunicadores, pode ser obrigatório dependendo da carga ou tipo de transporte.
No transporte de cargas perigosas (químicos, inflamáveis), o motorista deve seguir normas da ANTT, da ABNT e estar ciente de riscos ambientais e procedimentos de emergência.
Algumas atividades "pequenas" incluem calibragem dos pneus, checagem do óleo, limpeza dos faróis, checagem de documentação e abastecimento.
Atividades "grandes" incluem condução em comboios internacionais, transporte especial com escolta, operações com horário marcado em portos e aeroportos, e manobras em áreas restritas.
A atualização é constante: novas leis de trânsito, exigências ambientais (como o uso de Arla 32 em caminhões), tecnologias embarcadas e apps de gestão.
O motorista de caminhão refrigerado precisa controlar temperatura, cronogramas rígidos e cuidados com produtos perecíveis.
Já o de ônibus de turismo precisa cuidar da experiência do passageiro, oferecer conforto, narrativas locais e respeitar paradas programadas.
Existe também o motorista executivo, que transporta diretores ou autoridades, exige discrição, fluência verbal e postura profissional.
Muitos fazem cursos de direção defensiva, primeiros socorros, mecânica básica e condução econômica.
O desempenho do motorista afeta diretamente os custos logísticos: consumo de combustível, desgaste do veículo e prazos de entrega.
Com a crescente preocupação ambiental, há estímulo à direção sustentável e uso de veículos elétricos ou híbridos.
O motorista pode crescer profissionalmente tornando-se gestor de frota, instrutor de direção, supervisor logístico ou empreendedor no setor.
Há sindicatos representativos da categoria que lutam por direitos, melhores condições de trabalho e regulamentação da profissão.
Em zonas urbanas, os desafios incluem trânsito, violência, multas e zonas de restrição como rodízios ou áreas de emissão controlada.
Já nas zonas rurais, o desafio pode ser a infraestrutura precária, clima e longas distâncias.
É uma profissão que exige paciência, responsabilidade, autocontrole, atenção contínua, habilidades técnicas e boa comunicação.
Motoristas também precisam lidar com fiscalização em rodovias, pontos de controle, balanças e órgãos como PRF e ANTT.
A legislação trabalhista exige anotação da jornada e respeito aos períodos mínimos de descanso, principalmente após a Lei do Motorista (Lei 13.103/2015).
Enfim, o motorista profissional é peça fundamental na mobilidade urbana, na logística nacional e no funcionamento da cadeia produtiva do país.''',
            'audio_asset_path': 'assets/audio/motorista_profissional.mp3',
            'storage_path': 'audios/motorista_profissional.mp3'
          },
          {
            'filename': 'Engenheiro Civil.txt',
            'content':
            '''O engenheiro civil projeta, constrói e gerencia obras de infraestrutura como edifícios, pontes, estradas, barragens e saneamento.
As áreas de especialização incluem estruturas (fundações, lajes, vigas), geotecnia (solo), transportes, hidráulica, saneamento ambiental, estruturas metálicas, e construção sustentável.
Ele elabora projetos executivos com cálculos estruturais, dimensionamento, e especificações de materiais.
Também realiza estudo de viabilidade técnica e econômica, considerando normas ABNT, NBR, e referências técnicas.
Nos canteiros de obras, supervisiona equipes, fiscaliza a execução conforme projeto e resolve problemas práticos como infiltrações, recalques e alinhamentos.
Controla qualidade: ensaios de concreto, solo e aterro, e acompanha controle tecnológico em laboratório.
Gerencia cronograma, orçamento, logística de materiais, equipamentos como guindastes, tratores, caminhões betoneira e retroescavadeiras.
Especifica e acompanha implantação de sistemas de drenagem, redes de água e esgoto, e pavimentações.
No ambiente urbano, encara projetos de mobilidade, calçadas, ciclovias, sinalização viária e acessibilidade (rampas, rampas de pedestre).
Usa ferramentas CAD/BIM (AutoCAD, Revit, Civil 3D), MS Project, Excel, softwares de cálculo estrutural (ProtaStructure, Eberick).
Atividades "pequenas": leitura de plantas, medições in loco, reuniões com fornecedores, verificações de prazos, ajustes de orçamento.
Grandes: gerenciamento de contratos, coordenação de múltiplas frentes (infra, acabamento, elétrica), auditorias de segurança e obras em grande escala.
Atua em escritórios, canteiros, empresas públicas de infraestrutura, consultorias e órgãos governamentais.
Precisa lidar com fiscalização, licenciamento ambiental, aprovação de prefeituras, concessionárias públicas e órgãos reguladores.
Enfrenta desafios como condições climáticas, logística urbana, interfaces com outras disciplinas (elétrica, arquitetura, logística).
Coordena equipes multidisciplinares: arquitetos, eletricistas, encanadores, pedreiros, operadores de máquinas.
O planejamento estruturado envolve estimar quantidades, custos, selecionar fornecedores e definir marcos contratuais.
Gerente de obra integra escopo, prazo, custo, qualidade, e segurança (inclusive PCMAT, NR-18).
Especialistas em construção sustentável projetam com certificações como LEED, certificações de eficiência energética e aproveitamento de água da chuva.
Operação em barragens demanda análise de estabilidade, monitoramento de barragens e sistemas de segurança.
Estradas exigem estudos de tráfego, dimensionamento de pavimentos flexíveis e rígidos, estudos de drenagem superficial e subsuperficial.
Ele precisa atualizar conhecimentos em normas (NBRs) e tecnologias (materiais ecológicos, impressão 3D de concreto).
Participa de inspeções, laudos técnicos, vistorias e perícias judiciais.
Atua também em retrofit e recuperação de estruturas: concreto protendido, reforço com fibra de carbono, contenções.
No setor público pode ocupar cargos de assessoramento, fiscalização, autarquias e secretarias de infraestrutura.
Em engenharia rodoviária, fiscaliza trecho, detecta patologias (trincas, recalques), obras de restauração e pavimentação.
Trabalha com planejamento urbano e projetos de drenagem em regiões de risco e enchentes.
Atua diretamente em obras habitacionais, urbanização, saneamento e infraestrutura de transporte público.
A remuneração varia conforme porte do projeto, setor (privado/público), e complexidade técnica envolvida.
A visão sistêmica da engenharia civil eduza diretamente impacto social, ambiente construído e qualidade de vida.
O engenheiro civil lida com risco: estabilidade, custos, acidentes, logística, gestão humana e técnicas.
A pós-graduação pode incluir áreas como engenharia de segurança, BIM, gestão de projetos (PMP), infraestrutura verde.
Também ensina em universidades, orienta TCC, pesquisa em laboratórios, publica artigos e participa de comitês técnicos.
Encarrega-se de contratos, garantias, prazos e a interface cliente-empreiteiro-arquiteto.
Também atua como consultor técnico para perícias, laudos, serviços de auditoria de obras.
Ele precisa adaptar soluções a condições locais: solo, clima, cultura e legislação urbanística.
Pode expandir atuação internacional, participando em projetos de infraestrutura global, ONGs, ou agências como Banco Mundial.
A engenharia civil é fundamental para desenvolvimento urbano, infraestrutura sustentável e impacta diretamente no cotidiano das pessoas.
Uma carreira ampla: do pequeno muro residencial até o grande lançamento de infraestrutura nacional.
Envolve ciência, gestão, técnica, meio ambiente e atendimento a normas – une teoria e prática em obras de impacto.''',
            'audio_asset_path': 'assets/audio/engenheiro_civil.mp3',
            'storage_path': 'audios/engenheiro_civil.mp3'
          },
          {
            'filename': 'Arquiteto Projetista.txt',
            'content':
            '''O arquiteto projetista é o profissional que idealiza espaços e estruturas, integrando estética, funcionalidade e sustentabilidade nos projetos arquitetônicos.
Atua em diversas frentes: projetos residenciais, comerciais, culturais, urbanos, paisagísticos, restauro e urbanismo.
No processo de trabalho, envolve levantamento de dados, briefing com cliente, estudo do entorno, legislação municipal (zoneamento, gabaritos), e concepção inicial.
Em especializações, destaca-se arquitetura de interiores, acessibilidade, arquitetura verde, BIM, arquitetura hospitalar e corporativa.
Ferramentas utilizadas: AutoCAD, Revit, SketchUp, Lumion, Rhino, ArchiCAD, Photoshop, Illustrator, InDesign e maquetes físicas.
Nas etapas de projeto, prepara anteprojeto, projeto legal (para aprovação em prefeituras), projeto executivo (detalhamento completo), detalhe construtivo e compatibilização com engenharias.
“Atividades pequenas” incluem desenho de planta baixa, esquadrias, elevações e cortes, detalhamento de materiais e contato com fornecedores.
“Atividades grandes” envolvem coordenação de projetos multi disciplinares, reuniões com engenharia, acompanhamento até a execução da obra e recebimento técnico.
Office: atua em escritórios de arquitetura, incorporação, departamentos de design, prefeituras, institutos públicos e ONGs dedicadas à habitação.
Para obras de grande porte, supervisiona compatibilização entre arquitetura, estrutura, elétrica, hidráulica e HVAC.
Também pode trabalhar em projetos sustentáveis: coleta de água de chuva, eficiência energética, certificações como LEED ou AQUA.
Em licitações públicas, o arquiteto prepara projetos para concorrências, elabora memória de cálculo, planilhas orçamentárias e estudos técnicos.
Deve estar atento às normas da ABNT, NBR 9050 (acessibilidade), NBR 15575 (habitabilidade), além do Código de Obras e edificações local.
Em estudos urbanísticos, avalia impacto viário, densidade urbana, mobilidade, arborização e conforto ambiental.
A interação com engenheiros civis, estruturais, elétricos, paisagistas e construtores é constante durante todo o ciclo do projeto.
Em consultorias, pode atuar em retrofit, revitalização, laudos técnicos e avaliação de imóveis.
Possui rotina criativa (esboços, apresentação ao cliente, painéis visuais), técnica (planilhas, detalhamentos) e executiva (cronogramas, relatórios).
Em escritórios menores, acumula múltiplas funções: projeto, orçamento, obra, apresentação e atendimento ao cliente.
Em equipes grandes, há divisão de responsabilidade: estagiários, arquitetos de projeto e gestores de obra.
A comunicação visual do projeto é importante: pranchas, renderings 3D, vídeos e maquetes participativas.
O uso de BIM permite gerenciamento de informações, quantitativos automáticos, cronograma e custo integrados.
Projetos residenciais envolvem layout funcional, ergonomia, conforto térmico e acústico, além de estética interior.
Projetos comerciais exigem fluxo de pessoas, circulação eficiente, acessibilidade, iluminação adequada e imagem corporativa.
Projetos públicos demandam normas específicas, licitações, estudos de viabilidade e relação com entidades governamentais.
O arquiteto ainda pode atuar em design de mobiliário, cenografia, direção de arte, planejamento urbano ou campus universitário.
Participa de seminários, congressos, cursos de tendências, e mantém atualização em normas e tecnologia.
O profissional autônomo deve cuidar da gestão do escritório: marketing, negociação, compliance, contratos e contabilidade.
A remuneração varia conforme formato de contratação: por projeto, por hora, CLT, percentuais de obra ou licitação.
Há ativos importantes: portfóflio, certificações, credenciamento para obras públicas e feedback de clientes.
Os desafios incluem atender expectativas estéticas e funcionais, prazos, limitação orçamentária, processo licitatório e burocracia municipal.
Em obra, acompanha cronograma, medições, aprovação de materiais, solução de incompatibilidades e fiscalização técnica.
O arquiteto também pode se especializar em arquitetura hospitalar, com entendimento de fluxos de pacientes, esterilização, segurança, vigilância sanitária e normas técnicas rígidas.
Em projetos sustentáveis, integra alternativas de ventilação natural, painéis solares, jardins internos e reúso de água.
Pode atuar em pesquisa acadêmica, docência, publicações especializadas e produção de conteúdo técnico.
Tem ainda a possibilidade de internacionalizar carreira em escritórios no exterior ou exportação de serviços de arquitetura.
O arquiteto projetista atua em todas as fases: concepção, projeto legal e executivo, compatibilização, obra e pós-obra.
A carreira requer visão espacial, criatividade, conhecimento técnico, capacidade de negociação e gestão.
O impacto dessa profissão está na forma como as pessoas vivem, trabalham e experimentam os ambientes construídos.
Contribui diretamente para o desenvolvimento urbano, sustentabilidade, qualidade de vida e identidade arquitetônica.
Para quem busca combinar arte, técnica, gestão e impacto social, a arquitetura projetista é uma profissão multifacetada e significativa.''',
            'audio_asset_path': 'assets/audio/arquiteto_projetista.mp3',
            'storage_path': 'audios/arquiteto_projetista.mp3'
          },
          {
            'filename': 'Economista.txt',
            'content':
            '''O economista é o profissional que estuda, analisa e projeta o comportamento da economia de empresas, setores, países ou mercados específicos.
Pode atuar em áreas diversas: macroeconomia, microeconomia, economia internacional, desenvolvimento econômico, finanças públicas, econometria e economia comportamental.
Atua em instituições como bancos centrais, bancos comerciais, consultorias, empresas, ministérios, órgãos de planejamento (como IBGE, IPEA), ONGs, escolas e universidades.
Entre suas funções estão: coleta e análise de indicadores econômicos (PIB, inflação, desemprego), construção de modelos econométricos, elaboração de estudos de viabilidade e cenários futuros.
No campo privado, pode trabalhar como analista financeiro, consultor de investimentos, gestor de fundos, assessor econômico ou economista-chefe de instituição financeira.
No setor público, participa na formulação de políticas públicas, análise de orçamentos, controle financeiro, planejamento urbano e tributário.
O economista pode ser pesquisador, docente, consultor, empreendedor, agente regulador ou analista de riscos.
Ferramentas do dia a dia incluem softwares de estatística e econometria (R, Stata, EViews, Python, MATLAB), planilhas, bancos de dados econômicos (PNAD, FGV, Trading Economics) e programação para análise de grande volume de dados.
“Atividades pequenas” envolvem coleta de dados, atualização de dashboards, elaboração de slides com gráficos e revisão de literatura científica.
“Atividades grandes” envolvem modelagem macroeconômica, construção de cenários de crise, negociação de políticas públicas, ou condução de pesquisas acadêmicas de impacto.
Atua em comitês de política econômica, elaboração de relatórios para investidores, análise de risco-soberano e aconselhamento de governos.
Pode integrar equipes de precificação, planejamento estratégico de empresas, consultoria tributária ou regulação econômica em agências como ANP, ANEEL ou ANATEL.
Cerca de ênfase em mensuração de variáveis macro, condução de pesquisa aplicada, avaliação de projetos de infraestrutura e estudos de impacto social.
O mercado financeiro exige domínio de finanças quantitativas, derivativos, variações cambiais, gestão de carteiras, avaliação de ativos e ciclos econômicos.
O economista de mercados de capitais monitora ações, títulos, commodities, câmbio e determina estratégias de investimento.
Em cenários econômicos, utiliza previsões, cenários otimistas/pessimistas, testes de robustez, back tests, simulação de Monte Carlo e séries temporais.
O economista também pode atuar no direito econômico, concorrência, fusões e aquisições, compliance e políticas antitruste.
Em agências reguladoras, analisa tarifas, regulação de mercados, equilíbrio econômico-financeiro e negocia com empresas e governo.
Desenvolve estudos de custo-benefício, eficiência, produtividade, pobreza, desigualdade, tributação e impactos de políticas públicas.
Consciente dos desafios sociais, atua em planejamento urbano, habitação social e sustentabilidade econômica.
Precisa de forte embasamento matemático, estatístico e analítico, além de habilidades de comunicação para transmissão de dados para não-especialistas.
Atua em conferências, publica artigos, escreve reports econômicos, e participa de think tanks.
O economista em startups lida com análise de viabilidade, pricing, métricas de crescimento, churn, CAC e LTV.
Em ONGs ou organismos multilaterais (Banco Mundial, ONU), contribui em pesquisas sobre desenvolvimento, pobreza, desigualdade e mudanças climáticas.
Sua rotina envolve leitura diária de jornais econômicos, boletins de mercado, noticiários internacionais e atualização legislativa.
Ferramentas para visualization incluem Power BI, Tableau, Qlik e Excel avançado para dashboards interativos.
Em períodos eleitorais, atua na projeção de impactos de novas políticas, análise de cenários eleitorais e estudos de mercado para setores produtivos.
O economista também pode lecionar em universidades, coordenar cursos de pós-graduação ou MBA e orientar dissertações.
Certificações adicionais como CQE, CFA, CFP, FMVA aumentam empregabilidade em mercado financeiro.
Desafios incluem pressão por previsões, incompletude de dados, ciclos econômicos voláteis, políticas monetárias e guerra comercial.
A remuneração varia muito de acordo com setor: público, privado, mercado financeiro ou consultoria.
As habilidades mais valorizadas são análise crítica, programação, comunicação clara e capacidade de resolver problemas complexos.
O economista pode ascender a posições de liderança: diretor financeiro, consultor sênior, coordenador de planejamento, chefe de departamento e professor titular.
Também atua em inovação econômica, fintechs, inteligência de dados, economia circular e consultoria ambiental.
A contribuição social da profissão se dá na construção de políticas justas, eficiência na alocação de recursos públicos e no impulso à estabilidade econômica.
A economia aplicada está presente em qualquer decisão coletiva ou empresarial: decisões de investimento, cobrança de impostos, política salarial.
A ética profissional exige transparência, imparcialidade, rigor na coleta e interpretação de dados.
Há associações profissionais, como a ANPEC, que promovem debates, conferências e formação contínua.
A profissão se renova com big data, machine learning, blockchain, criptomoedas e análise preditiva.
Em resumo, o economista combina ciência, matemática, política, finanças e estratégia para compreender e impactar a realidade econômica de sociedades.''',
            'audio_asset_path': 'assets/audio/economista.mp3',
            'storage_path': 'audios/economista.mp3'
          },
          {
            'filename': 'Jornalista.txt',
            'content':
            '''O jornalista é responsável por investigar, apurar, produzir e divulgar informações de interesse público, atuando em veículos como jornais, revistas, TV, rádio, portais e mídias digitais.
As especializações incluem jornalismo político, econômico, esportivo, cultural, de dados, audiovisual, investigativo, científico, ambiental e comunitário.
Pode exercer funções como repórter, editor, produtor de conteúdo, apresentador, comentarista, fotojornalista ou correspondente internacional.
O local de trabalho varia: redações, estúdios, emissoras, agências de notícias, editoras, assessorias de imprensa, organizações não governamentais e portais on-line.
Repórter de campo faz entrevistas, cobertura de eventos, coletas de dados, conferência de informações e produção de pautas, filmagens, gravações via celular ou equipamento profissional.
Editor-chefe coordena equipe, realiza revisão de textos, define pauta e aprova peças jornalísticas.
Jornalismo investigativo demanda fontes, análise de documentos, verificação de dados, confidencialidade e eventual publicação de reportagens que podem gerar impacto político ou social.
O fotojornalista utiliza câmeras profissionais, lentes diversas, tripés e conhecimentos de composição, iluminação e edição.
No jornalismo de dados, analisa grandes bases, trabalha com Excel, R, Python, Tableau, Power BI, GIS para encontrar padrões e criar visualizações acessíveis.
O jornalista digital trabalha com SEO, redes sociais, métricas digitais, interatividade, vídeos, podcasts e formatos multimídia.
“Atividades pequenas” incluem redação diária, checagem de fontes, contato com assessores, publicação em redes sociais, busca de autorização para uso de imagem.
“Atividades grandes” envolvem investigação, reportagens especiais, documentários, transmissões ao vivo, textos long-form e organização de eventos jornalísticos.
Trabalha em equipe com editores, designers, marketeiros, videomakers, desenvolvedores web, fotógrafos, produtores de conteúdo e secretariado.
Utiliza softwares de edição de texto (Word, Google Docs), vídeo (Premiere, Final Cut), áudio (Audition, Pro Tools), e sistemas CMS (WordPress, Drupal).
O jornalista deve observar códigos éticos da profissão, verificar imparcialidade, checar rumores, evitar fake news e respeitar a legislação (direito de resposta).
Muitos atuam também como assessor de imprensa, consultor de reputação, ou em relações públicas.
No rádio, atua lendo boletins, fazendo reportagens ao vivo via carro de imprensa ou diretamente da redação. No TV, apresenta, escreve roteiros, participa de gravação.
A profissão exige disponibilidade para trabalhar em feriados, fins de semana, turnos noturnos e cobertura de situações emergenciais como desastres e crises políticas.
No cenário digital, produz vídeos curtos, lives, podcasts, infográficos, e se relaciona diretamente com público e comunidade online.
O jornalista diplomado também pode trabalhar em produção cultural, assessoria de imprensa, organização de seminários e palestras.
É comum que produza newsletters, colunas opinativas, análises econômicas, políticas e temáticas.
A remuneração e estrutura contratual variam: CLT, PJ, freelances, projetos por produção, afiliado digital e monetização em plataformas.
O jornalista repórter internacional lida com entrevistas no exterior, tradução, adaptação cultural, riscos de segurança, credenciais e vistos.
Também pode atuar como fact-checker, verificando fake news; ou community manager, interagindo com leitores nas redes.
Em redações modernas, existe integração com equipe de SEO, growth hacking e designers UX.
O jornalista cultural cobre lançamentos, resenhas, críticas literárias, eventos artísticos.
No esporte, cobre jogos, faz entrevistas, análises táticas, e produz vídeos com melhores momentos.
Pode seguir carreira acadêmica como pesquisador em comunicação, jornalismo midiático, teoria da mídia ou docência.
A profissão exige escrita clara, pensamento crítico, persistência, curiosidade e adaptabilidade.
Os desafios envolvem pressão por prazos, mudança de padrão de consumo de mídia, ataques digitais, fake news e defesa de liberdade de imprensa.
A jornada profissional inclui aprendizado constante: cursos, especializações (MBA em comunicação, jornalismo de dados, jornalismo científico).
Ferramentas como Slack, Trello, Google Analytics, CrowdTangle, Chartbeat e plataformas de monitoramento são rotineiras.
O jornalista digital também precisa dominar técnicas de storytelling, edição de vídeo curto (TikTok, Reels), áudio (spotify, apple podcast).
Os impactos da profissão incluem accountability público, controle social, proteção de direitos, transparência e formação de opinião.
A atuação em ONGs ambientais exige sensibilização comunitária, reportagem de campo, proteção a fontes e estrutura jurídica de apoio.
Produzir conteúdo para empresas e marcas como content marketing ou branded content também é comum.
O trabalho em equipe é essencial: repórter, videomaker, editor, designer e desenvolvedor digital.
Existem entidades como Fenaj, associações regionais, que regulamentam e promovem a categoria.
O(a) profissional deve ser proativo, resiliente, multidisciplinar e preparado para crises e incertezas.
O jornalismo continua sendo pilar da democracia, informação e diálogo social.''',
            'audio_asset_path': 'assets/audio/jornalista.mp3',
            'storage_path': 'audios/jornalista.mp3'
          },
          {
            'filename':
            'Diretor de Empresa, Presidente, Prefeito e Governador.txt',
            'content':
            '''Essas funções — diretor de empresa, presidente (empresa ou país), prefeito e governador — compartilham características relacionadas à liderança, tomada de decisão estratégica, gestão orçamentária, políticas e alto nível de responsabilidade. Embora distintos em escala, propósitos e contextos, tratam de gestão de organizações complexas.
Diretor de Empresa (CEO, CFO, COO, CMO…)
Atua em empresas privadas ou públicas, responsável pela definição de estratégia corporativa, metas financeiras, operacionais e de mercado.
Cada função demanda foco específico:
CEO (Chief Executive Officer): lidera toda organização, articula cultura, lidera conselho, define visão, parcerias estratégicas, sustentabilidade e inovação.
CFO (Chief Financial Officer): cuida de finanças, controle orçamentário, gestão de custos, captação de recursos, relacionamento com bancos, comunicação com investidores e compliance.
COO (Chief Operating Officer): responsável por operações, cadeia de produção, logística, metas de produção, qualidade e fluxo produtivo.
CMO (Chief Marketing Officer): cuida de marca, comunicação, vendas, análise de mercado e estratégia comercial.
Presidente de País
Lidera o Poder Executivo federal, define políticas públicas, orçamento nacional, relações exteriores, e representação internacional.
Coordena ministérios como Saúde, Fazenda, Educação, Justiça, Infraestrutura, entre outros.
Enfrenta temas complexos: economia, segurança, educação, assistência social, meio ambiente e crises nacionais.
Interage com legislativo, tribunais, sociedade civil, mídia e comunidade internacional.
Prefeito
Comanda o município, coordena secretarias municipais: educação, saúde, transporte, urbanismo, segurança, cultura e meio ambiente.
Toma decisões sobre plano diretor, mobilidade urbana, coleta de lixo, pavimentação, zonagem, licitações e atendimento ao cidadão.
Sua estratégia impacta diretamente a qualidade de vida da população local.
Governador
Lidera a administração estadual, com equilibrada atuação entre política federal, municípios e interesses regionais.
Coordena segurança pública (polícia civil/militar), educação estadual, saúde pública, obras rodoviárias, políticas econômicas regionais e recursos naturais.
Envolve articulação política com Legislativo, judiciais, prefeitos e mobilização de emendas parlamentares.
Competências requisitadas
Visão estratégica, liderança, poder de negociação, gestão de equipes multidisciplinares, comunicação, análise de cenário, gestão de crises e pressão política.
Domínio de ferramentas de gestão: ERP, sistemas de licitação pública (ComprasNet), análise financeira, governança, compliance e fiscalização de orçamento.
Atividades pequenas: leitura de relatórios, reuniões setoriais, assinatura de documentos.
Atividades grandes: planejamento estratégico, gestão de crise, megaprojetos (rodovias, mobilidade, saneamento, políticas públicas), comunicação institucional.
Interação com conselhos: fiscais, estratégicos, conselhos municipais, assembleias e conselhos empresariais.
Desafios envolvem equilíbrio político, oposição, gestão orçamentária, resultados mensuráveis, pressão pública, accountability.
Estrutura de suporte
Nos órgãos públicos: secretários, assessorias especiais, procuradorias, controladoria, assessoria de imprensa, gabinete.
Em empresas: conselho de administração, diretoria executiva, comitês de auditoria, marketing, RH, jurídico, tecnologia.
Métricas de desempenho
ROI, lucro, market share (empresarial); IDH, IDEB, PIB municipal/estadual, mortalidade infantil, segurança pública (governo).
Riscos e tributos
Vulnerabilidade a escândalos, crises econômicas, políticas, tecnológicas. Falhas podem afetar reputação, legalidade e continuidade de mandato ou empresa.
Formação profissional
Executivos geralmente têm MBA, mestrado, experiência em negócios, networking, passerelismo corporativo.
Políticos têm formação variada e exigem experiência política, gestão pública ou representatividade social.
Conclusão
Embora distintos em escala, todas essas carreiras envolvem liderança, impacto macroestratégico, gestão multidisciplinar, ética, comunicação e responsabilidade pública.
O desafio central é transformar visão estratégica em resultados concretos, balanceando interesses, recursos e prazos em cenários complexos e dinâmicos.''',
            'audio_asset_path': 'assets/audio/diretor_de_empresa.mp3',
            'storage_path': 'audios/diretor_de_empresa.mp3',
          },
        ];

        // ✅ ERRO 'File' CORRIGIDO (import 'dart:io' foi adicionado no topo)
        for (var item in initialContent) {
          final textFile = File('$appTextsDir/${item['filename']}');
          if (!await textFile.exists()) {
            await textFile.writeAsString(item['content']!);
            developer
                .log("Texto inicial '${item['filename']}' copiado para local.");
          }

          if (item.containsKey('audio_asset_path') &&
              item.containsKey('storage_path')) {
            await _uploadAudioToFirebase(
                item['audio_asset_path']!, item['storage_path']!);
          }
        }

        await prefs.setBool('initialTextsCopiedAndUploaded', true);
        developer
            .log("Textos e áudios iniciais marcados como copiados/uploadados.");
      } catch (e) {
        developer.log("Erro geral ao copiar/uploadar dados iniciais: $e",
            name: 'InitialDataError');
        await prefs.setBool('initialTextsCopiedAndUploaded', false);
      }
    } else {
      developer.log(
          "Textos e áudios iniciais já copiados/uploadados anteriormente.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Textos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Meus Textos Salvos',
            onPressed: () async {
              final String? selectedText = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedTextsPage()),
              );
              if (selectedText != null && selectedText.isNotEmpty) {
                if (mounted) {
                  setState(() {
                    _englishTextController.text = selectedText;
                    _portugueseText = "";
                    _currentSentenceIndex = -1;
                    _ttsState = TtsState.stopped;
                  });
                  _prepareTextsFromState();
                  await _saveState();
                  _translateAndPrepareTexts();
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_ttsState == TtsState.stopped || _ttsState == TtsState.paused)
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInputCard(),
                    const SizedBox(height: 10),
                    _buildControlsCard(),
                    const Divider(height: 30, thickness: 1),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _isTranslating
                ? const Center(child: CircularProgressIndicator())
                : Padding(
              padding: const EdgeInsets.all(16.0),
              child: isLargeScreen
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildTextBox(
                      title: "Inglês (com áudio)",
                      sentences: _englishSentences,
                      scrollController: _englishScrollController,
                      keys: _englishSentenceKeys,
                      borderColor: const Color(0xFF002147),
                      showTitle: !(_ttsState == TtsState.playing),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildTextBox(
                      title: "Português (tradução)",
                      sentences: _portugueseSentences,
                      scrollController: _portugueseScrollController,
                      keys: _portugueseSentenceKeys,
                      borderColor: const Color(0xFF006B3C),
                      showTitle: !(_ttsState == TtsState.playing),
                    ),
                  ),
                ],
              )
                  : Column(
                children: [
                  Expanded(
                    child: _buildTextBox(
                      title: "Inglês (com áudio)",
                      sentences: _englishSentences,
                      scrollController: _englishScrollController,
                      keys: _englishSentenceKeys,
                      borderColor: const Color(0xFF002147),
                      showTitle: !(_ttsState == TtsState.playing),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: _buildTextBox(
                      title: "Português (tradução)",
                      sentences: _portugueseSentences,
                      scrollController: _portugueseScrollController,
                      keys: _portugueseSentenceKeys,
                      borderColor: const Color(0xFF006B3C),
                      showTitle: !(_ttsState == TtsState.playing),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildControls(),
    );
  }

  Widget _buildInputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _englishTextController,
              decoration: InputDecoration(
                labelText: 'Cole o texto aqui (será lido em inglês)',
                border: const OutlineInputBorder(),
                suffixIcon: _englishTextController.text.isNotEmpty &&
                    _ttsState == TtsState.stopped
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _englishTextController.clear();
                      _portugueseText = "";
                      _englishSentences = [];
                      _portugueseSentences = [];
                      _currentSentenceIndex = -1;
                      _saveState();
                    });
                  },
                )
                    : null,
              ),
              maxLines: 3,
              enabled: !_isTranslating && _ttsState == TtsState.stopped,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.translate),
              label: const Text("Traduzir e Preparar"),
              onPressed: _isTranslating || _ttsState != TtsState.stopped
                  ? null
                  : _translateAndPrepareTexts,
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
        child: Column(
          children: [
            // Corrigido para um intervalo de velocidade mais natural
            _buildSliderRow(
                'Velocidade (0.5 — 1.0 — 2.0)', _speechRate, 0.5, 2.0, (value) {
              setState(() => _speechRate = value);
              _saveState();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBox({
    required String title,
    required List<String> sentences,
    required ScrollController scrollController,
    required List<GlobalKey> keys,
    Color borderColor = Colors.grey,
    required bool showTitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle)
          Text(title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 18, color: Colors.black, height: 1.5),
                  children: _buildHighlightableSpans(sentences, keys),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<InlineSpan> _buildHighlightableSpans(
      List<String> sentences, List<GlobalKey> keys) {
    if (keys.length != sentences.length) {
      return [const TextSpan(text: '')];
    }

    final List<InlineSpan> spans = [];
    for (int i = 0; i < sentences.length; i++) {
      final isHighlighted =
          (_ttsState == TtsState.playing || _ttsState == TtsState.paused) &&
              i == _currentSentenceIndex;

      spans.add(
        WidgetSpan(
          child: Container(
            key: keys[i],
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            decoration: BoxDecoration(
              color:
              isHighlighted ? const Color(0xFFA0D8B3) : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              sentences[i],
              style: TextStyle(
                fontSize: 18,
                color: Colors.black87,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
      if (i < sentences.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }
    return spans;
  }

  Widget _buildSliderRow(String label, double value, double min, double max,
      ValueChanged<double> onChanged) {
    String quickLabel;
    if (value < 0.9) {
      quickLabel = 'Devagar';
    } else if (value < 1.5) {
      quickLabel = 'Normal';
    } else {
      quickLabel = 'Rápido';
    }

    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) * 10).round(),
          label: quickLabel,
          onChanged: onChanged,
        ),
        Text(value.toStringAsFixed(1), style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed:
            _ttsState == TtsState.playing || _englishSentences.isEmpty
                ? null
                : _play,
            icon: Icon(
              _ttsState == TtsState.playing
                  ? Icons.play_arrow
                  : Icons.play_arrow,
              color: _ttsState == TtsState.playing ? Colors.grey : Colors.green,
              size: 50,
            ),
          ),
          IconButton(
            onPressed: _ttsState == TtsState.stopped ? null : _pause,
            icon: Icon(
              Icons.pause,
              color:
              _ttsState == TtsState.stopped || _ttsState == TtsState.paused
                  ? Colors.grey
                  : Colors.blue,
              size: 50,
            ),
          ),
          IconButton(
            onPressed: _ttsState == TtsState.stopped ? null : _stop,
            icon: Icon(
              Icons.stop,
              color: _ttsState == TtsState.stopped ? Colors.grey : Colors.red,
              size: 50,
            ),
          ),
        ],
      ),
    );
  }
}