import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:partiuspeak/pages/login_page.dart'; // Ajuste o caminho se necessário

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao sair: $e')),
        );
      }
      debugPrint("Erro ao fazer sign out: $e");
    }
  }

  // Função para exclusão de conta (adicionada anteriormente)
  Future<void> _deleteUserAccount() async {
    // Implemente a lógica de confirmação aqui antes de chamar user.delete()
    // Por exemplo, um AlertDialog
    final bool confirmDelete = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir Conta'),
            content: const Text(
                'Tem certeza que deseja excluir sua conta? Esta ação é irreversível.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child:
                    const Text('Excluir', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmDelete) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Sua conta foi excluída com sucesso.')),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'requires-recent-login') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Por segurança, por favor faça login novamente antes de excluir sua conta.')),
          );
          // Opcional: Redirecionar para login para reautenticar
          _signOut();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao excluir conta: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro inesperado: $e')),
        );
      }
      debugPrint("Erro ao fazer sign out: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        // ✅ ADICIONADO: Para permitir rolagem e espaçamento
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.teal,
                child: Icon(Icons.person, size: 70, color: Colors.white),
              ),
            ),
            const SizedBox(height: 30),
            Center(
              child: Text(
                currentUser?.displayName ?? 'Usuário',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                currentUser?.email ?? 'E-mail não disponível',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ),
            const Divider(height: 40, thickness: 1),
            // Outras informações ou botões podem vir aqui
            // ...

            const SizedBox(height: 40), // Espaço antes dos botões de ação

            // Botão Sair
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text(
                  'Sair da Conta',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15), // Espaço entre os botões

            // Botão Excluir Conta
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _deleteUserAccount,
                icon: const Icon(Icons.delete_forever, color: Colors.white),
                label: const Text(
                  'Excluir Minha Conta',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
            ),
            const SizedBox(
                height: 30), // ✅ ADICIONADO: Espaço no final da página
          ],
        ),
      ),
    );
  }
}
