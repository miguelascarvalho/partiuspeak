//
// PÁGINA CORRIGIDA: lib/pages/saved_texts_page.dart
// (Imports duplicados removidos)
//
import 'package:flutter/material.dart';
import 'dart:io'; // Para File, Directory
import 'package:path_provider/path_provider.dart'; // Para getApplicationDocumentsDirectory
import 'package:intl/intl.dart'; // Para DateFormat

class SavedTextFile {
  final String path;
  final String name;
  final DateTime modifiedDate;

  SavedTextFile({
    required this.path,
    required this.name,
    required this.modifiedDate,
  });
}

class SavedTextsPage extends StatefulWidget {
  const SavedTextsPage({super.key});

  @override
  State<SavedTextsPage> createState() => _SavedTextsPageState();
}

class _SavedTextsPageState extends State<SavedTextsPage> {
  List<SavedTextFile> _textFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTextFiles();
  }

  Future<String> _getAppTextsDirectoryPath() async {
    // ✅ Diretório seguro e permanente no iOS/macOS
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/meus_textos_salvos';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return path;
  }

  Future<void> _loadTextFiles() async {
    setState(() => _isLoading = true);
    try {
      final dirPath = await _getAppTextsDirectoryPath();
      final dir = Directory(dirPath);
      final files = dir
          .listSync()
          .where((f) => f.path.toLowerCase().endsWith('.txt'))
          .map((f) => SavedTextFile(
                path: f.path,
                name: f.uri.pathSegments.last,
                modifiedDate: File(f.path).lastModifiedSync(),
              ))
          .toList()
        ..sort((a, b) => b.modifiedDate.compareTo(a.modifiedDate));

      setState(() => _textFiles = files);
    } catch (e) {
      _showSnackBar("Erro ao carregar arquivos: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      await _loadTextFiles();
      _showSnackBar("Arquivo excluído com sucesso.", success: true);
    } catch (e) {
      _showSnackBar("Erro ao excluir: $e");
    }
  }

  Future<void> _saveTextToFile(String fileName, String content) async {
    try {
      final dirPath = await _getAppTextsDirectoryPath();
      final file = File('$dirPath/$fileName');

      if (await file.exists()) {
        final overwrite = await _confirmDialog(
          title: "Sobrescrever arquivo?",
          message: 'Já existe um arquivo chamado "$fileName". Deseja sobrescrever?',
          confirmText: "Sobrescrever",
          confirmColor: Colors.orange,
        );
        if (overwrite != true) return;
      }

      await file.writeAsString(content);
      await _loadTextFiles();
      _showSnackBar("Texto salvo com sucesso!", success: true);
    } catch (e) {
      _showSnackBar("Erro ao salvar: $e");
    }
  }

  Future<bool?> _confirmDialog({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = Colors.teal,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSaveTextDialog() {
    final nameController = TextEditingController();
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Salvar Novo Texto"),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do arquivo',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite um nome válido.';
                    }
                    if (value.contains(RegExp(r'[\\/:*?"<>|]'))) {
                      return 'Nome contém caracteres inválidos.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: textController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Conteúdo do texto',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Digite algum texto.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                // O 'mounted' check aqui é a forma correta de lidar com o warning
                if (!mounted) return; 
                Navigator.pop(ctx); // Fecha o dialog ANTES do await
                await _saveTextToFile(
                  '${nameController.text.trim()}.txt',
                  textController.text,
                );
              }
            },
            child: const Text("Salvar"),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDialog(String path, String name) async {
    final confirm = await _confirmDialog(
      title: "Excluir Arquivo",
      message: 'Tem certeza que deseja excluir "$name"?',
      confirmText: "Excluir",
      confirmColor: Colors.red,
    );
    if (confirm == true) await _deleteFile(path);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ O 'DateFormat' agora é reconhecido por causa do import corrigido
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Meus Textos Salvos"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTextFiles,
            tooltip: "Atualizar lista",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _textFiles.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Nenhum texto salvo ainda.\nToque em "Novo texto" para adicionar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _textFiles.length,
                  itemBuilder: (context, index) {
                    final file = _textFiles[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0.5,
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined,
                            color: Colors.teal, size: 30),
                        title: Text(
                          file.name.replaceAll('.txt', ''),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Modificado em: ${dateFormat.format(file.modifiedDate)}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () async {
                          final content = await File(file.path).readAsString();
                          // O 'mounted' check aqui é a forma correta
                          if (!mounted) return;
                          Navigator.pop(context, content);
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever,
                              color: Colors.redAccent),
                          onPressed: () =>
                              _confirmDeleteDialog(file.path, file.name),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSaveTextDialog,
        label: const Text("Novo texto"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.teal,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}