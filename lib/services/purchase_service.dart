import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PurchaseService extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  bool available = false;
  bool loading = false;

  List<ProductDetails> products = [];
  List<PurchaseDetails> purchases = [];
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _subscriptionActive = false;

  static const Set<String> productIds = {
    'assinatura_premium_mensal', // substitua se o ID da App Store for outro
  };

  PurchaseService() {
    _initialize();
  }

  Future<void> _initialize() async {
    available = await _iap.isAvailable();
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (e) => debugPrint('Erro no purchaseStream: $e'),
    );

    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint("Erro ao restaurar compras: $e");
    }

    _listenToFirestoreSubscription();
    notifyListeners();
  }

  Future<void> loadProducts() async {
    loading = true;
    notifyListeners();

    if (!available) {
      loading = false;
      notifyListeners();
      return;
    }

    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      products = [];
    } else {
      products = response.productDetails;
    }

    loading = false;
    notifyListeners();
  }

  Future<void> buyProduct(ProductDetails product) async {
    try {
      final param = PurchaseParam(productDetails: product);
      await _iap.buyNonConsumable(purchaseParam: param);
    } catch (e, st) {
      debugPrint('Erro na compra: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  void _listenToFirestoreSubscription() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _subscriptionActive = false;
      notifyListeners();
      return;
    }

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();
      if (data != null) {
        final role = data['role'];
        _subscriptionActive = (role == 'premium' || role == 'premium_ios');
      } else {
        _subscriptionActive = false;
      }
      notifyListeners();
    }, onError: (error) {
      debugPrint("Erro ao ouvir Firestore: $error");
      _subscriptionActive = false;
      notifyListeners();
    });
  }

  bool get isSubscribed => _subscriptionActive;

  void _onPurchaseUpdate(List<PurchaseDetails> data) {
    purchases = data;
    for (final p in data) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _verifyAndCompletePurchase(p);
      }
      if (p.status == PurchaseStatus.error) {
        debugPrint('Erro na compra IAP: ${p.error}');
      }
    }
    notifyListeners();
  }

  Future<void> _verifyAndCompletePurchase(PurchaseDetails p) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'role': 'premium_ios',
          'subscription': {
            'active': true,
            'source': 'app_store',
            'updatedAt': FieldValue.serverTimestamp(),
            'purchaseId': p.purchaseID,
          },
        }, SetOptions(merge: true));
        debugPrint("✅ Compra validada e escrita no Firestore!");
      }
    } catch (e) {
      debugPrint("❌ Erro ao escrever compra no Firestore: $e");
    }

    if (p.pendingCompletePurchase) {
      await _iap.completePurchase(p);
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
