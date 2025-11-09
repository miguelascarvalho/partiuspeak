import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:partiuspeak/services/purchase_service.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final purchaseService = Provider.of<PurchaseService?>(context, listen: false);
      purchaseService?.loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final purchaseService = Provider.of<PurchaseService?>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('✨ Seja Premium ✨'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF654ea3), Color(0xFFeaafc8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Desbloqueie Acesso Total',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFeature('📚', 'Todas as lições liberadas'),
                _buildFeature('🚫', 'Sem anúncios'),
                _buildFeature('🚀', 'Conteúdo exclusivo'),
                const SizedBox(height: 40),

                if (purchaseService?.loading == true)
                  const CircularProgressIndicator(color: Colors.white)
                else if (purchaseService?.products.isEmpty ?? true)
                  const Text(
                    'Nenhum plano disponível.\nVerifique sua conexão.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  )
                else
                  ...purchaseService!.products.map(
                    (dynamic product) =>
                        _buildProductTile(product, purchaseService),
                  ),

                const SizedBox(height: 20),
                TextButton(
                  onPressed: purchaseService?.restorePurchases,
                  child: const Text(
                    'Restaurar Compras',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(fontSize: 18, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildProductTile(dynamic product, PurchaseService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        onPressed: () => service.buyProduct(product),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                product.title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              product.price,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
