import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

import 'package:partiuspeak/screens/premium_page.dart';
import 'package:partiuspeak/services/purchase_service.dart';
import 'package:partiuspeak/pages/profile_page.dart';
import 'package:partiuspeak/pages/meus_textos.dart';
import 'package:partiuspeak/licoes/lesson_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic> _modulos = {};

  @override
  void initState() {
    super.initState();
    _carregarJson();
  }

  Future<void> _carregarJson() async {
    final String jsonString =
        await rootBundle.loadString('assets/data/module_metadata.json');
    final Map<String, dynamic> dados = json.decode(jsonString);
    if (mounted) {
      setState(() => _modulos = dados);
    }
  }

  @override
  Widget build(BuildContext context) {
    final purchaseService = Provider.of<PurchaseService>(context);
    final bool isPremium = purchaseService.isSubscribed;

    if (_modulos.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFA5D6A7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFA5D6A7),
        elevation: 0,
        actions: [
          if (isPremium)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Chip(
                label: Text(
                  'PREMIUM',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.amber,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.indigo),
            tooltip: 'Perfil e Configurações',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40.0),
                child: Image.asset(
                  'assets/images/imag.png',
                  width: 310,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),

              // 🔸 Botão Premium (abre sempre a tela local)
              if (!isPremium)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildButton(
                    context,
                    '✨ Seja Premium ✨',
                    Colors.amber.shade700,
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const PremiumPage()),
                      );
                    },
                  ),
                ),

              // 🔸 Botões dos módulos
              _buildModuloButton(
                  'Módulo Zero', Colors.indigo, 'modulo_zero', isPremium),
              _buildModuloButton(
                  'Iniciante', Colors.red, 'iniciante', isPremium),
              _buildModuloButton('Intermediário', const Color(0xFFFF6A00),
                  'intermediario', isPremium),
              _buildModuloButton(
                  'Avançado', Colors.purple, 'avancado', isPremium),

              const SizedBox(height: 18),

              // 🔸 Meus Textos (sempre disponível)
              _buildButton(
                context,
                'Meus Textos',
                const Color(0xFF009688),
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MeusTextosPage()),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModuloButton(
      String text, Color color, String nomeModulo, bool isPremium) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _buildButton(context, text, color, () {
        final licoes = _modulos[nomeModulo] as Map<String, dynamic>? ?? {};
        if (licoes.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LessonListPage(
                nomeModulo: text,
                licoes: licoes,
                isPremium: isPremium,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nenhuma lição encontrada para $text')),
          );
        }
      }),
    );
  }

  Widget _buildButton(
      BuildContext context, String text, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: color,
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
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFamily: 'Montserrat',
            ),
          ),
        ),
      ),
    );
  }
}
