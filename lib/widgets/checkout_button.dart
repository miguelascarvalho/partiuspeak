import 'package:flutter/material.dart';
import 'package:partiuspeak/screens/premium_page.dart';

class CheckoutButton extends StatelessWidget {
  const CheckoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.star),
      label: const Text(
        'Assinar Premium',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        // ✅ Agora abre a tela Premium local (In-App Purchase nativo)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PremiumPage()),
        );
      },
    );
  }
}
