import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart'; // Removido (duplicado)


import 'package:partiuspeak/home_page.dart';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // 🔹 Cria documento no Firestore
  Future<void> _criarUsuarioFirestore(User user) async {
    final doc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final snapshot = await doc.get();

    if (!snapshot.exists) {
      await doc.set({
        'email': user.email,
        'role': 'free',
        'subscription': {
          'active': false,
          'source': 'apple',
          'updatedAt': DateTime.now().toIso8601String(),
        },
      });
      debugPrint("🍎 Novo usuário criado no Firestore: ${user.email}");
    }
  }

  // 🔹 Cadastro normal (e-mail e senha)
  Future<void> _signUp() async {
    if (_passwordController.text.trim() != _confirmPasswordController.text.trim()) {
      _showSnackBar('As senhas não coincidem.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await _criarUsuarioFirestore(credential.user!);

      _showSnackBar('Cadastro realizado com sucesso!', Colors.green);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'weak-password':
          msg = 'A senha fornecida é muito fraca.';
          break;
        case 'email-already-in-use':
          msg = 'Já existe uma conta para este e-mail.';
          break;
        case 'invalid-email':
          msg = 'E-mail inválido.';
          break;
        default:
          msg = 'Erro ao cadastrar: ${e.message}';
      }
      _showSnackBar(msg, Colors.red);
    } catch (e) {
      _showSnackBar('Erro inesperado: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🍎 Login/Cadastro com Apple
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      // Gera um nonce aleatório para segurança
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      await _criarUsuarioFirestore(userCredential.user!);

      _showSnackBar('Login com Apple realizado com sucesso!', Colors.green);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      debugPrint("Erro Apple Sign-In: $e");
      _showSnackBar('Erro ao entrar com Apple.', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔐 Helpers Apple Sign-In
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _showSnackBar(String msg, Color color) {
    if (!mounted) return; // Adicionado 'if (!mounted)'
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA5D6A7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/imag.png', width: 250, height: 150),
              const SizedBox(height: 20),
              const Text(
                'Crie sua conta',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
              ),
              const SizedBox(height: 30),

              // Campos normais de cadastro
              _buildTextField(_emailController, 'E-mail', Icons.email),
              const SizedBox(height: 20),
              _buildTextField(_passwordController, 'Senha', Icons.lock, obscure: true),
              const SizedBox(height: 20),
              _buildTextField(_confirmPasswordController, 'Confirmar Senha', Icons.lock_reset, obscure: true),
              const SizedBox(height: 30),

              // Botão principal
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : ElevatedButton(
                      onPressed: _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      ),
                      child: const Text(
                        'Cadastrar',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
              const SizedBox(height: 20),

              // 🍎 Botão Apple Sign-In
              SignInWithAppleButton(
                onPressed: _signInWithApple,
                style: SignInWithAppleButtonStyle.black,
              ),

              const SizedBox(height: 30),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Já tem uma conta? Faça login!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, IconData icon, {bool obscure = false}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withAlpha(51),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        labelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white54),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}