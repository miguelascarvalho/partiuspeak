import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:partiuspeak/home_page.dart';
import 'package:partiuspeak/pages/cadastro_page.dart';
import 'package:partiuspeak/pages/forgot_password_page.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((User? user) {
      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    });
  }

  Future<void> _criarUsuarioFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      await docRef.set({
        'email': user.email,
        'role': 'free',
        'subscription': {
          'active': false,
          'source': null,
          // ✅ CORREÇÃO APLICADA AQUI
          'updatedAt': DateTime.now().toIso8601String(),
        },
      });
      debugPrint('👤 Novo usuário criado no Firestore: ${user.email}');
    } else {
      debugPrint('📄 Usuário já existe: ${user.email}');
    }
  }

  Future<void> _signInWithEmail() async {
    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _criarUsuarioFirestore();
      _showSnackBar('Login realizado com sucesso!', Colors.green);
    } on FirebaseAuthException catch (e) {
      String message = switch (e.code) {
        'user-not-found' => 'Nenhum usuário encontrado para este e-mail.',
        'wrong-password' => 'Senha incorreta.',
        'invalid-email' => 'E-mail inválido.',
        _ => 'Erro ao fazer login: ${e.message}',
      };
      _showSnackBar(message, Colors.red);
    } catch (e) {
      _showSnackBar('Erro inesperado: ${e.toString()}', Colors.red);
    } finally {
      // ✅ CORREÇÃO (if mounted) APLICADA AQUI
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔹 Login com Apple (iOS/macOS)
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(oauthCredential);

      // Se for novo usuário, cria doc no Firestore
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await _criarUsuarioFirestore();
      }

      _showSnackBar('Login com Apple realizado com sucesso!', Colors.green);
    } on FirebaseAuthException catch (e) {
      _showSnackBar('Erro no login com Apple: ${e.message}', Colors.red);
    } catch (e) {
      debugPrint("Erro geral no Apple Sign-In: $e");
      _showSnackBar('Erro inesperado com Apple', Colors.red);
    } finally {
      // ✅ CORREÇÃO (if mounted) APLICADA AQUI
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[400],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : _buildLoginForm(),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 40.0),
          child: Image.asset(
            'assets/images/imag.png',
            width: 250,
            height: 150,
            fit: BoxFit.contain,
          ),
        ),
        const Text(
          'Bem-vindo ao Partiu Speak!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontFamily: 'Montserrat',
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        _buildTextField(_emailController, 'E-mail',
            hint: 'seuemail@exemplo.com',
            icon: Icons.email,
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 20),
        _buildTextField(_passwordController, 'Senha',
            hint: 'Sua senha', icon: Icons.lock, obscure: true),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const ForgotPasswordPage()),
            ),
            child: const Text(
              'Esqueceu a senha?',
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: _signInWithEmail,
          style: _buttonStyle(Colors.indigo),
          child: const Text('Entrar',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
        const SizedBox(height: 15),
        // 🔹 Botão Apple (só aparece em iOS)
        if (Theme.of(context).platform == TargetPlatform.iOS)
          ElevatedButton.icon(
            onPressed: _signInWithApple,
            icon: const Icon(Icons.apple, color: Colors.black),
            label: const Text('Continuar com Apple',
                style: TextStyle(fontSize: 18, color: Colors.black)),
            style: _buttonStyle(Colors.white,
                border: BorderSide(color: Colors.grey[300]!)),
          ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CadastroPage()),
          ),
          child: const Text(
            'Não tem uma conta? Cadastre-se!',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {required IconData icon,
        String? hint,
        bool obscure = false,
        TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: _inputDecoration(label, icon: icon, hint: hint),
      style: const TextStyle(color: Colors.black),
    );
  }

  InputDecoration _inputDecoration(String label,
      {required IconData icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.black54),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30.0),
        borderSide: BorderSide.none,
      ),
      labelStyle: const TextStyle(color: Colors.black87),
      hintStyle: const TextStyle(color: Colors.black54),
    );
  }

  ButtonStyle _buttonStyle(Color color, {BorderSide? border}) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30.0),
        side: border ?? BorderSide.none,
      ),
      padding: const EdgeInsets.symmetric(vertical: 15),
      minimumSize: const Size(double.infinity, 50),
    );
  }
}