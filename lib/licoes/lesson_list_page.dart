// Imports do Flutter e pacotes externos
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Imports internos do app e das páginas de lição
import '../screens/premium_page.dart';
import 'lesson_page_modulo_zero.dart'; // ✅ Importado diretamente
import 'lesson_page_modulo_outros.dart'; // ✅ Importado diretamente

class LessonListPage extends StatefulWidget {
  final String nomeModulo;
  final Map<String, dynamic> licoes;
  final bool isPremium;

  const LessonListPage({
    super.key,
    required this.nomeModulo,
    required this.licoes,
    required this.isPremium,
  });

  @override
  State<LessonListPage> createState() => _LessonListPageState();
}

class _LessonListPageState extends State<LessonListPage> {
  Set<String> _completedLessons = {};

  // 🔑 Limite de lições gratuitas por módulo
  static const Map<String, int> _lessonDemoLimits = {
    'Módulo Zero': 6,
    'Iniciante': 10,
    'Intermediário': 6,
    'Avançado': 5,
  };

  @override
  void initState() {
    super.initState();
    _loadCompletionStatus();
  }

  Future<void> _loadCompletionStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'completed_module_${widget.nomeModulo}';
    setState(() {
      _completedLessons = (prefs.getStringList(key) ?? []).toSet();
    });
  }

  Future<void> _toggleCompletion(String lessonJsonPath) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'completed_module_${widget.nomeModulo}';
    setState(() {
      if (_completedLessons.contains(lessonJsonPath)) {
        _completedLessons.remove(lessonJsonPath);
      } else {
        _completedLessons.add(lessonJsonPath);
      }
    });
    await prefs.setStringList(key, _completedLessons.toList());
  }

  @override
  Widget build(BuildContext context) {
    final bool isPremiumUser = widget.isPremium;
    final int demoLimit = _lessonDemoLimits[widget.nomeModulo] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nomeModulo.toUpperCase()),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        itemCount: widget.licoes.entries.length,
        itemBuilder: (context, index) {
          final entry = widget.licoes.entries.elementAt(index);
          final value = entry.value as Map<String, dynamic>;
          final String lessonTitle = value['nome'] ?? 'Sem nome';
          final String lessonJsonPath = value['jsonPath'] ?? '';
          final bool isCompleted = _completedLessons.contains(lessonJsonPath);

          // NOVO: Tratamento do parâmetro 'range' (com verificação de tipo)
          final List<dynamic>? rawRange = value['range'] as List<dynamic>?;
          final List<int>? lessonRange = rawRange?.cast<int>().toList();

          final bool isDemoLesson = index < demoLimit;
          final bool podeAcessar = isPremiumUser || isDemoLesson;

          final Color tileColor = podeAcessar
              ? (isCompleted ? Colors.grey.shade600 : Colors.indigo.shade400)
              : Colors.grey.shade800;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 24, right: 12),
                title: Text(
                  lessonTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                trailing: podeAcessar
                    ? IconButton(
                  icon: Icon(
                    isCompleted
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: Colors.white,
                  ),
                  onPressed: () => _toggleCompletion(lessonJsonPath),
                )
                    : const Icon(Icons.lock, color: Colors.amber),
                onTap: () async {
                  if (podeAcessar) {
                    // 🚨 CORREÇÃO APLICADA AQUI: Adiciona verificação do caminho do JSON
                    if (lessonJsonPath.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Erro ao iniciar lição: Caminho do JSON está vazio. Verifique a estrutura 'licoes'."),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return; // Impede a navegação se o caminho for inválido
                    }

                    if (widget.nomeModulo == 'Módulo Zero') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonPageModuloZero(
                            // ✅ Nomes de classe diretos
                            title: lessonTitle,
                            jsonPath: lessonJsonPath,
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonPageModuloOutros(
                            // ✅ Nomes de classe diretos
                            title: lessonTitle,
                            jsonPath: lessonJsonPath,
                            range: lessonRange, // Passando o range corrigido
                          ),
                        ),
                      );
                    }
                  } else {
                    // 🔒 Usuário não premium tentando acessar lição bloqueada
                    _mostrarDialogPremium(context);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ Popup quando o usuário tenta abrir uma lição bloqueada
  Future<void> _mostrarDialogPremium(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          "Recurso Premium",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Esta lição faz parte do conteúdo Premium.\nAssine o PartiuSpeak Premium para desbloquear todas as lições.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fechar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumPage()),
              );
            },
            child: const Text("Assinar"),
          ),
        ],
      ),
    );
  }
}